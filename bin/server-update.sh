#!/usr/bin/env bash
# Install docker-ce
set -euo pipefail


## if debian/ubuntu
if [ -f /etc/debian_version ]; then
    sudo apt upgrade -y
fi

## if redhat/centos, fedora, or rocky linux
if [ -f /etc/redhat-release ]; then
    sudo dnf upgrade -y
fi
