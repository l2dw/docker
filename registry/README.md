# Registry

Private [Docker Distribution](https://distribution.github.io/distribution/) Registry v2 (`docker.io/library/registry:2`) with **htpasswd** auth. Listens on **5000**.

Default network is stack-local `registry-network`. For Traefik on Dokploy set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true`. Traefik/Homepage labels live only in `docker-compose.yml`.

## Credentials (env vars — no host htpasswd / make required)

The registry binary does **not** read username/password from the environment. This stack’s `docker-entrypoint.sh` (Compose/Swarm **config**) builds a bcrypt htpasswd at start from:

| Variable | Default | Role |
|----------|---------|------|
| `REGISTRY_USER_NAME` | `dockeradm` | Basic-auth user |
| `REGISTRY_USER_PASS` | `ChangeMe` | Basic-auth password — **rotate in production** |
| `REGISTRY_AUTH_HTPASSWD_PATH` | `/auth/htpasswd` | File written inside the container |

Set them in `registry/.env`, root `.env` (Swarm/Make), or the Dokploy UI. First start needs outbound access to Alpine repos once (`apk add apache2-utils` for `htpasswd`).

```env
REGISTRY_USER_NAME=dockeradm
REGISTRY_USER_PASS=your-strong-password
```

```sh
docker login registry.example.com -u dockeradm -p 'your-strong-password'
```

Unlabeled `compose.yml` and labeled `docker-compose.yml` both publish **`REGISTRY_HOST_PORT`** (default **5000**). Prefer **Host-only** Traefik path (`REGISTRY_BASE_PATH=/`) if you also enable Traefik.

## Direct access from nodes (no Traefik)

Default: Traefik labels **off**; port published with **`REGISTRY_PORT_MODE=ingress`** so **any Swarm node** accepts `IP_du_noeud:5000` and the mesh routes to the registry task.

```sh
# On any cluster node (or LAN client that can reach a node IP)
docker login 10.0.0.12:5000 -u dockeradm -p '…'
docker pull 10.0.0.12:5000/myimage:tag
```

| Setting | Effect |
|---------|--------|
| `REGISTRY_PORT_MODE=ingress` (default) | `:5000` on **every** node via routing mesh |
| `REGISTRY_PORT_MODE=host` | `:5000` only on the node running the task |
| `REGISTRY_HOST_PORT=5001` | Change if `:5000` is already taken on the mesh / host |

Containers on the **same Docker network** can use DNS without the published port: `registry:5000` (Compose) or `registry_registry:5000` (Swarm stack name).

Optional HTTPS / public name: set `REGISTRY_TRAEFIK_LABELS_SWARM_ENABLE=true` (and Docker enable) + join `dokploy-network` — Traefik and `:5000` can coexist.

## Docker client (login, insecure, catalog, tags)

Replace `REG` with your endpoint (examples: `10.0.0.12:5000`, `registry.example.com:5000`). Plain HTTP on `:5000` needs an **insecure registry** entry on each Docker host that pulls/pushes.

### Insecure registry (HTTP)

Edit `/etc/docker/daemon.json` (create if missing), then restart Docker:

```json
{
  "insecure-registries": ["10.0.0.12:5000", "registry.example.com:5000"]
}
```

```sh
# Linux
sudo systemctl restart docker
# confirm
docker info 2>/dev/null | grep -A20 'Insecure Registries'
```

Without this, `docker pull/push` to `http://host:5000` fails with “HTTP response to HTTPS client” / similar. TLS via Traefik does **not** need `insecure-registries` (use normal HTTPS + `docker login` to the hostname).

### Login / logout

```sh
export REG=10.0.0.12:5000
export REGISTRY_USER_NAME=dockeradm
export REGISTRY_USER_PASS='your-strong-password'

docker login "$REG" -u "$REGISTRY_USER_NAME" -p "$REGISTRY_USER_PASS"
# credentials stored under ~/.docker/config.json
docker logout "$REG"
```

### Push / pull

```sh
export REG=10.0.0.12:5000
docker pull alpine:latest
docker tag alpine:latest "$REG/alpine:latest"
docker push "$REG/alpine:latest"
docker pull "$REG/alpine:latest"
```

Image names **must** include the registry host (`$REG/...`). Nested paths work: `$REG/team/app:1.2.3`.

### List repositories (catalog)

Docker CLI has no `docker search` for a private Distribution registry. Use the [Registry HTTP API V2](https://distribution.github.io/distribution/spec/api/):

```sh
export REG=10.0.0.12:5000
export AUTH=(-u "$REGISTRY_USER_NAME:$REGISTRY_USER_PASS")

# API reachable?
curl -fsS "${AUTH[@]}" "http://$REG/v2/" && echo OK

# List repositories (“packages” / images)
curl -fsS "${AUTH[@]}" "http://$REG/v2/_catalog"
# paginate if needed:
curl -fsS "${AUTH[@]}" "http://$REG/v2/_catalog?n=1000"

# Pretty (optional jq)
curl -fsS "${AUTH[@]}" "http://$REG/v2/_catalog" | jq -r '.repositories[]'
```

### List tags for an image

```sh
IMG=alpine   # repository name from _catalog (no host prefix)
curl -fsS "${AUTH[@]}" "http://$REG/v2/$IMG/tags/list"
curl -fsS "${AUTH[@]}" "http://$REG/v2/$IMG/tags/list" | jq -r '.tags[]'
```

Nested repo: `curl … "http://$REG/v2/team/app/tags/list"`.

### Inspect manifest / digest

```sh
TAG=latest
curl -fsS "${AUTH[@]}" \
  -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
  "http://$REG/v2/$IMG/manifests/$TAG"
# digest header (for delete):
curl -fsSI "${AUTH[@]}" \
  -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
  "http://$REG/v2/$IMG/manifests/$TAG" | tr -d '\r' | grep -i Docker-Content-Digest
```

### Delete a tag/manifest (optional)

Requires `REGISTRY_STORAGE_DELETE_ENABLED=true` (default in this stack). GC inside the registry is a separate ops step.

```sh
DIGEST='sha256:…'   # from Docker-Content-Digest above
curl -fsS -X DELETE "${AUTH[@]}" "http://$REG/v2/$IMG/manifests/$DIGEST"
```

### Quick smoke test

```sh
export REG=10.0.0.12:5000
docker login "$REG" -u dockeradm -p ChangeMe
docker pull busybox:latest
docker tag busybox:latest "$REG/busybox:test"
docker push "$REG/busybox:test"
curl -fsS -u dockeradm:ChangeMe "http://$REG/v2/_catalog"
curl -fsS -u dockeradm:ChangeMe "http://$REG/v2/busybox/tags/list"
```

`.env` is **not** read by `docker stack deploy` alone — use Make or export env in Dokploy. Compose `env_file` + `environment:` (`environment:` wins).

`APP_NAME` (Dokploy) scopes Traefik names; not listed in `.env.example`.

## Base path

Keep `REGISTRY_BASE_PATH=/`. PathPrefix subpaths break typical `docker push/pull` (`host/v2`).

## Storage (`registry_data`)

Defaults: Docker **named volume** (interne). `driver=local` with **empty** `driver_opts` (`type` / `o` / `device`) — do not set `type=local` or `device=:`.

Service mount: `${REGISTRY_DATA_DIR:-registry_data}:/var/lib/registry` (empty `REGISTRY_DATA_DIR` → named volume).

| Mode | Env |
|------|-----|
| **Interne** (défaut) | `REGISTRY_DATA_VOLUME_EXTERNAL=false`, leave `REGISTRY_DATA_DRIVER_TYPE` / `_O` / `_DEVICE` empty |
| **Externe** | Pré-créer le volume, puis `REGISTRY_DATA_VOLUME_EXTERNAL=true` (Compose n’applique plus `driver_opts`) |
| **Disque local (bind)** | `REGISTRY_DATA_DRIVER_TYPE=none`, `REGISTRY_DATA_DRIVER_O=bind`, `REGISTRY_DATA_DRIVER_DEVICE=/abs/path` (Compose peut résoudre `./data` → absolu ; Swarm : chemin **absolu** sur le nœud). Créer le dossier avant. |
| **NFS** | `REGISTRY_DATA_DRIVER_TYPE=nfs`, `REGISTRY_DATA_DRIVER_O=addr=nfs.example.com,rw,nfsvers=4,nolock`, `REGISTRY_DATA_DRIVER_DEVICE=:/exports/registry_data` |

**Bind alternatif** (sans `driver_opts`) : `REGISTRY_DATA_DIR=/mnt/registry` sur le mount service.

```env
# Interne (défaut)
REGISTRY_DATA_VOLUME_EXTERNAL=false
REGISTRY_DATA_DRIVER_TYPE=
REGISTRY_DATA_DRIVER_O=
REGISTRY_DATA_DRIVER_DEVICE=

# Bind disque local
# REGISTRY_DATA_DRIVER_TYPE=none
# REGISTRY_DATA_DRIVER_O=bind
# REGISTRY_DATA_DRIVER_DEVICE=/mnt/registry   # or ./data under Compose

# NFS
# REGISTRY_DATA_DRIVER_TYPE=nfs
# REGISTRY_DATA_DRIVER_O=addr=nfs.example.com,rw,nfsvers=4,nolock
# REGISTRY_DATA_DRIVER_DEVICE=:/exports/registry_data

# Volume déjà créé
# REGISTRY_DATA_VOLUME_EXTERNAL=true
# docker volume create --driver local --opt type=none --opt o=bind --opt device=/mnt/registry registry_data
```

`external: true` → le volume doit exister ; `driver` / `driver_opts` du YAML sont ignorés.

## Quick start

```sh
# Optional local Make helpers
make registry-setup REGISTRY_DOMAIN=registry.example.com REGISTRY_APP_URL=https://registry.example.com
# Edit REGISTRY_USER_PASS in registry/.env, then:
make registry-compose-up    # or: make registry-stack-up
```

Dokploy: set env vars (including `REGISTRY_USER_*`), deploy the compose from this repo (needs `docker-entrypoint.sh` next to the compose file for the config mount).

## Makefile

```sh
make registry-setup
make registry-pull-images
make registry-stack-up
make registry-stack-upgrade
make registry-stack-down
make registry-debug
make registry-debug-logs
make registry-compose-up
make registry-compose-down
make registry-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `REGISTRY_DOMAIN` / `REGISTRY_APP_URL` | Traefik Host + public URL |
| `REGISTRY_USER_NAME` / `REGISTRY_USER_PASS` | Auth (entrypoint → htpasswd) |
| `REGISTRY_HTTP_SECRET` | Optional upload signing key |
| `REGISTRY_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `REGISTRY_HOST_PORT` / `REGISTRY_PORT_MODE` | Direct `:5000` on nodes (`ingress` = mesh on all nodes) |
| `REGISTRY_TRAEFIK_LABELS_*_ENABLE` | Default `false` — optional public Traefik route |

Do not commit `registry/.env` or real secrets.
