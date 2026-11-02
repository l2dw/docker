#!/bin/sh
# Replace systemd-resolved stub with static resolv.conf (POSIX sh — no bash substitutions).

if [ "${UPDATE_DNS_RESOLVERS}" != "true" ] && [ "${UPDATE_DNS_RESOLVERS}" != "1" ]; then
	echo "UPDATE_DNS_RESOLVERS is not set to true, skipping DNS resolution fix"
	exit 0
fi

# Check if user has sudo privileges (NOPASSWD)
if ! sudo -n true 2>/dev/null; then
	echo "Info: passwordless sudo is required (NOPASSWD); skipping DNS resolution fix."
	exit 0
fi

NS1="${NAMESERVER1:-${EXTERNAL_IP:-}}"
NS2="${NAMESERVER2:-${GATEWAY_IP:-}}"
NS3="${NAMESERVER3:-8.8.8.8}"

if [ -z "${NS1}" ] || [ -z "${NS2}" ]; then
	echo "Error: set NAMESERVER1 and NAMESERVER2 (or EXTERNAL_IP and GATEWAY_IP) when UPDATE_DNS_RESOLVERS=1"
	exit 1
fi

INFRA_DOMAIN="${INFRA_DOMAIN:-local}"
INFRA_NAME="${INFRA_NAME:-local}"
SEARCH_DOMAIN="${SEARCH_DOMAIN:-${INFRA_DOMAIN}}"
DOMAIN_DOT="$(printf '%s' "${INFRA_DOMAIN}" | tr '-' '.')"

sudo sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl stop systemd-resolved 2>/dev/null || true
sudo systemctl disable systemd-resolved 2>/dev/null || true
sudo systemctl mask systemd-resolved 2>/dev/null || true
sudo rm -f /etc/resolv.conf

sudo tee /etc/resolv.conf > /dev/null << EOF
nameserver ${NS1}
nameserver ${NS2}
nameserver ${NS3}
search ${INFRA_NAME}.${INFRA_DOMAIN} ${INFRA_NAME}.${DOMAIN_DOT} ${SEARCH_DOMAIN}
EOF

# Confirm the DNS configuration:
cat /etc/resolv.conf
