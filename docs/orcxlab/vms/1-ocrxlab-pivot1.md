# OCRX Infrastructure

## Instances (arbutus.alliancecan.ca)

1. pivot.ocrx: 64Go - P4-6G

### Infra

```sh
INFRA_NAME=ocrxlab
sudo mkdir -p /opt/${INFRA_NAME} && sudo chown ubuntu:ubuntu /opt/${INFRA_NAME}
## Git
cd /opt/${INFRA_NAME} && git init
git remote add origin ${GIT_REPO:-https://github.com/l2dw/docker.git}
git fetch origin && git checkout dokploy

## Packages
# ./bin/install-utilities-packages.sh

## Environments variables
sudo tee ~/.env << FIN > /dev/null

# Dokploy
# ── Dokploy (see also dokploy/.env.example) ──────────────────────────────────
DOKPLOY_TRAEFIK_LABELS_SWARM_ENABLE=true
DOKPLOY_TRAEFIK_LABELS_DOCKER_ENABLE=false

# Swarm placement (one constraint string per service). No nested fallbacks — set each key.
# Examples: node.hostname==pivot01 | node.labels.zone==dmz | node.platform.os==linux
DOKPLOY_PLACEMENT_CONSTRAINTS=node.labels.name==pivot1
DOKPLOY_POSTGRES_PLACEMENT_CONSTRAINTS=node.labels.name==pivot1
DOKPLOY_REDIS_PLACEMENT_CONSTRAINTS=node.labels.name==pivot1
DOKPLOY_DOKPLOY_PLACEMENT_CONSTRAINTS=node.labels.name==pivot1
DOKPLOY_TRAEFIK_PLACEMENT_CONSTRAINTS=node.labels.name==pivot1
DOKPLOY_CERTS_DUMPER_PLACEMENT_CONSTRAINTS=node.labels.name==pivot1
DOKPLOY_WAF_PLACEMENT_CONSTRAINTS=node.labels.name==pivot1

# ## Dokploy
DOKPLOY_DOKPLOY_IMAGE=docker.io/dokploy/dokploy:latest
DOKPLOY_DATABASE_URL=postgres://postgres:ChangeMe@dokploy-postgresql:5432/dokploy
DOKPLOY_REDIS_URL=redis://dokploy-redis:6379
DOKPLOY_PORT=3000
DOKPLOY_DOMAIN=134-87-11-3.arbutus.alliancecan.ca
DOKPLOY_ENTRYPOINTS=websecure
DOKPLOY_BASE_PATH=/
DOKPLOY_MIDDLEWARES=
DOKPLOY_TLS_ENABLED=true
DOKPLOY_TLS_CERTRESOLVER=letsencrypt
DOKPLOY_ALLOWED_ORIGINS=https://134-87-11-3.arbutus.alliancecan.ca
DOKPLOY_BETTER_AUTH_TRUSTED_ORIGINS=https://134-87-11-3.arbutus.alliancecan.ca,http://localhost:3000
DOKPLOY_HOMEPAGE_GROUP=Infra
DOKPLOY_HOMEPAGE_NAME=Dokploy
DOKPLOY_HOMEPAGE_ICON=dokploy.png
DOKPLOY_HOMEPAGE_HREF=https://134-87-11-3.arbutus.alliancecan.ca
DOKPLOY_PRIVILEGED=false
DOKPLOY_DATA_DIR=/volumes/ocrx-appdata/dokploy
DOKPLOY_LOGS_DIR=
# ##Dokploy Postgres
DOKPLOY_POSTGRES_IMAGE=docker.io/postgres:16
DOKPLOY_POSTGRES_PASSWORD=ChangeMe
DOKPLOY_POSTGRES_USER=postgres
DOKPLOY_POSTGRES_DB=dokploy
DOKPLOY_POSTGRES_PRIVILEGED=false
DOKPLOY_POSTGRES_DATA_DIR=/volumes/ocrx-appdata/postgresql
# DOKPLOY_POSTGRES_LOGS_DIR=/volumes/ocrx-appdata/logs/postgresql
# DOKPLOY_POSTGRES_DATA_VOLUME_NAME=dokploy-postgresql_data
# DOKPLOY_POSTGRES_DATA_VOLUME_EXTERNAL=false
# DOKPLOY_POSTGRES_LOGS_VOLUME_NAME=dokploy-postgresql_logs
# DOKPLOY_POSTGRES_LOGS_VOLUME_EXTERNAL=false
# ## Dokploy Redis
DOKPLOY_REDIS_IMAGE=docker.io/redis:7
DOKPLOY_REDIS_PASSWORD=
DOKPLOY_REDIS_USER=
DOKPLOY_REDIS_DB=
DOKPLOY_REDIS_PRIVILEGED=false
DOKPLOY_REDIS_DATA_DIR=
DOKPLOY_REDIS_LOGS_DIR=
DOKPLOY_REDIS_DATA_VOLUME_NAME=/volumes/ocrx-appdata/redis
# DOKPLOY_REDIS_DATA_VOLUME_EXTERNAL=false
# DOKPLOY_REDIS_LOGS_VOLUME_NAME=dokploy-redis_logs
# DOKPLOY_REDIS_LOGS_VOLUME_EXTERNAL=false
# ## Traefik
DOKPLOY_TRAEFIK_IMAGE=docker.io/traefik:latest
DOKPLOY_TRAEFIK_LOGS_VOLUME_NAME=dokploy-traefik_logs
DOKPLOY_TRAEFIK_LOGS_VOLUME_EXTERNAL=true
DOKPLOY_TRAEFIK_CONFIG_VOLUME_NAME=dokploy-traefik_config
DOKPLOY_TRAEFIK_CONFIG_VOLUME_EXTERNAL=false
DOKPLOY_TRAEFIK_CERTIFICATES_VOLUME_NAME=dokploy-traefik_certificates
DOKPLOY_TRAEFIK_CERTIFICATES_VOLUME_EXTERNAL=false
DOKPLOY_TRAEFIK_RULES_VOLUME_NAME=dokploy-traefik_rules
DOKPLOY_TRAEFIK_RULES_VOLUME_EXTERNAL=false
DOKPLOY_TRAEFIK_PRIVILEGED=false
DOKPLOY_TRAEFIK_LOGS_DIR=
# Compose-only restart (Swarm uses deploy.restart_policy). Set per service — no nested fallback.
# unless-stopped | on-failure | always | no
DOKPLOY_RESTART=unless-stopped
DOKPLOY_POSTGRES_RESTART=unless-stopped
DOKPLOY_REDIS_RESTART=unless-stopped
DOKPLOY_DOKPLOY_RESTART=unless-stopped
DOKPLOY_TRAEFIK_RESTART=unless-stopped
DOKPLOY_CERTS_DUMPER_RESTART=unless-stopped
DOKPLOY_WAF_RESTART=unless-stopped
# Basic auth for dashboard (optional). Hash from: htpasswd -nb user pass | sed 's/\$/$$/g'  (Compose needs $$ for each $ in the hash)
# DOKPLOY_TRAEFIK_BASIC_AUTH_CREDENTIALS=admin:$$apr1$$...
DOKPLOY_TRAEFIK_CONFIG_DIR=
DOKPLOY_TRAEFIK_RULES_DIR=
DOKPLOY_TRAEFIK_LOG_LEVEL=INFO
DOKPLOY_TRAEFIK_ACCESS_LOG_FORMAT=json
DOKPLOY_TRAEFIK_EMAIL=cenadmin@listes.umontreal.ca
DOKPLOY_TRAEFIK_PROVIDERS_SWARM=true
DOKPLOY_TRAEFIK_PROVIDERS_DOCKER=false
# Extra CLI flags (optional)
# DOKPLOY_TRAEFIK_COMMAND=
DOKPLOY_TRAEFIK_BASE_PATH=/traefik
# Entrypoint middlewares (comma-separated). Example: waf or waf@file
DOKPLOY_TRAEFIK_WEB_MIDDLEWARES=waf
DOKPLOY_TRAEFIK_WEBSECURE_MIDDLEWARES=waf
# Real client IP: trust X-Forwarded-* from these CIDRs (LB / docker nets).
DOKPLOY_TRAEFIK_FORWARDED_HEADERS_TRUSTED_IPS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1/32,::1/128
DOKPLOY_TRAEFIK_FORWARDED_HEADERS_INSECURE=false
DOKPLOY_TRAEFIK_TRANSPORT_READ_TIMEOUT=600s
DOKPLOY_TRAEFIK_TRANSPORT_WRITE_TIMEOUT=600s
DOKPLOY_TRAEFIK_TRANSPORT_IDLE_TIMEOUT=180s
DOKPLOY_TRAEFIK_ENTRYPOINTS=web
DOKPLOY_TRAEFIK_TLS_ENABLED=false
DOKPLOY_TRAEFIK_TLS_CERTRESOLVER=letsencrypt
DOKPLOY_TRAEFIK_MIDDLEWARES=
DOKPLOY_TRAEFIK_PORT_MODE=host
DOKPLOY_TRAEFIK_PORT80_PUBLISHED=80
DOKPLOY_TRAEFIK_PORT443_PUBLISHED=443
# ## WAF (ModSecurity CRS)
DOKPLOY_WAF_IMAGE=docker.io/owasp/modsecurity-crs:4.27.0-apache-202606290906
DOKPLOY_WAF_LOGS_DIR=
DOKPLOY_WAF_PROXY=1
# Space-separated CIDRs (Apache RemoteIPInternalProxy). Commas break httpd-vhosts.conf generation.
DOKPLOY_WAF_REMOTEIP_INT_PROXY="10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.1/32"
# Label middleware → CRS (port 8080). File twin: etc/traefik/rules/middlewares.yml (waf@file)
DOKPLOY_WAF_MODSECURITY_URL=http://waf:8080
DOKPLOY_WAF_MAX_BODY_SIZE=10485760
DOKPLOY_WAF_TIMEOUT_MILLIS=2000
# Swarm configs sourced from repo (etc/waf/rules/). Paths are read on the deploying manager at stack deploy.
DOKPLOY_WAF_BEFORE_CRS_RULES=../etc/waf/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
DOKPLOY_WAF_AFTER_CRS_RULES=../etc/waf/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
# Bump names when rotating immutable configs after content changes, e.g. dokploy_waf_before_crs_v2
DOKPLOY_WAF_BEFORE_CRS_CONFIG_NAME=dokploy_waf_before_crs
DOKPLOY_WAF_AFTER_CRS_CONFIG_NAME=dokploy_waf_after_crs
FIN


make setup \
    INSTANCE_NAME=pivot1 \
    INFRA_NAME=ocrxlab \
    INFRA_DOMAIN=arbutus-cloud \
    ADMIN_USER=ubuntu \
    INFRA_DIR=/opt/ocrxlab \
    APPDATA_DIR=/appdata \
    CERTS_DIR=/shares/certs \
    BACKUPS_DIR=/backups \
    LOGS_DIR=/appdata/logs \
    DATA_DIR=/data \
    ENABLE_SWAP_FILE=1 \
    SWAP_SIZE=8G \
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
