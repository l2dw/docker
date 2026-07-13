#!/bin/bash

# Setup filesystem

if [ -z "${ADMIN_USER:-}" ]; then
	echo "Error: ADMIN_USER is required" >&2
	exit 1
fi

HOME_DIR=$(eval echo "~${ADMIN_USER}")
ENV_FILE="${ENV_FILE:-${HOME_DIR}/.env}"
if [ -f "${ENV_FILE}" ] && [ -r "${ENV_FILE}" ]; then
	# shellcheck disable=SC1090
	set -a
	. "${ENV_FILE}"
	set +a
fi

# Defaults when not passed on the command line or stored in the env file yet.
INFRA_DIR="${INFRA_DIR:-/infra}"
APPDATA_DIR="${APPDATA_DIR:-/appdata}"
DATA_DIR="${DATA_DIR:-${APPDATA_DIR}/data}"
CERTS_DIR="${CERTS_DIR:-${APPDATA_DIR}/certs}"
LOGS_DIR="${LOGS_DIR:-${APPDATA_DIR}/logs}"
BACKUPS_DIR="${BACKUPS_DIR:-${APPDATA_DIR}/backups}"

if sudo -n true 2>/dev/null; then
	if ! sudo mkdir -p "${INFRA_DIR}" "${APPDATA_DIR}" "${CERTS_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}" "${DATA_DIR}"; then
		echo "Error: Failed to create directories: ${INFRA_DIR} ${APPDATA_DIR} ${CERTS_DIR} ${LOGS_DIR} ${BACKUPS_DIR} ${DATA_DIR}" >&2
		exit 1
	fi
	if ! sudo chown "${ADMIN_USER}:${ADMIN_USER}" "${INFRA_DIR}" "${APPDATA_DIR}" "${CERTS_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}" "${DATA_DIR}"; then
		echo "Error: Failed to chown directories for ${ADMIN_USER}" >&2
		exit 1
	fi
else
	echo "Error: passwordless sudo is required to create infrastructure directories." >&2
	echo "  sudo mkdir -p ${INFRA_DIR} ${APPDATA_DIR} ${CERTS_DIR} ${LOGS_DIR} ${BACKUPS_DIR} ${DATA_DIR}" >&2
	echo "  sudo chown ${ADMIN_USER}:${ADMIN_USER} ${INFRA_DIR} ${APPDATA_DIR} ${CERTS_DIR} ${LOGS_DIR} ${BACKUPS_DIR} ${DATA_DIR}" >&2
	exit 1
fi
