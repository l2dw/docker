#!/bin/bash

# Setup filesystem
source /etc/environment

# Create directories (CERTS_DIR: bind mount for Traefik ACME /certs in docker-compose)
CERTS_DIR="${CERTS_DIR:-/etc/certs}"
sudo mkdir -p "${INFRA_DIR}" "${APPDATA_DIR}" "${CERTS_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}" "${DATA_DIR}"
sudo chown "${ADMIN_USER}:${ADMIN_USER}" "${INFRA_DIR}" "${APPDATA_DIR}" "${BACKUPS_DIR}" "${DATA_DIR}"

if [ ! -d /backups ] && [ ! -L /backups ]; then
    sudo ln -s "${BACKUPS_DIR}" /backups
fi

if [ ! -d /data ] && [ ! -L /data ]; then
    sudo ln -s "${DATA_DIR}" /data
fi

if [ ! -d /logs ] && [ ! -L /logs ]; then
    sudo ln -s "${LOGS_DIR}" /logs
fi
