#!/bin/bash

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
# if swap file already exists, remove it first
if [ -f "${SWAP_FILE}" ]; then
	sudo swapoff "${SWAP_FILE}"
	sudo rm -f "${SWAP_FILE}"
fi

sudo fallocate -l "${SWAP_SIZE}" "${SWAP_FILE}"
sudo chmod 600 "${SWAP_FILE}"
sudo mkswap "${SWAP_FILE}"

# add to fstab: check if already exists
if ! grep -q "${SWAP_FILE}" /etc/fstab; then
	echo "${SWAP_FILE} swap swap defaults 0 0" | sudo tee -a /etc/fstab
fi

# reload systemd
sudo systemctl daemon-reload && sudo mount -a
sleep 2 && sudo swapon -a
sudo swapon --show

echo "Swap file memory added successfully"
