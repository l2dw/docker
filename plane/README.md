# Plane (Community Edition)

Self-hosted [Plane](https://plane.so) — **app services only**. Postgres, Redis, RabbitMQ and object storage are **external** (set `PLANE_DATABASE_URL`, `PLANE_REDIS_URL`, `PLANE_AMQP_URL`, `PLANE_S3_*`). Based on [Community compose](https://github.com/makeplane/plane/tree/preview/deployments/cli/community) + [reverse-proxy path map](https://developers.plane.so/self-hosting/govern/reverse-proxy) (no bundled Caddy).

## Quick start

```sh
make plane-setup
# Edit plane/.env — domain + external DB/Redis/AMQP/S3 URLs
make plane-stack-up      # Swarm
# or
make plane-compose-up    # Compose
```

Debug: `make plane-debug` / `make plane-debug-logs`.

`docker stack deploy` does **not** load Compose `env_file` reliably — use Make (exports root `.env`) + `environment:` interpolation.

## External dependencies

This stack does **not** ship Postgres, Redis, RabbitMQ, or object storage. Provision them elsewhere, put Plane on the **same Docker network** (typically `DEFAULT_NETWORK_NAME=dokploy-network` + `DEFAULT_NETWORK_EXTERNAL=true`), then set the URLs below **before** the first `make plane-stack-up` (the `migrator` service expects a ready database).

| Service | Role | Default DNS (placeholder) | Required env |
|---------|------|---------------------------|--------------|
| **Postgres** | App DB | `postgres:5432` | `PLANE_DATABASE_URL` (+ optional `PLANE_PG*` / `PLANE_POSTGRES_*`) |
| **Redis / Valkey** | Cache / broker bits | `redis:6379` | `PLANE_REDIS_URL` (+ `PLANE_REDIS_HOST` / `_PORT`) |
| **RabbitMQ** | Async jobs (AMQP) | `rabbitmq:5672` | `PLANE_AMQP_URL` (+ `PLANE_RABBITMQ_*`) |
| **S3 / MinIO** | Uploads / attachments | `minio:9000` | `PLANE_S3_ENDPOINT_URL`, `PLANE_S3_BUCKET_NAME`, `PLANE_AWS_ACCESS_KEY_ID`, `PLANE_AWS_SECRET_ACCESS_KEY`, `PLANE_USE_MINIO` |

Replace placeholder hostnames with your real service DNS names on the shared overlay.

### Postgres

```env
PLANE_PGHOST=postgres
PLANE_PGDATABASE=plane
PLANE_POSTGRES_USER=plane
PLANE_POSTGRES_PASSWORD=ChangeMe
PLANE_POSTGRES_DB=plane
PLANE_POSTGRES_PORT=5432
PLANE_DATABASE_URL=postgresql://plane:ChangeMe@postgres:5432/plane
```

Create role + database `plane` on the external Postgres before deploy. `PLANE_DATABASE_URL` is the source of truth for the backend.

### Redis / Valkey

```env
PLANE_REDIS_HOST=redis
PLANE_REDIS_PORT=6379
PLANE_REDIS_URL=redis://redis:6379/
```

Use a Redis-compatible instance (Valkey works). Auth URL form if needed: `redis://:password@redis:6379/0`.

### RabbitMQ

```env
PLANE_RABBITMQ_HOST=rabbitmq
PLANE_RABBITMQ_PORT=5672
PLANE_RABBITMQ_USER=plane
PLANE_RABBITMQ_PASSWORD=ChangeMe
PLANE_RABBITMQ_VHOST=plane
PLANE_AMQP_URL=amqp://plane:ChangeMe@rabbitmq:5672/plane
```

Create the vhost/user (or point `PLANE_AMQP_URL` at an existing AMQP endpoint).

### S3 / MinIO

```env
PLANE_USE_MINIO=1
PLANE_MINIO_ENDPOINT_SSL=0
PLANE_AWS_REGION=
PLANE_AWS_ACCESS_KEY_ID=access-key
PLANE_AWS_SECRET_ACCESS_KEY=ChangeMe
PLANE_S3_ENDPOINT_URL=http://minio:9000
PLANE_S3_BUCKET_NAME=uploads
```

| Mode | `PLANE_USE_MINIO` | Notes |
|------|-------------------|--------|
| MinIO / path-style compatible | `1` | Endpoint is your MinIO API URL; create bucket `uploads` (or match `PLANE_S3_BUCKET_NAME`) |
| AWS S3 | `0` | Set region + real S3 endpoint; keys must allow object R/W on the bucket |

Plane talks to S3/MinIO **directly** via these vars — there is no `/uploads` Traefik route in this stack.


## Base path

**Subpath is not supported.** Keep `PLANE_BASE_PATH=/` and a dedicated subdomain (`PLANE_DOMAIN`).

## Traefik / Homepage

Labels only in `docker-compose.yml` (and HTTP role files). `compose.yml` is unlabeled. `APP_NAME` scopes Traefik names. Homepage on `web` only. **No** `/uploads` Traefik route — clients talk to external S3/MinIO via `PLANE_S3_ENDPOINT_URL`.

| Path | Service | Port |
|------|---------|------|
| `/*` | `web` | 3000 |
| `/spaces` | `space` | 3000 |
| `/god-mode` | `admin` | 3000 |
| `/live` | `live` | 3000 |
| `/api`, `/auth`, `/static` | `api` | 8000 |

## env_file

Each service: `PLANE_<ROLE>_ENV_FILE` (default `.env.example`). Prod → `.env`. `environment:` overrides. Swarm: Make-exported root `.env`.

## Per-service compose

`web-compose.yml`, `space-compose.yml`, `admin-compose.yml`, `live-compose.yml`, `api-compose.yml`, `worker-compose.yml`, `beat-worker-compose.yml`, `migrator-compose.yml`.

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `EXTERNAL` |
|------|------------------------|------------|
| Stack-local | `plane-network` | `false` |
| Shared Traefik / DB / Redis | `dokploy-network` | `true` |

`make plane-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

## Volumes

None — no persistent log or data volumes in this stack (DB/Redis/MQ/S3 are external).


## Required env

- `PLANE_DOMAIN`, `PLANE_APP_URL`, `PLANE_CORS_ALLOWED_ORIGINS`
- `PLANE_DATABASE_URL`, `PLANE_REDIS_URL`, `PLANE_AMQP_URL`, `PLANE_S3_ENDPOINT_URL`
- Secrets (`plane-setup` if still `ChangeMe`): `PLANE_SECRET_KEY`, `PLANE_LIVE_SERVER_SECRET_KEY`, `PLANE_AWS_SECRET_ACCESS_KEY`
