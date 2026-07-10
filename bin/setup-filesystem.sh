#!/bin/bash

# Setup filesystem

HOME_DIR=$(eval echo "~${ADMIN_USER}")
ENV_FILE="${ENV_FILE:-${HOME_DIR}/.env}"
if [ -f "${ENV_FILE}" ] && [ -r "${ENV_FILE}" ]; then
	# shellcheck disable=SC1090
	set -a
	. "${ENV_FILE}"
	set +a
fi

# Create directories (CERTS_DIR: bind mount for Traefik ACME /certs in docker-compose)
APPDATA_DIR="${APPDATA_DIR:-/appdata}"
DATA_DIR="${DATA_DIR:-$APPDATA_DIR/data}"
CERTS_DIR="${CERTS_DIR:-$APPDATA_DIR/certs}"
LOGS_DIR="${LOGS_DIR:-$APPDATA_DIR/logs}"
BACKUPS_DIR="${BACKUPS_DIR:-$APPDATA_DIR/backups}"

## sudo user has permission to create directories in ${HOME_DIR}?
if  sudo -n true 2>/dev/null; then
    sudo mkdir -p "${INFRA_DIR}" "${APPDATA_DIR}" "${CERTS_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}" "${DATA_DIR}"
    sudo chown "${ADMIN_USER}:${ADMIN_USER}" "${INFRA_DIR}" "${APPDATA_DIR}" "${BACKUPS_DIR}" "${DATA_DIR}"
    exit 0
fi


## if failed, exit with error
if [ $? -ne 0 ]; then
    echo "Error: Failed to create directories: ${INFRA_DIR} ${APPDATA_DIR} ${CERTS_DIR} ${LOGS_DIR} ${BACKUPS_DIR} ${DATA_DIR}"
    echo "Please check if the user ${ADMIN_USER} has permission to create directories."
    echo "  sudo mkdir -p ${INFRA_DIR} ${APPDATA_DIR} ${CERTS_DIR} ${LOGS_DIR} ${BACKUPS_DIR} ${DATA_DIR}"
    exit 1
fi


# if [ ! -d /backups ] && [ ! -L /backups ]; then
#     sudo ln -s "${BACKUPS_DIR}" /backups
# fi

# if [ ! -d /data ] && [ ! -L /data ]; then
#     sudo ln -s "${DATA_DIR}" /data
# fi

# if [ ! -d /logs ] && [ ! -L /logs ]; then
#     sudo ln -s "${LOGS_DIR}" /logs
# fi

