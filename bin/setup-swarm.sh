#!/usr/bin/env bash
# Initialize Docker Swarm on this node (single-manager setup).
# Idempotent: does nothing if Swarm is already active.
#
# SWARM_ADVERTISE_ADDR — optional; if unset, a sensible IPv4 is detected (default route / global scope).
#   Override manually when needed, e.g. SWARM_ADVERTISE_ADDR=192.168.1.10 ./setup-swarm.sh

set -euo pipefail

## TODO: checks if node (hostname like "pivot.*") is pivot node and if not, skip swarm setup
if ! hostname | grep -q "pivot."; then
	echo "This node is not a pivot node; skipping swarm setup."
	exit 0
fi

## TODO: checks if node is already in the swarm and if so, skip swarm setup
if docker_cmd info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q "active"; then
	echo "This node is already in the swarm; skipping swarm setup."
	exit 0
fi

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

if ! command -v docker >/dev/null 2>&1; then
	echo "Error: docker not found. Run install-docker-ce.sh first." >&2
	exit 1
fi

state="$(docker_cmd info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo inactive)"
if [ "${state}" = "active" ]; then
	echo "Docker Swarm is already active on this node; skipping init."
	if docker_cmd info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null | grep -q true; then
		docker_cmd node ls
	fi
	print_join_cluster_commands
	exit 0
fi

echo "Initializing Docker Swarm..."
init_args=()

if [ -z "${SWARM_ADVERTISE_ADDR:-}" ]; then
	SWARM_ADVERTISE_ADDR="$(detect_swarm_advertise_addr)"
fi

if [ -n "${SWARM_ADVERTISE_ADDR}" ]; then
	echo "Using --advertise-addr ${SWARM_ADVERTISE_ADDR}"
	init_args+=(--advertise-addr "${SWARM_ADVERTISE_ADDR}")
else
	echo "Could not detect an IPv4 advertise address; running docker swarm init without --advertise-addr."
fi

docker_cmd swarm init "${init_args[@]}"

echo "Docker Swarm initialized."
docker_cmd node ls
print_join_cluster_commands

