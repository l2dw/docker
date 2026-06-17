# Infrastructure deployment (Swarm + Traefik)

`make deploy-infrastructure` runs `bin/setup-swarm.sh` then `bin/deploy-infrastructure.sh`, which deploys [`docker-compose.yaml`](../docker-compose.yaml) as stack **`infrastructure`**.

## Prerequisites

- **`make setup`** (or equivalent) so `/etc/environment` defines paths and `bin/setup-filesystem.sh` has created host directories.
- **`CERTS_DIR`** (default **`/etc/certs`**) must exist on **every Swarm node** that can run Traefik. The `certs_volume` bind-mounts this path; if it is missing, tasks fail with:

  `failed to mount local volume: mount /etc/certs:... no such file or directory`

  `deploy-infrastructure.sh` runs `sudo mkdir -p` for `APPDATA_DIR` and `CERTS_DIR` before creating volumes—run deploy on a manager after `setup`, or create the directories manually on each node that matches Traefik’s placement constraints (e.g. `node.role==manager`).

- External **`mysql_root_password`** secret if your compose file references it (create with `docker secret create` before deploy).

## Traefik logging

Compose sets `--log.level=${TRAEFIK_LOG_LEVEL:-INFO}`. For more verbose logs when debugging:

```bash
export TRAEFIK_LOG_LEVEL=DEBUG
make deploy-infrastructure
```

## Useful commands

```bash
docker service ps infrastructure_traefik --no-trunc
docker service logs infrastructure_traefik --tail 100
docker stack services infrastructure
```
