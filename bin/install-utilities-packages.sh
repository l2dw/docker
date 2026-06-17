#!/usr/bin/env bash
# Install utilities packages
set -euo pipefail

## if debian/ubuntu, install utilities packages
if [ -f /etc/debian_version ]; then
    sudo apt update -y
    sudo apt install -y \
        build-essential \
        ca-certificates fail2ban \
        curl \
        wget \
        git \
        vim \
        htop \
        unzip \
        jq \
        tree \
        tmux \
        dnsutils \
        net-tools
fi

## if redhat/centos, fedora, or rocky linux, install utilities packages
if [ -f /etc/redhat-release ]; then
    sudo dnf install -y epel-release
    sudo dnf install -y http://rpms.remirepo.net/enterprise/remi-release-9.rpm
    sudo dnf install -y --allowerasing initscripts nc \
        rsync openssh-server telnet \
        rsyslog gnupg make fail2ban \
        curl wget vim git sudo nano cifs-utils jq \
        unzip bzip2 zip tmux \
        tree zsh net-tools bash-completion crontabs passwd cracklib-dicts \
        nfs-utils nfs4-acl-tools httpd-tools bind-utils \
        firewalld
fi
