# s3-mirror

Permanent **MinIO Client (`mc`) mirror** between two targets while the pod is running.

Each of **SRC** and **DST** is either:

- `s3` — S3-compatible bucket (`ENDPOINT` + keys + `BUCKET` + optional `PREFIX`)
- `path` — directory under the Compose volume (`/data`, optional `S3_MIRROR_*_PATH`)

Couples: bucket↔folder, folder↔bucket, **bucket↔bucket**.

| `S3_MIRROR_MODE` | Behaviour |
|------------------|-----------|
| `uni` (default) | `mc mirror --watch SRC DST` (blocks until stop) |
| `bi` | Two crossed watches; **avoid `--remove` on both sides** (delete loops) |

Image: Alpine + `mc` ([`Dockerfile`](Dockerfile)) — official `minio/mc` is often scratch (no shell). Default tag `s3-mirror:local` (built by `make s3-mirror-setup`).

**Base path:** N/A (no HTTP app). `S3_MIRROR_BASE_PATH=/`. Traefik omitted in v1.

## Quick start

```sh
make s3-mirror-setup
# edit s3-mirror/.env — set SRC/DST credentials or bind path
make s3-mirror-compose-up
# or Swarm:
make s3-mirror-stack-up
```

Production: set `S3_MIRROR_ENV_FILE=.env` and keep secrets out of git. Compose merges `env_file` + `environment:` (`environment:` wins). Swarm relies on Make-exported root `.env` + `environment:` interpolation (`env_file` is not equivalent under `docker stack deploy`).

`APP_NAME=s3-mirror` scopes Homepage label identity; Dokploy may override `APP_NAME`.

## Networks

Default: stack-local `s3-mirror-network` with `DEFAULT_NETWORK_EXTERNAL=false`.  
`make s3-mirror-setup` upserts `DEFAULT_NETWORK_EXTERNAL` to **`true` only** when `DEFAULT_NETWORK_NAME=dokploy-network`; any other name (including empty → fallback `s3-mirror-network`) → `false`, and creates the network when external is false.

```sh
# Join Dokploy / Traefik overlay
# In s3-mirror/.env:
#   DEFAULT_NETWORK_NAME=dokploy-network
#   DEFAULT_NETWORK_EXTERNAL=true
make s3-mirror-setup
```

## Volumes

Compose key **`data`** mounts at `${S3_MIRROR_DATA_VOLUME_DIR:-/data}`:

| Mode | `EXTERNAL` | `DRIVER` | `TYPE` | `OPTS` | `PATH` |
|------|------------|----------|--------|--------|--------|
| Local named | `false` | `local` | empty | empty | empty |
| Bind | `false` | `local` | `none` | `bind` | host path e.g. `/appdata/homepage/config` |
| NFS | `false` | `local` | `nfs` | `addr=<host>,rw,nfsvers=4` | export e.g. `:/exports/s3-mirror` |
| External | `true` | — | — | — | — ; `NAME` must exist |

```sh
# Bind for Homepage config sync (bucket → host dir)
S3_MIRROR_SRC_TYPE=s3
S3_MIRROR_DST_TYPE=path
S3_MIRROR_MODE=uni
S3_MIRROR_DATA_VOLUME_TYPE=none
S3_MIRROR_DATA_VOLUME_OPTS=bind
S3_MIRROR_DATA_VOLUME_PATH=/appdata/homepage/config
```

## Recipes

**Bucket → folder (uni)** — Homepage-style:

```env
S3_MIRROR_SRC_TYPE=s3
S3_MIRROR_SRC_ENDPOINT=https://minio.example.com
S3_MIRROR_SRC_ACCESS_KEY=...
S3_MIRROR_SRC_SECRET_KEY=...
S3_MIRROR_SRC_BUCKET=homepage-config
S3_MIRROR_DST_TYPE=path
S3_MIRROR_MODE=uni
```

**Bucket → bucket (uni):**

```env
S3_MIRROR_SRC_TYPE=s3
S3_MIRROR_DST_TYPE=s3
# set both *_ENDPOINT / keys / BUCKET
```

**Bi-directional path ↔ bucket:**

```env
S3_MIRROR_MODE=bi
S3_MIRROR_MC_OPTS=--overwrite
# Do not add --remove on both directions without a conflict strategy
```

## Make targets

| Target | Role |
|--------|------|
| `s3-mirror-setup` | `.env`, network upsert, build image if missing |
| `s3-mirror-stack-up\|down\|recreate\|upgrade\|logs` | Swarm |
| `s3-mirror-compose-up\|down\|restart\|logs\|recreate` | Compose |
| `s3-mirror-debug`, `s3-mirror-debug-logs`, `s3-mirror-pull-images` | Ops |

## Homepage use case

Bind `S3_MIRROR_DATA_VOLUME_PATH` to the same host path Homepage uses (`/appdata/homepage/config`), `SRC=s3` / `DST=path` / `MODE=uni`. The mirror keeps the folder updated for as long as the pod runs.
