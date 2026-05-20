#!/bin/bash

# Setup filesystem
source /etc/environment

# Create directories (CERTS_DIR: bind mount for Traefik ACME /certs in docker-compose)
CERTS_DIR="${CERTS_DIR:-/etc/certs}"
sudo mkdir -p "${INFRA_DIR}" "${APPDATA_DIR}" "${CERTS_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}"
sudo chown "${ADMIN_USER}:${ADMIN_USER}" "${INFRA_DIR}" "${APPDATA_DIR}" "${BACKUPS_DIR}"
