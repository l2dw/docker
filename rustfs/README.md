# rustfs

[RustFS](https://rustfs.com) — S3-compatible object storage (`docker.io/rustfs/rustfs`) on **9000** (API) and **9001** (Console). Joins `dokploy-network`. Traefik/Homepage labels live only in `docker-compose.yml`.

Ports **9000/9001 are not published on the host**. One DNS name is enough (default `s3.example.com`): S3 API at the host root, Console at `/rustfs/console`.

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${RUSTFS_ENV_FILE:-.env.example}`; production: `RUSTFS_ENV_FILE=.env`. `environment:` wins on key conflicts.

```sh
make rustfs-setup \
  RUSTFS_S3_DOMAIN=s3.example.com \
  RUSTFS_CONSOLE_DOMAIN=s3.example.com \
  RUSTFS_CONSOLE_URL=http://s3.example.com/rustfs/console
make rustfs-stack-up
# or
make rustfs-compose-up
```

On the `rustfs` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `rustfs/`.

## Base path / Console URL

**S3 API:** AWS Signature V4 includes the request path — do **not** put the API under a prefix or `stripPrefix`. Default `RUSTFS_BASE_PATH=/` is unused. Traefik: `Host(RUSTFS_S3_DOMAIN)` → port **9000**.

**Console:** the UI path is **hard-coded** as `/rustfs/console` (health: `/rustfs/console/health`). `/console` is **not** a RustFS route and cannot be configured. Traefik: same host + `PathPrefix(/rustfs/console)` (also `/rustfs/admin` and `/browser`, which the SPA calls) → port **9001**. **No `stripPrefix`.**

Open **`http://s3.example.com/rustfs/console`**. S3 clients: endpoint `http://s3.example.com`, **path-style** (`forcePathStyle: true`). Avoid a bucket named `rustfs` if objects would collide with `/rustfs/console`. A dedicated Console hostname remains the [official Traefik layout](https://docs.rustfs.com/en/developer/integration/reverse-proxy/traefik) if login/API calls to `/` mis-route to S3.

## Credentials and volumes

`make rustfs-setup` generates `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` if empty. Do not use the well-known `rustfsadmin` pair in production.

Named volumes: `/data` (objects) and `/var/log/rustfs` (logs). Container runs as user `rustfs` (UID 10001) — bind mounts must be writable by that user.

## Multiple disks (SNMD)

The committed stack is **single-node, single-disk (SNSD)**: `command: [/data]` plus one volume. Extra capacity on **one** RustFS process uses [Single Node Multiple Disk (SNMD)](https://docs.rustfs.com/en/installation/linux/single-node-multiple-disk): several paths in one erasure set.

Do **not** treat extra mounts as separate S3 buckets. RustFS sees them as **one pool**.

| Goal | How |
|------|-----|
| More disks, one server | SNMD: extra mounts + replace `command` (and/or `RUSTFS_VOLUMES`) |
| HA / several servers | [MNMD](https://docs.rustfs.com/en/installation/linux/multiple-node-multiple-disk): several RustFS nodes, `RUSTFS_VOLUMES` with HTTP URLs — not `replicas: N` sharing one volume |
| One NFS share | Keep SNSD: one NFS (or bind) → `/data` |

**Syntax:** official env uses **three dots** in braces: `RUSTFS_VOLUMES=/data/rustfs{0...3}` (not `{0..3}`). The image/systemd start is `rustfs $RUSTFS_VOLUMES`. This stack’s `command: [/data]` **wins** over the image CMD — an override **must replace `command`** with the disk paths (or the process stays SNSD and ignores extra mounts).

**Independence:** recent RustFS builds check that each path is a **different physical device** (`st_dev`). Bind-mount **each disk (or NFS export) separately** into the container (`/data/rustfs0`, `/data/rustfs1`, …). Do not bind one parent directory and expect nested host mounts to show up as distinct devices.

**UID:** all data paths must be writable by **10001:10001**. NFS: `anonuid=10001,anongid=10001` (or matching ownership on the export).

**NFS:** lab/small SNMD can use several NFS exports. Latency and NFS semantics are weaker than local XFS/ext4; if the independence check fails (same NFS server/`st_dev`), use local disks or MNMD with disks **per node**. Pin Swarm tasks to a node that can reach the exports (`deploy.placement.constraints`).

Do **not** commit override files (gitignored: `**/*.override.*`).

### Override files (Compose vs Swarm)

Make merges an override when the file exists. Resolution (`bin/resolve-project-compose.sh`):

1. `rustfs/stack-compose.override.yml` if present
2. else `rustfs/docker-compose.override.yml`

| Target | Make | Extra `-f` / `-c` |
|--------|------|-------------------|
| Compose | `make rustfs-compose-up` | `-f rustfs/docker-compose.yml` then `-f` the override |
| Swarm | `make rustfs-stack-up` | `docker stack deploy -c … -c` the override |

One `docker-compose.override.yml` is picked up by **both** Compose and Swarm. Use `stack-compose.override.yml` when Swarm should differ, or set `DOCKER_COMPOSE_OVERRIDE` / `STACK_OVERRIDE` on the Make command.

Compose **appends** `volumes:` lists — the base `rustfs-data:/data` mount stays. Leave it unused, or (Compose v2.24+) reset with `volumes: !override` then list every mount. `command:` from the override **replaces** the base `command`.

Swarm interpolates from the **root** `.env` exported by Make (not Compose `env_file`). Keep NFS `driver_opts` (`addr=…`) in the override file.

### Compose / Swarm override example (4 NFS disks)

`rustfs/docker-compose.override.yml` (or `stack-compose.override.yml`):

```yaml
volumes:
  rustfs0:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs.example.com,rw,nfsvers=4
      device: ":/exports/rustfs0"
  rustfs1:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs.example.com,rw,nfsvers=4
      device: ":/exports/rustfs1"
  rustfs2:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs.example.com,rw,nfsvers=4
      device: ":/exports/rustfs2"
  rustfs3:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs.example.com,rw,nfsvers=4
      device: ":/exports/rustfs3"

services:
  rustfs:
    command:
      - /data/rustfs0
      - /data/rustfs1
      - /data/rustfs2
      - /data/rustfs3
    environment:
      - RUSTFS_VOLUMES=/data/rustfs{0...3}
    volumes:
      - rustfs0:/data/rustfs0
      - rustfs1:/data/rustfs1
      - rustfs2:/data/rustfs2
      - rustfs3:/data/rustfs3
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.platform.os==linux
          # - node.hostname==storage-1
```

Host NFS already mounted: use binds instead of `driver_opts`, e.g. `/mnt/nfs/export0:/data/rustfs0`. Then `make rustfs-compose-up` or `make rustfs-stack-up`.

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
| `RUSTFS_CONSOLE_PATH` | Console PathPrefix (default `/rustfs/console`, not `/console`) |
| `RUSTFS_S3_URL` / `RUSTFS_CONSOLE_URL` | Public URLs (Homepage href = console URL) |
| `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` | Generated by setup if empty |
| `RUSTFS_ENV_FILE` | Compose dotenv (default `.env.example`) |

Do not commit `rustfs/.env` or real secrets.
