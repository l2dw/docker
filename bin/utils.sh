#!/bin/bash

# Track vars exported before defaults (e.g. make) so callers can still load ~/.env for missing ones.
# Empty values (ADMIN_USER=) are treated as unset — common in partial .env files.
_ADMIN_USER_EXPLICIT=0
[ -n "${ADMIN_USER}" ] && _ADMIN_USER_EXPLICIT=1
ADMIN_USER="${ADMIN_USER:-${SUDO_USER:-$(whoami)}}"

_INSTANCE_NAME_EXPLICIT=0
[ -n "${INSTANCE_NAME}" ] && _INSTANCE_NAME_EXPLICIT=1
INSTANCE_NAME="${INSTANCE_NAME:-$(hostname -s)}"

# Resolve the admin user's home directory (works when setup runs via sudo/make as another user).
_ENV_FILE_WAS_SET=
[ -n "${ENV_FILE+set}" ] && _ENV_FILE_WAS_SET=1
HOME_DIR=$(eval echo "~${ADMIN_USER}")
ENV_FILE="${ENV_FILE:-${HOME_DIR}/.env}"

# Recompute paths after ADMIN_USER may have changed (e.g. sourced from ~/.env).
resolve_admin_home() {
	HOME_DIR=$(eval echo "~${ADMIN_USER}")
	if [ -z "${_ENV_FILE_WAS_SET}" ]; then
		ENV_FILE="${HOME_DIR}/.env"
	fi
}

# Re-apply identity defaults after sourcing an env file (empty ADMIN_USER= must not win).
apply_identity_defaults() {
	ADMIN_USER="${ADMIN_USER:-${SUDO_USER:-$(whoami)}}"
	INSTANCE_NAME="${INSTANCE_NAME:-$(hostname -s)}"
	resolve_admin_home
}

# Log a setup problem but keep going (used by make setup steps).
setup_warn() {
	echo "Warning: $*" >&2
}


# Utility functions
require_passwordless_sudo() {
	if ! sudo -n true 2>/dev/null; then
		echo "Error: passwordless sudo is required (NOPASSWD). Verify with: sudo -n true" >&2
		exit 1
	fi
}

# Pick an IPv4 address
detect_ip_address() {
	local addr=""

	if command -v ip >/dev/null 2>&1; then
		# Prefer source IP used for traffic toward the default route (typical cloud / LAN address).
		for dest in 8.8.8.8 1.1.1.1; do
			addr="$(ip -4 route get "${dest}" 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }' || true)"
			[ -n "${addr}" ] && break
		done

		# Primary IPv4 on the default-route interface.
		if [ -z "${addr}" ]; then
			local dev
			dev="$(ip -4 route show default 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }' || true)"
			if [ -n "${dev}" ]; then
				addr="$(ip -4 -o addr show dev "${dev}" scope global 2>/dev/null | awk '{ print $4 }' | head -1 | cut -d/ -f1 || true)"
			fi
		fi

		# First global IPv4 on any interface.
		if [ -z "${addr}" ]; then
			addr="$(ip -4 -o addr show scope global 2>/dev/null | awk '{ print $4 }' | head -1 | cut -d/ -f1 || true)"
		fi
	fi

	# Common on minimal systems without full ip(8) output, or non-Linux.
	if [ -z "${addr}" ] && command -v hostname >/dev/null 2>&1; then
		addr="$(hostname -I 2>/dev/null | awk '{ print $1 }' || true)"
	fi

	printf '%s' "${addr}"
}

render_env_bashrc_block() {
	# Bake the path chosen at setup time; login shells may override via export ENV_FILE=...
	local default_env_file_quoted
	default_env_file_quoted="$(printf '%q' "${ENV_FILE}")"
	cat <<EOF
# INFRA ENVIRONMENT VARIABLES: load infra variables (override: export ENV_FILE=/path)
ENV_FILE=\${ENV_FILE:-${default_env_file_quoted}}
if [ -r "\${ENV_FILE}" ]; then
  set -a
  # shellcheck source=/dev/null
  . "\${ENV_FILE}"
  set +a
fi
EOF
}

docker_cmd() {
	if docker info >/dev/null 2>&1; then
		docker "$@"
	elif sudo docker info >/dev/null 2>&1; then
		sudo docker "$@"
	elif podman info >/dev/null 2>&1; then
		podman "$@"
	elif sudo podman info >/dev/null 2>&1; then
		sudo podman "$@"
	else
		echo "Error: Docker or Podman is not installed or not reachable (try: newgrp docker, or use sudo)." >&2
		exit 1
	fi
}

# Return 0 when the Docker CLI provides a usable `docker swarm` subcommand.
# Podman does not implement Docker Swarm mode; it is not checked here.
supports_swarm() {
	if command -v docker >/dev/null 2>&1 && docker swarm --help >/dev/null 2>&1; then
		return 0
	fi
	if sudo docker swarm --help >/dev/null 2>&1; then
		return 0
	fi
	return 1
}

# Print docker swarm join commands (only managers can issue tokens).
print_join_cluster_commands() {
	echo ""
	echo "========== Join other nodes to this cluster =========="
	if docker_cmd info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null | grep -q true; then
		docker_cmd swarm join-token worker
		echo ""
		docker_cmd swarm join-token manager
	else
		echo "This node is a Swarm worker (not a manager). Run the following on a manager to see join commands:"
		echo "  docker swarm join-token worker"
		echo "  docker swarm join-token manager"
	fi
	echo "======================================================"
	echo ""
}

