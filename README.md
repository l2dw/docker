# OCRX Infrastructure

## Instances (arbutus.alliancecan.ca)

1. pivot.ocrx: 128Go - P2-3G
2. worker-01.ocrx: 128Go - P8-12G
3. worker-02.ocrx: 128Go - P8-12G
4. atelier-01.ocrx: 128Go - P2-3G

## VMs

### pivot-ocrx

```sh
# ssh
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@134.87.11.3
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@134.87.9.18

## Git
git init
git remote add origin https://github.com/ocrx-dev/ocrx-infra.git
git fetch origin && git checkout ocrx/infra

## Packages
./bin/install-utilities-packages.sh

# ## Environments variables
# sudo tee ~/.env << FIN > /dev/null
# #
# HTTP_PROXY=
# HTTPS_PROXY=
# NO_PROXY=

# TZ=America/Montreal
# DEFAULT_NETWORK_NAME=dokploy-network
# DEFAULT_NETWORK_EXTERNAL=true
# DOCKER_RUNTIME_SOCKET=/var/run/docker.sock

# FIN
INSTANCE_NAME=pivot
make setup \
    INSTANCE_NAME=${INSTANCE_NAME} \
    INFRA_NAME=ocrx \
    INFRA_DOMAIN=arbutus-cloud \
    ADMIN_USER=ubuntu \
    INFRA_DIR=/home/ubuntu \
    APPDATA_DIR=/appdata \
    CERTS_DIR=/shares/certs \
    BACKUPS_DIR=/backups \
    LOGS_DIR=/appdata/logs \
    DATA_DIR=/data \
    SWAP_SIZE=4G \
    DOCKER_REGISTRY=registry.ocrx.arbutus-cloud:5000 \
    DOCKER_USER=cenadmin \
    DOCKER_PASSWORD=CenUdeM6500 \
    UPDATE_DNS_RESOLVERS=1 \
    NAMESERVER1=134.87.11.3 \
    NAMESERVER2=192.168.71.1 \
    NAMESERVER3=8.8.8.8 \
    SEARCH_DOMAIN=arbutus-cloud

source ~/.env
# cat /etc/resolv.conf

## Docker


## SSH

sudo tee ~/.ssh/authorized_keys << FIN > /dev/null
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFDxfUBXOdZmTsLk3jrpkICQrt7o2NEXSXCOjaY9iocy ${ADMIN_USER}@${INFRA_NAME}.${INFRA_DOMAIN}
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII+DXnVWEejLpROErVA1jKTEnhY53kRoPpnMQCn5LDC+ christian.kamgang.simeu@umontreal.ca
FIN

sudo tee ~/.ssh/id_ed25519 << FIN > /dev/null
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBQ8X1AVznWZk7C5N466ZCAkK7e6NjRF0lwjo2mPYqHMgAAAKCJPgawiT4G
sAAAAAtzc2gtZWQyNTUxOQAAACBQ8X1AVznWZk7C5N466ZCAkK7e6NjRF0lwjo2mPYqHMg
AAAECFtvGaF+VO828EgikIyziJqsZab4ksJ95KWy5cx7No7VDxfUBXOdZmTsLk3jrpkICQ
rt7o2NEXSXCOjaY9iocyAAAAG2NlbmFkbUBjaHVwaW5qLmJlbHVnYS1jbG91ZAEC
-----END OPENSSH PRIVATE KEY-----
FIN
sudo chown $ADMIN_USER:$ADMIN_USER -R ~/.ssh/
sudo chmod 600 -R ~/.ssh/
sudo chmod 700 ~/.ssh/


# ssh-keygen -t ed25519 -C "ubuntu@ocrx.arbutus-cloud" -f ~/.ssh/id_ed25519 -N ""
# cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys


```

## Création d'une VM

### Manuel

```sh
#ssh vm

```
