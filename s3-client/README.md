# S3-client

Long-running [MinIO Client (`mc`)](https://min.io/docs/minio/linux/reference/minio-mc.html) container for S3-compatible storage administration. The service stays idle (`sleep infinity`) so you can `exec` into it and run `mc` against RustFS, MinIO, AWS S3, or any S3 API endpoint on the shared Docker network.

Persistent state:

- `/data` — working directory for uploads, downloads, and scripts
- `/root/.mc` — `mc` aliases, config, and credentials

## Variables

Copy `s3-client/.env.example` into the repo root `.env` (or export the keys there). `make stack-deploy` loads the root `.env` automatically.

### Paths and layout

| Variable | Default | Description |
|----------|---------|-------------|
| `APPDATA_DIR` | _(root `.env`)_ | Base app data path; use in `S3_CLIENT_*_DIR` values |
| `S3_CLIENT_DATA_DIR` | `s3_client_data` | Host path or named volume mounted at `/data` |
| `S3_CLIENT_CONFIG_DIR` | `s3_client_config` | Host path or named volume mounted at `/root/.mc` |
| `S3_CLIENT_LOGS_DIR` | — | Reserved for future use; not mounted by the current compose file |

### Network

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_CLIENT_NETWORK` | `dokploy-network` | External overlay/bridge network the container joins |
| `S3_CLIENT_NETWORK_EXTERNAL` | `true` | Set `false` if Compose should create the network |

The stack must reach your S3 server by **Docker DNS name** on this network (e.g. `rustfs`, `minio`), not only by public hostname.

### Volumes (named volume overrides)

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_CLIENT_DATA_VOLUME_NAME` | `s3_client_data` | Named volume for `/data` when `S3_CLIENT_DATA_DIR` is unset |
| `S3_CLIENT_DATA_VOLUME_EXTERNAL` | `false` | Use an existing Docker volume |
| `S3_CLIENT_CONFIG_VOLUME_NAME` | `s3_client_config` | Named volume for `/root/.mc` when `S3_CLIENT_CONFIG_DIR` is unset |
| `S3_CLIENT_CONFIG_VOLUME_EXTERNAL` | `false` | Use an existing Docker volume |

### Container runtime

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_CLIENT_IMAGE` | `docker.io/minio/mc:latest` | Image (MinIO Client) |
| `S3_CLIENT_PULL_POLICY` | `always` | Compose pull policy |
| `S3_CLIENT_RESTART` | `unless-stopped` | Restart policy (Compose); Swarm uses deploy restart policy |
| `S3_CLIENT_PRIVILEGED` | `true` | Privileged mode |
| `S3_CLIENT_PLACEMENT_CONSTRAINTS` | `manager` | Swarm placement (`node.role==…`) |

### Proxy and timezone

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/Toronto` | Container timezone |
| `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` | empty | Passed into the container for outbound `mc` calls |

#### Corporate proxy

Set in the repo root `.env` (example):

```env
HTTP_PROXY=http://mandataire.example.com:80
HTTPS_PROXY=http://mandataire.example.com:80
NO_PROXY=localhost,127.0.0.1,.example.com,rustfs,minio,s3-client,10.0.0.0/8
```

- **HTTPS to the proxy** — use an `http://` or `https://` proxy URL; `mc` uses these env vars for outbound connections.
- **`NO_PROXY`** — list every **internal** S3 host that must **not** go through the proxy: Docker service names (`rustfs`, `minio`), overlay CIDRs, and local domains. Without this, `mc` may try to reach `http://rustfs:9000` via the corporate proxy and fail.
- After changing proxy vars, recreate the stack: `make s3-client-compose-recreate` or `make s3-client-stack-recreate`.

**Test proxy configuration** (inside the container):

```sh
docker exec -it s3-client-s3-client-1 sh

# 1. Env vars are present
env | grep -i proxy

# 2. Internal endpoint (should bypass proxy via NO_PROXY)
mc alias set internal http://rustfs:9000 ACCESS_KEY SECRET_KEY
mc --debug ls internal

# 3. External HTTPS endpoint (should use HTTPS_PROXY)
mc alias set external https://s3.example.com ACCESS_KEY SECRET_KEY
mc --debug ls external
```

Use `mc --debug` to confirm whether traffic goes direct or via `CONNECT` to the proxy.

#### Self-signed or private HTTPS (`--insecure`)

Use only in lab/dev—not production.

**Per alias** (recommended):

```sh
mc alias set minio https://minio:9000 ACCESS_KEY SECRET_KEY --insecure
mc ls minio
```

**Persist for all aliases on this client** — edit `/root/.mc/config.json` (host path: `S3_CLIENT_CONFIG_DIR`) and set `"insecure": true` on each alias:

```json
{
  "aliases": {
    "minio": {
      "url": "https://minio:9000",
      "accessKey": "ACCESS_KEY",
      "secretKey": "SECRET_KEY",
      "api": "S3v4",
      "path": "auto",
      "insecure": true
    }
  }
}
```

Or re-run `mc alias set … --insecure` for each alias; `mc` merges into the same file.

**Verify TLS / connectivity:**

```sh
mc alias list
mc ready minio              # MinIO only
mc --debug stat minio/my-bucket/test.txt
```

If you still see `x509: certificate signed by unknown authority`, the alias was created without `--insecure` or `"insecure": true` in config—remove and recreate the alias.

### Homepage labels (optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_CLIENT_HOMEPAGE_GROUP` | `Infra` | Homepage dashboard group |
| `S3_CLIENT_HOMEPAGE_NAME` | `s3-client` | Display name |
| `S3_CLIENT_HOMEPAGE_ICON` | `s3-client.png` | Icon filename |
| `S3_CLIENT_HOMEPAGE_DESCRIPTION` | S3 Client… | Short description |

### S3 endpoint hints (commented in compose)

These are **not wired** in `docker-compose.yml` today; configure aliases manually with `mc alias set` after `exec`:

| Variable | Purpose |
|----------|---------|
| `S3_SERVER_HOST` | S3 API host (e.g. `rustfs:9000`) |
| `S3_SERVER_ACCESS_KEY` | Access key |
| `S3_SERVER_SECRET_KEY` | Secret key |

Example after deploy:

```sh
docker exec -it s3-client_s3-client.1.<task-id> sh
mc alias set local S3_SERVER_HOST ACCESS_KEY SECRET_KEY
mc ls local
mc cp /data/myfile.txt local/my-bucket/
```

Aliases and keys persist under `S3_CLIENT_CONFIG_DIR` (`/root/.mc` in the container).

## Makefile

Run from `devops/docker-templates` (parent of `s3-client/`). Merge `s3-client/.env.example` into the repo root `.env` before deploy.

### Docker Swarm (production / multi-node)

Requires Swarm (`make swarm-init` on first setup) and an existing `dokploy-network` (or your `S3_CLIENT_NETWORK`).

| Target | Description |
|--------|-------------|
| `make s3-client-stack-up` | Deploy stack (`stack-deploy STACK_NAME=s3-client`) |
| `make s3-client-stack-down` | Remove stack |
| `make s3-client-stack-recreate` | Down then up |
| `make s3-client-stack-logs` | Tail service logs |
| `make s3-client-stack-watch` | Follow merged logs |
| `make s3-client-stack-debug` | Services, tasks, and per-service log tails |

```sh
make s3-client-stack-up
docker exec -it $(docker ps -q --filter name=s3-client_s3-client | head -1) sh
```

### Docker Compose (local / single-node)

No Swarm required. Container name pattern: `s3-client-s3-client-1`.

| Target | Description |
|--------|-------------|
| `make s3-client-compose-up` | `docker compose up -d` |
| `make s3-client-compose-down` | `docker compose down` |
| `make s3-client-compose-restart` | Restart services |
| `make s3-client-compose-recreate` | Down then up |
| `make s3-client-compose-logs` | Show logs |
| `make s3-client-compose-watch-logs` | Follow logs |

```sh
make s3-client-compose-up
docker exec -it s3-client-s3-client-1 sh
```

Do not run Swarm and Compose deployments at the same time on the same host unless paths and network names are intentionally separated.

### Low-level equivalents

```sh
make stack-deploy STACK_NAME=s3-client
make stack-rm STACK_NAME=s3-client
make docker-project-up PROJECT_NAME=s3-client
make docker-project-down PROJECT_NAME=s3-client
```

## mc cli

Official reference: [MinIO Client (`mc`)](https://min.io/docs/minio/linux/reference/minio-mc.html).

### Shell

```sh
# Compose
docker exec -it s3-client-s3-client-1 sh

# Swarm
docker exec -it $(docker ps -q --filter name=s3-client_s3-client | head -1) sh
```

Inside the container, `mc` is on `PATH`. Config lives in `/root/.mc` (persisted via `S3_CLIENT_CONFIG_DIR`).

### Aliases

An **alias** is a named S3 endpoint (`local`, `minio`, `rustfs`, …). Use the **internal Docker service name and port** when the S3 server is on the same network:

```sh
# MinIO on dokploy-network (API port 9000)
mc alias set minio http://minio:9000 ACCESS_KEY SECRET_KEY

# RustFS / other S3-compatible service
mc alias set rustfs http://rustfs:9000 ACCESS_KEY SECRET_KEY

# Verify
mc alias list
mc admin info minio    # MinIO only; omit for generic S3
```

For servers reached only via Traefik or public DNS, use that URL instead (often HTTPS):

```sh
mc alias set prod https://s3.example.com ACCESS_KEY SECRET_KEY
```

Add `--api S3v4` if the server requires SigV4 explicitly. Add `--insecure` only for self-signed TLS in lab environments.

Aliases are stored under `/root/.mc` and survive container restarts.

### Buckets and objects

```sh
mc ls minio                          # list buckets
mc ls minio/my-bucket                # list objects
mc ls --recursive minio/my-bucket      # recursive

mc mb minio/new-bucket               # create bucket
mc rb minio/old-bucket               # remove empty bucket
mc rb --force --dangerous minio/old-bucket   # remove bucket and contents

mc cp /data/file.txt minio/my-bucket/
mc cp minio/my-bucket/file.txt /data/
mc cp --recursive /data/backups/ minio/my-bucket/backups/

mc rm minio/my-bucket/file.txt
mc rm --recursive --force minio/my-bucket/prefix/

mc stat minio/my-bucket/file.txt
mc du minio/my-bucket                # usage summary
```

Use `/data` as the default working directory for uploads and downloads (mounted from `S3_CLIENT_DATA_DIR`).

### Sync and mirror

```sh
# Upload local tree to bucket (create missing keys, remove extras with --remove)
mc mirror /data/site/ minio/my-bucket/site/

# Download bucket to local
mc mirror minio/my-bucket/site/ /data/site/

# Dry run
mc mirror --dry-run /data/site/ minio/my-bucket/site/
```

### Policies and sharing (optional)

```sh
mc anonymous get minio/my-bucket
mc anonymous set download minio/my-bucket/public/   # public read on prefix
mc share download minio/my-bucket/file.txt --expire 1h
```

### MinIO admin (MinIO servers only)

```sh
mc admin info minio
mc admin user list minio
mc admin user add minio newuser newpassword
mc admin policy attach minio readwrite --user newuser
```

These subcommands require MinIO—not generic AWS S3.

### Troubleshooting

| Symptom | Check |
|---------|--------|
| `Connection refused` | S3 service name/port; same Docker network as `s3-client` |
| `Access Denied` | Access key / secret; bucket policy; path-style vs host-style |
| `SSL certificate problem` | Use correct HTTPS URL or `--insecure` (lab only) |
| Alias missing after recreate | `S3_CLIENT_CONFIG_DIR` must be a host bind mount or named volume, not ephemeral storage |
| Proxy errors | `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` in root `.env` |

```sh
mc --debug ls minio/my-bucket    # verbose request trace
mc alias list
mc ready minio                   # health check (MinIO)
```
