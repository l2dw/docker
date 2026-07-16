#!/bin/bash

ADMIN_USER="${ADMIN_USER:-$(whoami)}"
INSTANCE_NAME="${INSTANCE_NAME:-$(hostname -s)}"

# Resolve the admin user's home directory (works when setup runs via sudo/make as another user).
HOME_DIR=$(eval echo "~${ADMIN_USER}")
ENV_FILE="${ENV_FILE:-${HOME_DIR}/.env}"


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


# Pick an IPv4 suitable for docker swarm --advertise-addr when SWARM_ADVERTISE_ADDR is unset.
detect_swarm_advertise_addr() {
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

docker_cmd() {
	if docker info >/dev/null 2>&1; then
		docker "$@"
	elif sudo docker info >/dev/null 2>&1; then
		sudo docker "$@"
	else
		echo "Error: Docker is not installed or not reachable (try: newgrp docker, or use sudo)." >&2
		exit 1
	fi
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

