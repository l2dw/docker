#!/bin/bash

source "$(dirname "$0")/utils.sh"

# Get the IP address of the current node
IP_ADDRESS="$(detect_ip_address)"
if [ -z "${IP_ADDRESS}" ]; then
	echo "Error: no suitable IPv4 address found; set SWARM_ADVERTISE_ADDR or IP_ADDRESS" >&2
	exit 1
fi
echo "${IP_ADDRESS}"
