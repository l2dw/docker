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


echo "Writing /etc/environment..."
tmp_env="$(mktemp)"
sudo touch /etc/environment

# Keep everything before the marker, replace everything after it.
sudo awk '
  /^# Infra Environment variables[[:space:]]*$/ { exit }
  { print }
' /etc/environment > "${tmp_env}"

cat >> "${tmp_env}" << EOF
# Infra Environment variables
TERM=xterm-256color
ADMIN_USER=${ADMIN_USER}
IP_ADDRESS="$(detect_ip_address)"
TZ=America/Toronto
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

#
EOF

sudo install -m 0644 "${tmp_env}" /etc/environment
rm -f "${tmp_env}"

sudo tee /etc/profile.d/zz-environment.sh << EOF > /dev/null
export \$(grep -v '^#' /etc/environment | xargs)
#
EOF

if [ ! -L /home/${ADMIN_USER}/Makefile ] && [ ! -f /home/${ADMIN_USER}/Makefile ]; then
    echo "Creating symlink for Makefile in /home/${ADMIN_USER}..."
    sudo ln -s /infra/Makefile /home/${ADMIN_USER}/Makefile
fi

if [ ! -L /home/${ADMIN_USER}/bin ] && [ ! -d /home/${ADMIN_USER}/bin ]; then
    echo "Creating symlink for bin in /home/${ADMIN_USER}..."
    sudo ln -s /infra/bin /home/${ADMIN_USER}/bin
fi

## Git config
if [ ! -f /home/${ADMIN_USER}/.gitconfig ]; then
    echo "Creating gitconfig in /home/${ADMIN_USER}..."
    sudo touch /home/${ADMIN_USER}/.gitconfig
    sudo chmod 0644 /home/${ADMIN_USER}/.gitconfig
    sudo chown ${ADMIN_USER}:${ADMIN_USER} /home/${ADMIN_USER}/.gitconfig
fi

git config --global http.sslVerify false
git config --global core.autocrlf false
git config --global user.name "${ADMIN_USER}"
git config --global user.email "${ADMIN_USER}@${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}"

sudo hostnamectl set-hostname "${INSTANCE_NAME}.${INFRA_NAME}.${INFRA_DOMAIN}"
