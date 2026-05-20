#! /usr/bin/env bash
# Deploy Swarm stack from docker-compose.yaml.
# Requires: external overlay network (or created here), bind-mount host paths must exist.

set -euo pipefail

# Swarm updates can legitimately take > 1 minute (image pulls, rolling updates).
# Avoid client-side DeadlineExceeded by increasing Docker API timeouts.
export DOCKER_CLIENT_TIMEOUT="${DOCKER_CLIENT_TIMEOUT:-300}"
export COMPOSE_HTTP_TIMEOUT="${COMPOSE_HTTP_TIMEOUT:-300}"

if [ -r /etc/environment ]; then
	# shellcheck disable=SC1091
	set -a
	# shellcheck source=/dev/null
	. /etc/environment
	set +a
fi

INFRA_DIR="${INFRA_DIR:-/infra}"
APPDATA_DIR="${APPDATA_DIR:-/appdata}"
CERTS_DIR="${CERTS_DIR:-/etc/certs}"
DEFAULT_NETWORK="${DEFAULT_NETWORK:-dokploy-network}"
APPDATA_VOLUME="${APPDATA_VOLUME:-appdata_volume}"
CERTS_VOLUME="${CERTS_VOLUME:-certs_volume}"

# Load infra env file (for compose interpolation).
# docker stack deploy does NOT support --env-file, so we render with docker compose first.
ENV_FILE="${INFRA_DIR}/.env"
if [ -r "${ENV_FILE}" ]; then
	set -a
	# shellcheck disable=SC1090
	. "${ENV_FILE}"
	set +a
fi

# Bind-mounted volumes need these directories on the host before the container starts.
#
# Some volumes are optional (e.g. REDIS_DATA_DIR); avoid crashing under `set -u`.
mkdir_dirs=(
	"${APPDATA_DIR}"
	"${CERTS_DIR}"
)
if [ -n "${PORTAINER_DATA_DIR:-}" ]; then mkdir_dirs+=("${PORTAINER_DATA_DIR}"); fi
if [ -n "${ADGUARD_CONF_VOLUME:-}" ]; then mkdir_dirs+=("${ADGUARD_CONF_VOLUME}"); fi
if [ -n "${ADGUARD_WORK_VOLUME:-}" ]; then mkdir_dirs+=("${ADGUARD_WORK_VOLUME}"); fi
if [ -n "${REDIS_DATA_DIR:-}" ]; then mkdir_dirs+=("${REDIS_DATA_DIR}"); fi
if [ -n "${POSTGRESQL_DATA_DIR:-}" ]; then mkdir_dirs+=("${POSTGRESQL_DATA_DIR}"); fi
if [ -n "${POSTGRESQL_LOGS_DIR:-}" ]; then mkdir_dirs+=("${POSTGRESQL_LOGS_DIR}"); fi
if [ -n "${DOKPLOY_DATA_DIR:-}" ]; then mkdir_dirs+=("${DOKPLOY_DATA_DIR}"); fi
if [ -n "${DOKPLOY_LOGS_DIR:-}" ]; then mkdir_dirs+=("${DOKPLOY_LOGS_DIR}"); fi
if [ -n "${DOCKER_REGISTRY_DATA_DIR:-}" ]; then mkdir_dirs+=("${DOCKER_REGISTRY_DATA_DIR}"); fi
if [ -n "${DOCKER_REGISTRY_CONF_DIR:-}" ]; then mkdir_dirs+=("${DOCKER_REGISTRY_CONF_DIR}"); fi
sudo mkdir -p "${mkdir_dirs[@]}"

## Create network if it doesn't exist
if ! docker network ls | grep -q "${DEFAULT_NETWORK}"; then
	docker network create "${DEFAULT_NETWORK}" --driver overlay
fi

## Create volume appdata_volume if it doesn't exist
if ! docker volume ls | grep -q "${APPDATA_VOLUME}"; then
	docker volume create "${APPDATA_VOLUME}" --driver local --opt type=none --opt device="${APPDATA_DIR}" --opt o=bind
fi

## Create volume certs_volume if it doesn't exist
if ! docker volume ls | grep -q "${CERTS_VOLUME}"; then
	docker volume create "${CERTS_VOLUME}" --driver local --opt type=none --opt device="${CERTS_DIR}" --opt o=bind
fi

## Deploy infrastructure
# Note: docker stack deploy performs compose-style env interpolation itself.
deploy_stack() {
	# --detach=false waits for services to converge (when supported by your docker version).
	# If the flag is unsupported, Docker will fail and we retry without it.
	docker stack deploy -c "${INFRA_DIR}/docker-compose.yaml" infrastructure --with-registry-auth --detach=false
}

print_debug() {
	echo ""
	echo "=== docker stack services infrastructure ==="
	docker stack services infrastructure || true
	echo ""
	echo "=== docker service ps infrastructure_portainer ==="
	docker service ps infrastructure_portainer --no-trunc || true
	echo ""
	echo "=== docker service inspect infrastructure_portainer (UpdateStatus) ==="
	docker service inspect infrastructure_portainer --format '{{json .UpdateStatus}}' 2>/dev/null || true
	echo ""
}

set +e
deploy_stack
rc=$?
if [ $rc -ne 0 ]; then
	# Fallback for older Docker engines without --detach=false.
	docker stack deploy -c "${INFRA_DIR}/docker-compose.yaml" infrastructure --with-registry-auth
	rc=$?
fi
set -e

if [ $rc -ne 0 ]; then
	echo "Error: docker stack deploy failed (rc=$rc)."
	print_debug
	exit $rc
fi

# Quick post-deploy snapshot
sleep 5
docker service ls || true
