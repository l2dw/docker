# OCRX Infrastructure

## Instances (arbutus.alliancecan.ca)

1. pivot.ocrx: 128Go - P2-3G
2. worker-01.ocrx: 128Go - P8-12G
3. worker-02.ocrx: 128Go - P8-12G
4. atelier-01.ocrx: 128Go - P2-3G

## Images

### template-ocrx

Création d'une image template pour installer

```sh
# ssh
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@134.87.11.3
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@134.87.9.18

## Git
git init
git remote add origin https://github.com/ocrx-dev/ocrx-infra.git
git fetch origin && git checkout ocrx/infra

## SSH
ssh-keygen -t ed25519 -C "ubuntu@ocrx.arbutus-cloud" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys

##
sudo tee ~/.env << FIN > /dev/null
#
HTTP_PROXY=
HTTPS_PROXY=
NO_PROXY=

TZ=America/Montreal
DEFAULT_NETWORK_NAME=dokploy-network
DEFAULT_NETWORK_EXTERNAL=true
DOCKER_RUNTIME_SOCKET=/var/run/docker.sock

INSTANCE_NAME=template
INFRA_NAME=ocrx
INFRA_DOMAIN=arbutus-cloud
ADMIN_USER=ubuntu

INFRA_DIR=/home/ubuntu
APPDATA_DIR=/appdata
CERTS_DIR=/shares/certs
BACKUPS_DIR=/backups
LOGS_DIR=/appdata/logs

# Docker Registry
DOCKER_REGISTRY_HOST=registry.ocrx.arbutus-cloud
DOCKER_REGISTRY_USER=ocrxadm
DOCKER_REGISTRY_PASS=CenUdeM6500

# DNS Resolvers
UPDATE_DNS_RESOLVERS=false
NAMESERVER1=192.168.x.x
NAMESERVER2=192.168.x.x
NAMESERVER3=192.168.x.x
SEARCH_DOMAIN=arbutus-cloud

FIN
## Docker


```

## Création d'une VM

### Manuel

```sh
#ssh vm

```
