# rustfs

[RustFS](https://rustfs.com) — S3-compatible object storage (`docker.io/rustfs/rustfs`) on **9000** (API) and **9001** (Console). Default network is stack-local `rustfs-network`. For Traefik on Dokploy set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true` in `rustfs/.env`. Traefik/Homepage labels live only in `docker-compose.yml`.

Ports **9000/9001** can be published on the host via **`compose.yml` only** (`RUSTFS_S3_HOST_PORT` / `RUSTFS_CONSOLE_HOST_PORT`). Labeled `docker-compose.yml` keeps Traefik-only ingress (no host publish). One DNS name is enough behind Traefik (default `s3.example.com`): S3 at the host root, Console under PathPrefix **`/rustfs`** (UI at `/rustfs/console`).

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${RUSTFS_ENV_FILE:-.env.example}`; production: `RUSTFS_ENV_FILE=.env`. `environment:` wins on key conflicts.

`APP_NAME` (Dokploy) scopes Traefik router/service names (`${APP_NAME:-rustfs}-s3` / `-console`). It is **not** listed in `.env.example`.

Environment variable reference (upstream): [RustFS environment variables](https://docs.rustfs.com/en/reference/environment-variables) · [Docker install](https://docs.rustfs.com/en/installation/container/docker) · [Credentials](https://docs.rustfs.com/en/operations/credentials).

```sh
make rustfs-setup \
  RUSTFS_S3_DOMAIN=s3.example.com \
  RUSTFS_CONSOLE_DOMAIN=s3.example.com \
  RUSTFS_CONSOLE_URL=http://s3.example.com/rustfs
make rustfs-stack-up
# or
make rustfs-compose-up
```

On the `rustfs` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `rustfs/`.

## Base path / Console URL

**S3 API:** AWS Signature V4 includes the request path — do **not** put the API under a prefix or `stripPrefix`. Default `RUSTFS_BASE_PATH=/` is unused. Traefik: `Host(RUSTFS_S3_DOMAIN)` → port **9000**.

**Console:** Traefik PathPrefix default `RUSTFS_CONSOLE_PATH=/rustfs` (covers `/rustfs/console`, `/rustfs/admin`; also `/browser` for the SPA) → port **9001**. **No `stripPrefix`.** Listen addresses use image defaults (9000/9001); do not set `RUSTFS_ADDRESS` / `RUSTFS_CONSOLE_ADDRESS`.

Open **`http://s3.example.com/rustfs/console`** (or `/rustfs`). S3 clients: endpoint `http://s3.example.com`, **path-style** (`forcePathStyle: true`). Avoid a bucket named `rustfs` if objects would collide with `/rustfs/*`. A dedicated Console hostname remains the [official Traefik layout](https://docs.rustfs.com/en/developer/integration/reverse-proxy/traefik) if login/API calls to `/` mis-route to S3.

## Host ports (`compose.yml` only)

Unlabeled `compose.yml` (and `multi-disk.compose.yml`) publish S3 and Console on the host. Targets stay **9000** / **9001**; set the **host** ports with:

| Variable | Default | Role |
|----------|---------|------|
| `RUSTFS_S3_HOST_PORT` | `9000` | Host port → container S3 `9000` |
| `RUSTFS_CONSOLE_HOST_PORT` | `9001` | Host port → container Console `9001` |
| `RUSTFS_S3_PORT_MODE` / `RUSTFS_CONSOLE_PORT_MODE` | `ingress` | Swarm publish mode: `ingress` \| `host` |

```sh
# Local Compose with host mapping
docker compose -f rustfs/compose.yml --env-file rustfs/.env up -d
# → localhost:9000 (S3), localhost:9001 (Console)
```

Do **not** rely on these publishes when Traefik is the ingress (`docker-compose.yml` / `make rustfs-stack-up`).

## MinIO Client (`mc`)

RustFS is S3-compatible — use the [MinIO Client (`mc`)](https://min.io/docs/minio/linux/reference/minio-mc.html) against the API endpoint.

**Install** (pick one):

```sh
# Homebrew
brew install minio/stable/mc
# or: brew install minio-mc   # may conflict with midnight-commander’s `mc` binary

# Linux amd64 binary
curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc
chmod +x /usr/local/bin/mc
```

Upstream install notes: [mc Quickstart](https://minio.github.io/mc/) · [MinIO mc reference](https://min.io/docs/minio/linux/reference/minio-mc.html).

**Alias + smoke test** (after setup; path-style endpoint):

```sh
mc alias set rustfs http://127.0.0.1:9000 "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY"
# or via Traefik: mc alias set rustfs http://s3.example.com "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY"
mc mb rustfs/my-bucket
mc ls rustfs
```

## Credentials and volumes

`make rustfs-setup` generates `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` if empty. Do not use the well-known `rustfsadmin` pair in production.

Named volumes: `/data` (objects) and `/var/log/rustfs` (logs). Container runs as user `rustfs` (UID 10001) — bind mounts must be writable by that user.

## Multiple disks (SNMD)

Default stack is **SNSD** (single disk): `RUSTFS_VOLUMES=/data` and one mount at `/data`. There is **no** `command:` — RustFS reads volumes from `RUSTFS_VOLUMES` ([env reference](https://docs.rustfs.com/en/reference/environment-variables), [SNMD](https://docs.rustfs.com/en/installation/linux/single-node-multiple-disk)).

Do **not** treat extra mounts as separate S3 buckets — they form **one** erasure pool.

| Goal | How |
|------|-----|
| More disks, one server | SNMD: set `RUSTFS_VOLUMES=/data/rustfs{0...3}` (**three** dots) + mount each path |
| HA / several servers | [MNMD](https://docs.rustfs.com/en/installation/linux/multiple-node-multiple-disk) — not `replicas: N` on one volume |
| One NFS share | Keep SNSD: one bind/NFS → `/data`, `RUSTFS_VOLUMES=/data` |

**Independence:** each path should be a different device (`st_dev`). Bind each disk (or NFS export) separately. **UID 10001:10001** on all data paths.

### How to enable multi-disk

**1. Example file (copy / try):** `rustfs/multi-disk.compose.yml` — unlabeled SNMD sample (4 named volumes + host ports). Not the default Make target.

```sh
docker compose -f rustfs/multi-disk.compose.yml --env-file rustfs/.env up -d
```

Edit that file to swap named volumes for **binds** (`/mnt/disk0:/data/rustfs0`) or **external** volumes (`external: true`).

**2. Override on the main stack** (recommended for Traefik / `make rustfs-*-up`): gitignored `rustfs/docker-compose.override.yml` or `stack-compose.override.yml`. Make merges it automatically (`bin/resolve-project-compose.sh`).

```yaml
# rustfs/docker-compose.override.yml (example)
volumes:
  rustfs0:
    # external: true          # pre-created volume
    # or NFS driver_opts / bind via service volumes below
  rustfs1:
  rustfs2:
  rustfs3:

services:
  rustfs:
    environment:
      - RUSTFS_VOLUMES=/data/rustfs{0...3}
    volumes: !override       # Compose v2.24+ — replace base mounts (drop unused /data)
      - rustfs0:/data/rustfs0
      - rustfs1:/data/rustfs1
      - rustfs2:/data/rustfs2
      - rustfs3:/data/rustfs3
      - rustfs-logs:/var/log/rustfs
      # or binds: /mnt/disk0:/data/rustfs0
```

Without `!override`, Compose **appends** volumes and the base `rustfs-data:/data` remains (usually harmless if unused). Also set `RUSTFS_VOLUMES=/data/rustfs{0...3}` in `rustfs/.env` (and root `.env` for Swarm).

**3. External volumes only:** create volumes ahead of time, mark them `external: true` in the override / example file, keep `RUSTFS_VOLUMES` in sync with mount targets.

Do **not** commit override files (`**/*.override.*` is gitignored).

## Makefile

```sh
make rustfs-setup
make rustfs-pull-images
make rustfs-stack-up
make rustfs-stack-upgrade
make rustfs-stack-down
make rustfs-debug
make rustfs-debug-logs
make rustfs-compose-up
make rustfs-compose-down
make rustfs-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `RUSTFS_S3_DOMAIN` | Traefik Host() for S3 API (warns if `example.com`) |
| `RUSTFS_CONSOLE_DOMAIN` | Traefik Host() for Console (default: same as S3) |
| `RUSTFS_CONSOLE_PATH` | Console PathPrefix (default `/rustfs`; covers `/rustfs/console`) |
| `RUSTFS_S3_URL` / `RUSTFS_CONSOLE_URL` | Public URLs (Homepage href = console URL) |
| `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` | Generated by setup if empty |
| `RUSTFS_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `RUSTFS_VOLUMES` | Default `/data` (SNSD). SNMD: `/data/rustfs{0...3}` + mounts — see README |
| `RUSTFS_S3_HOST_PORT` / `RUSTFS_CONSOLE_HOST_PORT` | Host publish in `compose.yml` / example `multi-disk.compose.yml` only |
| Server env (full list) | [docs.rustfs.com — environment variables](https://docs.rustfs.com/en/reference/environment-variables) |

Do not commit `rustfs/.env` or real secrets.
