#!/usr/bin/env bash
# Install utilities packages
set -euo pipefail

EXTRA_PACKAGES="$@"

## if debian/ubuntu, install utilities packages
if [ -f /etc/debian_version ]; then
    sudo apt update -y
    if [ -n "$EXTRA_PACKAGES" ]; then
        sudo apt install -y $EXTRA_PACKAGES
    fi
fi

## if redhat/centos, fedora, or rocky linux, install utilities packages
if [ -f /etc/redhat-release ]; then
    if [ -n "$EXTRA_PACKAGES" ]; then
        sudo dnf install -y $EXTRA_PACKAGES
    fi
fi
