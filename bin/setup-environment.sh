#!/bin/bash

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


# Pick an IPv4 address
detect_ip_address() {
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

## how do i get the home directory of the user ${ADMIN_USER}?
HOME_DIR=$(eval echo "~${ADMIN_USER}")
echo "Home directory of ${ADMIN_USER}: ${HOME_DIR}"
ENV_FILE="${ENV_FILE:-${HOME_DIR}/.env}"
echo "Writing ${ENV_FILE}..."
tmp_env="$(mktemp)"
touch "${ENV_FILE}"

# Keep everything before the marker, replace everything after it.
awk '
  /^# Infra Environment variables[[:space:]]*$/ { exit }
  { print }
' "${ENV_FILE}" > "${tmp_env}"

cat >> "${tmp_env}" << EOF

HTTP_PROXY=${http_proxy:-}
HTTPS_PROXY=${https_proxy:-}
NO_PROXY=${no_proxy:-}

TZ=${TZ:-America/Montreal}
DEFAULT_NETWORK_NAME=${DEFAULT_NETWORK_NAME:-dokploy-network}
DEFAULT_NETWORK_EXTERNAL=${DEFAULT_NETWORK_EXTERNAL:-true}
DOCKER_RUNTIME_SOCKET=${DOCKER_RUNTIME_SOCKET:-/var/run/docker.sock}

# Infra Environment variables
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
CERTS_DIR=${CERTS_DIR:-${APPDATA_DIR}/certs}
BACKUPS_DIR=${BACKUPS_DIR:-${APPDATA_DIR}/backups}
LOGS_DIR=${LOGS_DIR:-${APPDATA_DIR}/logs}
DATA_DIR=${DATA_DIR:-${APPDATA_DIR}/data}

# Docker registry
DOCKER_REGISTRY=${DOCKER_REGISTRY:-}
DOCKER_USER=${DOCKER_USER:-docker}
DOCKER_PASSWORD=${DOCKER_PASSWORD:-docker}

# # DNS (optional; used by fix-dns-resolv.sh)
# UPDATE_DNS_RESOLVERS=${UPDATE_DNS_RESOLVERS:-false}
# NAMESERVER1=${NAMESERVER1:-}
# NAMESERVER2=${NAMESERVER2:-}
# NAMESERVER3=${NAMESERVER3:-8.8.8.8}
# SEARCH_DOMAIN=${SEARCH_DOMAIN:-${INFRA_DOMAIN}}

#
EOF

install -m 0644 "${tmp_env}" "${ENV_FILE}"
rm -f "${tmp_env}"

BASHRC="${HOME_DIR}/.bashrc"
if [ -f "${BASHRC}" ]; then
	if ! grep -qF 'INFRA ENVIRONMENT VARIABLES' "${BASHRC}"; then
		cat >> "${BASHRC}" << 'EOF'

# INFRA ENVIRONMENT VARIABLES: load infra variables from ${ENV_FILE}
if [ -r "${ENV_FILE}" ]; then
  set -a
  # shellcheck source=/dev/null
  . "${ENV_FILE}"
  set +a
fi
EOF
		echo "Updated ${BASHRC} to source ${ENV_FILE}"
	else
		echo "${BASHRC} already sources ${ENV_FILE}"
	fi
else
	echo "Warning: ${BASHRC} not found; skipping ${HOME_DIR}/.bashrc environment hook" >&2
fi


if [ -f ${INFRA_DIR}/Makefile ] && [ ! -L ${HOME_DIR}/Makefile ] && [ ! -f ${HOME_DIR}/Makefile ]; then
    echo "Creating symlink for Makefile in ${HOME_DIR}..."
    sudo ln -s ${INFRA_DIR}/Makefile ${HOME_DIR}/Makefile
fi

if [ -d ${INFRA_DIR}/bin ] && [ ! -L ${HOME_DIR}/bin ] && [ ! -d ${HOME_DIR}/bin ]; then
    echo "Creating symlink for bin in ${HOME_DIR}..."
    sudo ln -s ${INFRA_DIR}/bin ${HOME_DIR}/bin
fi

## Git config
rm -f ${HOME_DIR}/.gitconfig
if [ -f ${INFRA_DIR}/etc/gitconfig ]; then
	cp ${INFRA_DIR}/etc/gitconfig ${HOME_DIR}/.gitconfig
else
    touch ${HOME_DIR}/.gitconfig
    chmod 0644 ${HOME_DIR}/.gitconfig
    chown ${ADMIN_USER}:${ADMIN_USER} ${HOME_DIR}/.gitconfig
fi

git config --global http.sslVerify false
git config --global core.autocrlf false
git config --global user.name "${ADMIN_USER}"
git config --global user.email "${ADMIN_USER}@${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}"


# Check if user has passwordless sudo privileges (NOPASSWD)
if ! sudo -n true 2>/dev/null; then
    echo "Info: passwordless sudo is required (NOPASSWD); skipping hostname configuration."
    exit 0
fi

sudo hostnamectl set-hostname "${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}"

## Replace localhost with the IP address in /etc/hosts : 127.0.0.1 localhost
sudo sed -i "s/127.0.0.1 .*/127.0.0.1 localhost ${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}/g" /etc/hosts


echo "==> Configure swap <=="
echo "======================"
sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf


## System daily update
# Add to crontab to update system once per day at 3:00 AM
if ! crontab -l | grep -q "apt-get update"; then
    echo "0 3 * * * apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && apt-get -y autoremove && apt-get autoclean >> /var/log/auto-update.log 2>&1" | sudo crontab -
fi
