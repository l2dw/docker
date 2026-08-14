#!/bin/bash

source "$(dirname "$0")/utils.sh"

# Fill missing vars from an existing env file (do not override make exports).
load_env_preserving_exports "${ENV_FILE}"
apply_identity_defaults

# Setup environment's variables

echo "Setting up environment with variables..."
echo "ADMIN_USER: ${ADMIN_USER}"
echo "INSTANCE_NAME: ${INSTANCE_NAME}"
echo "INFRA_NAME: ${INFRA_NAME}"
echo "INFRA_DOMAIN: ${INFRA_DOMAIN}"
echo "ENV_FILE: ${ENV_FILE}"

## Variables are required
missing=""
[ -z "${ADMIN_USER}" ] && missing="${missing} ADMIN_USER"
[ -z "${INSTANCE_NAME}" ] && missing="${missing} INSTANCE_NAME"
[ -z "${INFRA_NAME}" ] && missing="${missing} INFRA_NAME"
[ -z "${INFRA_DOMAIN}" ] && missing="${missing} INFRA_DOMAIN"
if [ -n "${missing}" ]; then
	echo "Error: required variables are missing:${missing}" >&2
	echo "Hint: pass on the command line (ADMIN_USER=admin ...) or set them in ${ENV_FILE}" >&2
	exit 1
fi


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

INFRA_DIR="${INFRA_DIR:-/infra}"
APPDATA_DIR="${APPDATA_DIR:-/appdata}"
# CERTS_DIR="${CERTS_DIR:-${APPDATA_DIR}/certs}"
BACKUPS_DIR="${BACKUPS_DIR:-${APPDATA_DIR}/backups}"
LOGS_DIR="${LOGS_DIR:-${APPDATA_DIR}/logs}"
# DATA_DIR="${DATA_DIR:-${APPDATA_DIR}/data}"

echo "Home directory of ${ADMIN_USER}: ${HOME_DIR}"
echo "Writing ${ENV_FILE}..."
tmp_env="$(mktemp)"
touch "${ENV_FILE}"

# Keep everything before the marker, replace everything after it.
awk '
  /^# Infra Environment variables[[:space:]]*$/ { exit }
  { print }
' "${ENV_FILE}" > "${tmp_env}"

cat >> "${tmp_env}" << EOF
# #########################################################
# Infra Environment variables
# #########################################################
ENV_FILE=${ENV_FILE}
TERM=xterm-256color
ADMIN_USER=${ADMIN_USER}
IP_ADDRESS="$(detect_ip_address)"
#
INSTANCE_NAME=${INSTANCE_NAME}
INFRA_NAME=${INFRA_NAME}
INFRA_DOMAIN=${INFRA_DOMAIN}
#
INFRA_DIR=${INFRA_DIR:-/infra}
APPDATA_DIR=${APPDATA_DIR:-/appdata}
BACKUPS_DIR=${BACKUPS_DIR:-${APPDATA_DIR}/backups}
LOGS_DIR=${LOGS_DIR:-${APPDATA_DIR}/logs}

# Docker registry
DOCKER_REGISTRY_HOST=${DOCKER_REGISTRY_HOST:-registry.${INFRA_NAME}.${INFRA_DOMAIN}:5000}
DOCKER_REGISTRY_USER=${DOCKER_REGISTRY_USER:-docker}
DOCKER_REGISTRY_PASS=${DOCKER_REGISTRY_PASS:-docker}

EOF

install -m 0644 "${tmp_env}" "${ENV_FILE}"
rm -f "${tmp_env}"

BASHRC="${HOME_DIR}/.bashrc"
ENV_BASHRC_BLOCK="$(render_env_bashrc_block)"

if [ -f "${BASHRC}" ]; then
	if grep -qF 'INFRA ENVIRONMENT VARIABLES' "${BASHRC}"; then
		tmp_bashrc="$(mktemp)"
		awk '
		  /^# INFRA ENVIRONMENT VARIABLES:/ { skip=1; next }
		  skip && /^fi$/ { skip=0; next }
		  skip { next }
		  { print }
		' "${BASHRC}" > "${tmp_bashrc}"
		printf '%s\n' "${ENV_BASHRC_BLOCK}" >> "${tmp_bashrc}"
		mv "${tmp_bashrc}" "${BASHRC}"
		echo "Updated ${BASHRC} to source ${ENV_FILE}"
	else
		printf '\n%s\n' "${ENV_BASHRC_BLOCK}" >> "${BASHRC}"
		echo "Updated ${BASHRC} to source ${ENV_FILE}"
	fi
