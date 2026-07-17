#!/bin/bash

source "$(dirname "$0")/utils.sh"

# Setup filesystem

if [ -z "${ADMIN_USER:-}" ]; then
	setup_warn "ADMIN_USER is required; skipping filesystem setup"
	exit 0
fi

resolve_admin_home
if [ -f "${ENV_FILE}" ] && [ -r "${ENV_FILE}" ]; then
	# shellcheck disable=SC1090
	set -a
	. "${ENV_FILE}"
	set +a
fi
apply_identity_defaults

# Defaults when not passed on the command line or stored in the env file yet.
INFRA_DIR="${INFRA_DIR:-/infra}"
APPDATA_DIR="${APPDATA_DIR:-/appdata}"
LOGS_DIR="${LOGS_DIR:-${APPDATA_DIR}/logs}"
BACKUPS_DIR="${BACKUPS_DIR:-${APPDATA_DIR}/backups}"

echo "==> Creating infrastructure directories..."
dirs=( "${INFRA_DIR}" "${APPDATA_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}" )

if sudo -n true 2>/dev/null; then
	if ! sudo mkdir -p "${dirs[@]}"; then
		setup_warn "failed to create directories: ${dirs[*]}"
		exit 0
	fi
	if ! sudo chown "${ADMIN_USER}:${ADMIN_USER}" "${dirs[@]}"; then
		setup_warn "failed to chown directories for ${ADMIN_USER}"
		exit 0
	fi
else
	if ! mkdir -p "${dirs[@]}"; then
		setup_warn "failed to create directories (no passwordless sudo): ${dirs[*]}"
		exit 0
	fi
	setup_warn "passwordless sudo not available; created directories without chown to ${ADMIN_USER}"
fi

echo "Finished setup-filesystem."
exit 0
