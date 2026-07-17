#!/usr/bin/env bash
# Initialize Docker Swarm on this node (single-manager setup).
# Idempotent: does nothing if Swarm is already active.
#
# SWARM_ADVERTISE_ADDR — optional; if unset, a sensible IPv4 is detected (default route / global scope).
#   Override manually when needed, e.g. SWARM_ADVERTISE_ADDR=192.168.1.10 ./setup-swarm.sh

set -euo pipefail

source "$(dirname "$0")/utils.sh"

if ! supports_swarm; then
	echo "Podman is installed; skipping Docker Swarm setup because Podman does not support Swarm."
	exit 0
fi

## Only initialize Swarm on pivot nodes (hostname starts with "pivot").
if ! hostname | grep -qE '^pivot'; then
	echo "This node is not a pivot node; skipping swarm setup."
	exit 0
fi

## TODO: checks if node is already in the swarm and if so, skip swarm setup
if docker_cmd info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q "active"; then
	echo "This node is already in the swarm; skipping swarm setup."
	exit 0
fi

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
	SWARM_ADVERTISE_ADDR="$(detect_ip_address)"
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

