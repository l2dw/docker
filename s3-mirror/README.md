# s3-mirror

Periodic **one-way [rclone](https://rclone.org) copy/sync** between two targets while the container runs.

Each of **SRC** and **DST** is either:

- `s3` — S3-compatible bucket (`ENDPOINT` + keys + `BUCKET` + optional `PREFIX`)
- `path` — directory under the side volume (`SRC` → `/src` read-only, `DST` → `/dst`; optional `S3_MIRROR_*_PATH`, relative to the volume)

Couples: folder → bucket, bucket → folder, **bucket → bucket**.

| `S3_MIRROR_MODE` | Behaviour |
|------------------|-----------|
| `sync` (default) | `rclone sync`: DST becomes identical to SRC. Deletions propagate, capped per pass by `S3_MIRROR_MAX_DELETE` (default 10). Enable **bucket versioning** to keep deleted files |
| `copy` | `rclone copy`: new/changed files are copied, **nothing is ever deleted on DST** |

The loop runs one pass every `S3_MIRROR_INTERVAL` seconds (default 3600, min 10). Files are compared by checksum. `S3_MIRROR_EXCLUDE` takes comma-separated rclone patterns (e.g. `logs/**,*.tmp`); `S3_MIRROR_RCLONE_OPTS` adds extra flags.

**Safety guards**

- A pass is **skipped** (error logged) when a local `path` source is missing or empty, so a `sync` can never empty the destination because of an unmounted source.
- The source volume is mounted **read-only**.
- Credentials are handed to rclone through `RCLONE_CONFIG_*` environment variables: no config file, nothing in argv or logs.

**Healthcheck:** `entrypoint.sh health` succeeds when the last successful pass is not older than `2 × INTERVAL + 120 s` (unhealthy until the first success).

Image: official `docker.io/rclone/rclone` (pinned tag, **no build**). The script [`bin/entrypoint.sh`](bin/entrypoint.sh) is delivered as a Compose/Swarm **config** (`S3_MIRROR_ENTRYPOINT_CONFIG_NAME`; configs are immutable — bump the `_vN` suffix after editing the script).

> Replaces the former `mc mirror --watch` engine (`Dockerfile` downloading `mc`): `dl.min.io` now answers HTTP 410 and `minio/mc` images are no longer pullable. The `bi` mode was dropped (use two instances with `copy` if really needed). `S3_MIRROR_MC_OPTS` → `S3_MIRROR_RCLONE_OPTS`; `uni` → `sync` (default) or `copy`.

**Base path:** N/A (no HTTP app). `S3_MIRROR_BASE_PATH=/`. Traefik omitted. `compose.yml` and `docker-compose.yml` are identical.

## Quick start

```sh
make s3-mirror-setup
# edit s3-mirror/.env — SRC/DST type, credentials, volume recipes
make s3-mirror-compose-up
# or Swarm:
make s3-mirror-stack-up
```

Production: set `S3_MIRROR_ENV_FILE=.env` and keep secrets out of git. Compose merges `env_file` + `environment:` (`environment:` wins). Swarm relies on Make-exported root `.env` + `environment:` interpolation (`env_file` is not equivalent under `docker stack deploy`). On Dokploy, use Vault Provider references for `*_ACCESS_KEY` / `*_SECRET_KEY`.

`APP_NAME=s3-mirror` scopes Homepage label identity; Dokploy may override `APP_NAME`.

## Networks

Default: stack-local `s3-mirror-network` with `DEFAULT_NETWORK_EXTERNAL=false`.
`make s3-mirror-setup` upserts `DEFAULT_NETWORK_EXTERNAL` to **`true` only** when `DEFAULT_NETWORK_NAME=dokploy-network`; any other name → `false`, and creates the network when external is false.

```sh
# Reach services on the Dokploy overlay (e.g. rustfs:9000)
# In s3-mirror/.env:
#   DEFAULT_NETWORK_NAME=dokploy-network
#   DEFAULT_NETWORK_EXTERNAL=true
make s3-mirror-setup
```

## Volumes

Compose keys **`src`** (mounted read-only at `${S3_MIRROR_SRC_VOLUME_DIR:-/src}`) and **`dst`** (`${S3_MIRROR_DST_VOLUME_DIR:-/dst}`):

| Mode | `DRIVER` | `TYPE` | `OPTS` | `PATH` |
|------|----------|--------|--------|--------|
| Local named | `local` | empty | empty | empty |
| Bind | `local` | `none` | `bind` | host path e.g. `/appdata/homepage/config` |
| NFS | `local` | `nfs` | `addr=<host>,rw,nfsvers=4` | export e.g. `:/exports/s3-mirror` |
| Existing volume | same as when created | | | set `NAME` to it |

There is **no `external:` key**: Compose rejects `external` together with `driver` (`conflicting parameters "external" and "driver" specified`). A volume that already exists under `NAME` is reused as-is.

## Recipes

**Folder → bucket (backup of a host directory)** — e.g. Homepage config on devel-cen:

```env
S3_MIRROR_SRC_TYPE=path
S3_MIRROR_SRC_VOLUME_NAME=s3-mirror_src
S3_MIRROR_SRC_VOLUME_TYPE=none
S3_MIRROR_SRC_VOLUME_OPTS=bind
S3_MIRROR_SRC_VOLUME_PATH=/appdata/homepage/config
S3_MIRROR_DST_TYPE=s3
S3_MIRROR_DST_ENDPOINT=http://rustfs:9000
S3_MIRROR_DST_BUCKET=appdata
S3_MIRROR_DST_PREFIX=homepage/config
S3_MIRROR_EXCLUDE=logs/**
# S3_MIRROR_MODE=sync is the default
```

**Bucket → folder (restore / pull):**

```env
S3_MIRROR_SRC_TYPE=s3
S3_MIRROR_SRC_ENDPOINT=https://minio.example.com
S3_MIRROR_SRC_BUCKET=homepage-config
S3_MIRROR_DST_TYPE=path
S3_MIRROR_DST_VOLUME_TYPE=none
S3_MIRROR_DST_VOLUME_OPTS=bind
S3_MIRROR_DST_VOLUME_PATH=/appdata/homepage/config
# copy: sync would delete local files that are missing from the bucket
S3_MIRROR_MODE=copy
```

**Bucket → bucket:** `SRC_TYPE=s3` and `DST_TYPE=s3`, set both `*_ENDPOINT` / keys / `BUCKET`.

## Make targets

| Target | Role |
|--------|------|
| `s3-mirror-setup` | `.env`, network upsert |
| `s3-mirror-stack-up\|down\|recreate\|upgrade\|logs` | Swarm |
| `s3-mirror-compose-up\|down\|restart\|logs\|recreate` | Compose |
| `s3-mirror-debug`, `s3-mirror-debug-logs`, `s3-mirror-pull-images` | Ops |

## Restart policy

`S3_MIRROR_RESTART_POLICY_MAX_ATTEMPTS` defaults to `0` (unlimited). In plain `docker compose` mode (Dokploy `docker-compose`), `deploy.restart_policy` becomes the container restart policy and a value above 0 requires `S3_MIRROR_RESTART_POLICY_CONDITION=on-failure`.

## Verified behaviour (2026-11-18, devel-cen, rclone 1.68.2)

`copy` with `logs/**` excluded; `sync` propagating a deletion while the previous version stays available (bucket versioning); empty-source guard leaves the destination untouched; healthcheck exit 0 after a pass, 1 without one.
