#!/usr/bin/env bash
# Install docker-ce
set -euo pipefail

# Test if docker is already installed
if command -v docker >/dev/null 2>&1; then
    echo "Docker is already installed"
    exit 0
fi

## if debian/ubuntu
if [ -f /etc/debian_version ]; then
    sudo apt update -y
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME:-$VERSION_ID}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

## if redhat/centos, fedora, or rocky linux
if [ -f /etc/redhat-release ]; then
    sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# Add admin user to docker group
sudo usermod -aG docker $ADMIN_USER || true

# Enable and start docker service
sudo systemctl enable docker --now

## config in /etc/docker/daemon.json
sudo mkdir -p /etc/docker/
sudo tee /etc/docker/daemon.json << EOF > /dev/null
{
  "bip": "172.16.17.1/24",
  "max-concurrent-downloads": 20,
  "insecure-registries" : [
    "127.0.0.1:5000",
    "${DOCKER_REGISTRY_HOST:-registry.${INFRA_NAME}.${INFRA_DOMAIN}:5000}"
  ]
}
EOF
sudo systemctl daemon-reload && sudo systemctl restart docker
