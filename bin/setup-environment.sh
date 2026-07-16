#!/bin/bash

source "$(dirname "$0")/utils.sh"

# Setup environment's variables

echo "Setting up environment with variables..."
echo "ADMIN_USER: ${ADMIN_USER}"
echo "INSTANCE_NAME: ${INSTANCE_NAME}"
echo "INFRA_NAME: ${INFRA_NAME}"
echo "INFRA_DOMAIN: ${INFRA_DOMAIN}"

## Variables are required
if [ -z "${ADMIN_USER}" ] || [ -z "${INSTANCE_NAME}" ] || [ -z "${INFRA_NAME}" ] || [ -z "${INFRA_DOMAIN}" ]; then
    echo "Error: Variables are required"
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

# Re-run: fill missing vars from an existing env file (do not override make exports).
if [ -r "${ENV_FILE}" ] && { [ -z "${INSTANCE_NAME}" ] || [ -z "${INFRA_NAME}" ] || [ -z "${INFRA_DOMAIN}" ] || [ -z "${ADMIN_USER}" ]; }; then
	# shellcheck disable=SC1090
	set -a
	. "${ENV_FILE}"
	set +a
fi
resolve_admin_home

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
resolve_admin_home


if [ -f "${INFRA_DIR}/Makefile" ] && [ ! -L "${HOME_DIR}/Makefile" ] && [ ! -f "${HOME_DIR}/Makefile" ]; then
    echo "Creating symlink for Makefile in ${HOME_DIR}..."
    ln -s "${INFRA_DIR}/Makefile" "${HOME_DIR}/Makefile"
fi

if [ -d "${INFRA_DIR}/bin" ] && [ ! -L "${HOME_DIR}/bin" ] && [ ! -d "${HOME_DIR}/bin" ]; then
    echo "Creating symlink for bin in ${HOME_DIR}..."
    ln -s "${INFRA_DIR}/bin" "${HOME_DIR}/bin"
fi

## Git config
rm -f "${HOME_DIR}/.gitconfig"
if [ -f "${INFRA_DIR}/etc/gitconfig" ]; then
	cp "${INFRA_DIR}/etc/gitconfig" "${HOME_DIR}/.gitconfig"
else
    touch "${HOME_DIR}/.gitconfig"
    chmod 0644 "${HOME_DIR}/.gitconfig"
    chown "${ADMIN_USER}:${ADMIN_USER}" "${HOME_DIR}/.gitconfig"
fi

git config --global http.sslVerify false
git config --global core.autocrlf false
git config --global user.name "${ADMIN_USER}"
git config --global user.email "${ADMIN_USER}@${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}"

require_passwordless_sudo

sudo hostnamectl set-hostname "${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}"

## Replace localhost with the IP address in /etc/hosts : 127.0.0.1 localhost
sudo sed -i "s/127.0.0.1 .*/127.0.0.1 localhost ${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}/g" /etc/hosts


echo "==> Configure swap <=="
echo "======================"
sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf


## System daily update (admin user crontab; commands use sudo for package management)
if ! crontab -l 2>/dev/null | grep -qF "apt-get update"; then
	(
		crontab -l 2>/dev/null
		echo "0 3 * * * sudo apt-get update && DEBIAN_FRONTEND=noninteractive sudo apt-get -y upgrade && sudo apt-get -y autoremove && sudo apt-get autoclean >> /var/log/auto-update.log 2>&1"
	) | crontab -
fi
