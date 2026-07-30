#!/usr/bin/env bash
# Install docker-ce
set -euo pipefail

## Check if user has passwordless sudo privileges (NOPASSWD)
if ! sudo -n true 2>/dev/null; then
    echo "Info: passwordless sudo is required (NOPASSWD); skipping server update."
    exit 0
fi

## if debian/ubuntu
if [ -f /etc/debian_version ]; then
    sudo apt upgrade -y
fi

## if redhat/centos, fedora, or rocky linux
if [ -f /etc/redhat-release ]; then
    sudo dnf upgrade -y
fi
