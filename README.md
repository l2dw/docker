# OCRX Infrastructure

## Instances (arbutus.alliancecan.ca)

1. pivot.ocrx: 64Go - P2-3G
2. worker-01.ocrx: 128Go - P8-12G
3. worker-02.ocrx: 128Go - P8-12G
4. atelier-01.ocrx: 128Go - P2-3G

## VMs

### template-ocrx

```sh
# ssh
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@134.87.11.3
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@134.87.9.18

## SSH
ssh-keygen -t ed25519 -C "ubuntu@ocrx.arbutus-cloud" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys

## Git
git init
git remote add origin ${GIT_REPO:-https://github.com/ocrx-dev/ocrx-infra.git}
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
INSTANCE_NAME=template
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
    DOCKER_REGISTRY_HOST=registry.ocrx.arbutus-cloud:5000 \
    DOCKER_REGISTRY_USER=cenadmin \
    DOCKER_REGISTRY_PASS=${DOCKER_REGISTRY_PASS} \
    UPDATE_DNS_RESOLVERS=1 \
    NAMESERVER1=134.87.11.3 \
    NAMESERVER2=192.168.71.1 \
    NAMESERVER3=8.8.8.8 \
    SEARCH_DOMAIN=arbutus-cloud

# cat /etc/resolv.conf

## Docker

```

* NFS Volumes

```sh
# Test before mount -a (should list exports; fails fast if blocked)
showmount -e "${NFS_HOST}"
sudo apt install -y nfs-common

# Remove old OCRX NFS lines, then append (avoid duplicates)
sudo cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d)
grep -v "${INFRA_NAME}-appdata" /etc/fstab | sudo tee /etc/fstab.tmp >/dev/null
sudo mv /etc/fstab.tmp /etc/fstab
sudo tee -a /etc/fstab << FIN
# OCRX NFS (pivot LAN — not floating IP)
${NFS_HOST}:/volumes/${INFRA_NAME}-appdata/data  /appdata      nfs  defaults,_netdev,nfsvers=4.2  0  0
${NFS_HOST}:/volumes/${INFRA_NAME}-appdata/backups  /backups      nfs  defaults,_netdev,nfsvers=4.2  0  0
${NFS_HOST}:/volumes/${INFRA_NAME}-appdata/shares  /shares      nfs  defaults,_netdev,nfsvers=4.2  0  0
FIN

sudo systemctl daemon-reload && sudo mount -a && df -h
```

* Setup VM
```sh
make setup INSTANCE_NAME=worker-2 \
    UPDATE_DNS_RESOLVERS=1 \
    NAMESERVER1=192.168.71.213 \
    NAMESERVER2=192.168.71.1 \
    NAMESERVER3=8.8.8.8 \
    SWAP_SIZE=6G \
    && source ~/.bashrc

make add-swap-file SWAP_SIZE=12G

docker swarm join --token ${SWARM_JOIN_TOKEN} ${SWARM_JOIN_ADDR}
```

* Swarm
```sh
# On leader
docker node ls
docker node update --label-add name=atelier-1 6xqkqus6vw8u5zaguzmvyr4ah
docker node update --label-add role=atelier 6xqkqus6vw8u5zaguzmvyr4ah
```
