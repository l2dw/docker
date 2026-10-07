# Homepage

[gethomepage/homepage](https://gethomepage.dev/) — dashboard UI on **HTTP 3000** behind Traefik. **No host `ports:`** (Traefik on the overlay). Docker socket mounted **read-only** for widgets (`HOMEPAGE_DOCKER_SOCKET`).

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${HOMEPAGE_ENV_FILE:-.env.example}`; production: `HOMEPAGE_ENV_FILE=.env`. `environment:` wins on key conflicts. `APP_NAME` (default `homepage`, Dokploy may override) scopes Traefik router names.

```sh
make homepage-setup \
  HOMEPAGE_DOMAIN=homepage.example.com \
  HOMEPAGE_ALLOWED_HOSTS=homepage.example.com \
  HOMEPAGE_APP_URL=http://homepage.example.com/
make homepage-stack-up
# or
make homepage-compose-up
```

On the `homepage` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `homepage/`.

## Base path

**Not supported** for reliable subpath deploy (absolute asset paths). Keep `HOMEPAGE_BASE_PATH=/` and use a dedicated subdomain (`Host` only). Do not rely on Traefik `stripPrefix`.

## Networks

Compose declares:

```yaml
networks:
  default:
    name: ${DEFAULT_NETWORK_NAME:-homepage-network}
    external: ${DEFAULT_NETWORK_EXTERNAL:-false}
```

| Goal | `DEFAULT_NETWORK_NAME` | `DEFAULT_NETWORK_EXTERNAL` | Who creates it |
|------|------------------------|----------------------------|----------------|
| Stack-local (default) | `homepage-network` | `false` | `make homepage-setup` (`overlay` Swarm / `bridge` Compose) or Swarm/Compose on deploy |
| Shared Dokploy / Traefik | `dokploy-network` | `true` | Infra / Dokploy — **join only** |

`make homepage-setup` upserts the pair: only `dokploy-network` ⇒ `EXTERNAL=true`; any other name ⇒ `false`.

```sh
# Manual create (when EXTERNAL=false and setup has not run)
docker network create homepage-network --driver overlay   # Swarm
docker network create homepage-network --driver bridge    # Compose

# Join Dokploy overlay
# In homepage/.env:
#   DEFAULT_NETWORK_NAME=dokploy-network
#   DEFAULT_NETWORK_EXTERNAL=true
make homepage-setup
```

## Volumes

Compose key **`config`** mounts at `${HOMEPAGE_CONFIG_VOLUME_DIR:-/app/config}`:

```yaml
volumes:
  config:
    name: ${HOMEPAGE_CONFIG_VOLUME_NAME:-homepage_config}
    external: ${HOMEPAGE_CONFIG_VOLUME_EXTERNAL:-false}
    driver: ${HOMEPAGE_CONFIG_VOLUME_DRIVER:-local}
    driver_opts:
      type: ${HOMEPAGE_CONFIG_VOLUME_TYPE:-}
      o: ${HOMEPAGE_CONFIG_VOLUME_OPTS:-}
      device: ${HOMEPAGE_CONFIG_VOLUME_PATH:-}
services:
  homepage:
    volumes:
      - config:${HOMEPAGE_CONFIG_VOLUME_DIR:-/app/config}:z
```

### Recipes (`HOMEPAGE_CONFIG_VOLUME_*`)

| Mode | `EXTERNAL` | `DRIVER` | `TYPE` | `OPTS` | `PATH` |
|------|------------|----------|--------|--------|--------|
| **Local named** | `false` | `local` | empty | empty | empty |
| **Bind** (default in `.env.example`) | `false` | `local` | `none` | `bind` | host path e.g. `/appdata/homepage/config` |
| **NFS** | `false` | `local` | `nfs` | `addr=<nfs-host>,rw,nfsvers=4` | export e.g. `:/exports/homepage` |
| **External** (pre-created) | `true` | — | — | — | — ; `NAME` must already exist |

**.env examples:**

```env
# Bind (default for this stack)
HOMEPAGE_CONFIG_VOLUME_NAME=homepage_config
HOMEPAGE_CONFIG_VOLUME_EXTERNAL=false
HOMEPAGE_CONFIG_VOLUME_DRIVER=local
HOMEPAGE_CONFIG_VOLUME_TYPE=none
HOMEPAGE_CONFIG_VOLUME_OPTS=bind
HOMEPAGE_CONFIG_VOLUME_PATH=/appdata/homepage/config
HOMEPAGE_CONFIG_VOLUME_DIR=/app/config

# Local named (Compose/Swarm creates the volume)
HOMEPAGE_CONFIG_VOLUME_TYPE=
HOMEPAGE_CONFIG_VOLUME_OPTS=
HOMEPAGE_CONFIG_VOLUME_PATH=

# NFS
HOMEPAGE_CONFIG_VOLUME_TYPE=nfs
HOMEPAGE_CONFIG_VOLUME_OPTS=addr=nfs.example.com,rw,nfsvers=4
HOMEPAGE_CONFIG_VOLUME_PATH=:/exports/homepage

# Attach an existing volume
HOMEPAGE_CONFIG_VOLUME_NAME=shared_homepage_config
HOMEPAGE_CONFIG_VOLUME_EXTERNAL=true
```

### Create volumes outside Compose

When `EXTERNAL=true`, create the volume **before** deploy. Optional for NFS one-shots:

```sh
# Local named
docker volume create homepage_config

# NFS (same driver_opts as compose)
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=nfs.example.com,rw,nfsvers=4 \
  --opt device=:/exports/homepage \
  homepage_config

# Bind: ensure the host directory exists
mkdir -p /appdata/homepage/config
```

Non-external volumes are created by Compose/Swarm on deploy; setup does **not** pre-create volumes unless you opt in.

## Makefile

```sh
make homepage-setup
make homepage-pull-images
make homepage-stack-up
make homepage-stack-upgrade
make homepage-stack-down
make homepage-debug
make homepage-debug-logs
make homepage-compose-up
make homepage-compose-down
make homepage-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `APP_NAME` | Traefik router scope (default `homepage`) |
| `HOMEPAGE_DOMAIN` / `HOMEPAGE_ALLOWED_HOSTS` / `HOMEPAGE_APP_URL` | Public host (warns if `example.com`) |
| `HOMEPAGE_HOMEPAGE_URL` | Homepage discovery `href` (empty by default; set public URL later) |
| `DEFAULT_NETWORK_NAME` / `DEFAULT_NETWORK_EXTERNAL` | Default `homepage-network` / `false`; `dokploy-network` ⇒ `true` |
| `HOMEPAGE_CONFIG_VOLUME_*` | Volume name/driver/opts/path + container `*_DIR` (`/app/config`) |
| `HOMEPAGE_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `HOMEPAGE_PORT` | Container listen port (default `3000`, Traefik LB) |
