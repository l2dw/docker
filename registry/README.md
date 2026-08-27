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

Unlabeled `compose.yml` publishes `REGISTRY_HOST_PORT` (default 5000). Labeled `docker-compose.yml` is Traefik-only. Prefer **Host-only** (`REGISTRY_BASE_PATH=/`) for docker CLI.

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
| `REGISTRY_HOST_PORT` | Host publish in `compose.yml` only |

Do not commit `registry/.env` or real secrets.