else
	echo "Warning: ${BASHRC} not found; skipping ${HOME_DIR}/.bashrc environment hook" >&2
fi

## Ensure all environment variables are reloaded in the shell
if [ -r "${ENV_FILE}" ]; then
	# shellcheck disable=SC1090
	set -a
	. "${ENV_FILE}"
	set +a
	echo "Reloaded environment from ${ENV_FILE}"
fi
apply_identity_defaults

echo "==> Home directory shortcuts..."
if [ -f "${INFRA_DIR}/Makefile" ] && [ ! -L "${HOME_DIR}/Makefile" ] && [ ! -f "${HOME_DIR}/Makefile" ]; then
	echo "Creating symlink for Makefile in ${HOME_DIR}..."
	if ! ln -s "${INFRA_DIR}/Makefile" "${HOME_DIR}/Makefile"; then
		setup_warn "could not create ${HOME_DIR}/Makefile symlink"
	fi
fi

if [ -d "${INFRA_DIR}/bin" ] && [ ! -L "${HOME_DIR}/bin" ] && [ ! -d "${HOME_DIR}/bin" ]; then
	echo "Creating symlink for bin in ${HOME_DIR}..."
	if ! ln -s "${INFRA_DIR}/bin" "${HOME_DIR}/bin"; then
		setup_warn "could not create ${HOME_DIR}/bin symlink"
	fi
fi

echo "==> Git configuration..."
GIT_CONFIG="${HOME_DIR}/.gitconfig"
rm -f "${GIT_CONFIG}"
if [ -f "${INFRA_DIR}/etc/gitconfig" ]; then
	cp "${INFRA_DIR}/etc/gitconfig" "${GIT_CONFIG}" || setup_warn "could not copy ${INFRA_DIR}/etc/gitconfig"
else
	touch "${GIT_CONFIG}" || setup_warn "could not create ${GIT_CONFIG}"
fi

if command -v git >/dev/null 2>&1; then
	if ! git config --file "${GIT_CONFIG}" http.sslVerify false; then
		setup_warn "git config http.sslVerify failed for ${GIT_CONFIG}"
	fi
	if ! git config --file "${GIT_CONFIG}" core.autocrlf false; then
		setup_warn "git config core.autocrlf failed for ${GIT_CONFIG}"
	fi
	if ! git config --file "${GIT_CONFIG}" user.name "${ADMIN_USER}"; then
		setup_warn "git config user.name failed for ${GIT_CONFIG}"
	fi
	if ! git config --file "${GIT_CONFIG}" user.email "${ADMIN_USER}@${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}"; then
		setup_warn "git config user.email failed for ${GIT_CONFIG}"
	fi
else
	setup_warn "git is not installed; skipped git configuration"
fi

chmod 0644 "${GIT_CONFIG}" 2>/dev/null || setup_warn "could not chmod ${GIT_CONFIG}"
if [ "$(id -un)" != "${ADMIN_USER}" ]; then
	chown "${ADMIN_USER}:${ADMIN_USER}" "${GIT_CONFIG}" 2>/dev/null \
		|| setup_warn "could not chown ${GIT_CONFIG} to ${ADMIN_USER}"
fi

echo "==> System configuration (hostname, hosts, swap, crontab)..."
if ! has_passwordless_sudo; then
	setup_warn "passwordless sudo is not configured; skipping hostname, /etc/hosts, sysctl, and crontab"
else
	if ! sudo hostnamectl set-hostname "${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}"; then
		setup_warn "hostnamectl set-hostname failed"
	fi

	if ! sudo sed -i "s/127.0.0.1 .*/127.0.0.1 localhost ${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}/g" /etc/hosts; then
		setup_warn "could not update /etc/hosts"
	fi

	echo "==> Configure swap swappiness..."
	if ! sudo sysctl vm.swappiness=10; then
		setup_warn "sysctl vm.swappiness failed"
	fi
	if ! grep -qF 'vm.swappiness=10' /etc/sysctl.conf 2>/dev/null; then
		echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf >/dev/null \
			|| setup_warn "could not append vm.swappiness to /etc/sysctl.conf"
	fi

	if ! crontab -l 2>/dev/null | grep -qF "apt-get update"; then
		if ! (
			crontab -l 2>/dev/null
			echo "0 3 * * * sudo apt-get update && DEBIAN_FRONTEND=noninteractive sudo apt-get -y upgrade && sudo apt-get -y autoremove && sudo apt-get autoclean >> /var/log/auto-update.log 2>&1"
		) | crontab -; then
			setup_warn "could not install daily apt crontab for ${ADMIN_USER}"
		fi
	fi
fi

echo "Finished setup-environment."
exit 0
