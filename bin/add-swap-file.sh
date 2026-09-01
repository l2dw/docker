#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/utils.sh"

ENABLE_SWAP_FILE="${ENABLE_SWAP_FILE:-false}"
SWAP_FILE="${SWAP_FILE:-/var/0.swap}"
SWAP_SIZE="${SWAP_SIZE:-4G}"

if [ "${ENABLE_SWAP_FILE}" != "true" ] && [ "${ENABLE_SWAP_FILE}" != "1" ]; then
	echo "ENABLE_SWAP_FILE is not set to true|1, skipping swap file creation"
	exit 0
fi

# Check if user has sudo privileges (NOPASSWD)
if ! sudo -n true 2>/dev/null; then
	echo "Info: passwordless sudo is required (NOPASSWD); skipping swap file creation."
	exit 0
fi

echo "Adding swap file ${SWAP_FILE} with size ${SWAP_SIZE}..."

# Remove an existing swap file (ignore swapoff if the file is not active).
if [ -f "${SWAP_FILE}" ]; then
	sudo swapoff "${SWAP_FILE}" 2>/dev/null || true
	sudo rm -f "${SWAP_FILE}"
fi

sudo fallocate -l "${SWAP_SIZE}" "${SWAP_FILE}"
sudo chmod 600 "${SWAP_FILE}"
sudo mkswap "${SWAP_FILE}"

if ! grep -qF "${SWAP_FILE}" /etc/fstab; then
	echo "${SWAP_FILE} swap swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null
fi

sudo swapon "${SWAP_FILE}"
sudo swapon --show

if ! swapon --show | grep -qF "${SWAP_FILE}"; then
	echo "Error: swap file ${SWAP_FILE} was not enabled" >&2
	exit 1
fi

echo "Swap file memory added successfully"
