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

`PLANE_DATABASE_URL` is the source of truth for the backend. Create the role + database on the **external** Postgres **before** the first deploy (migrator needs them).

Connect as a superuser (examples: `psql` on the host, or `docker exec` into the Postgres task):

```sh
# From a shell that can reach Postgres (adjust container / host)
psql -U postgres -h postgres -d postgres <<'SQL'
CREATE USER plane WITH PASSWORD 'ChangeMe';
CREATE DATABASE plane OWNER plane;
GRANT ALL PRIVILEGES ON DATABASE plane TO plane;
-- Postgres 15+: also grant schema usage on the new DB
\c plane
GRANT ALL ON SCHEMA public TO plane;
ALTER SCHEMA public OWNER TO plane;
SQL
```

Swarm / Dokploy (find the Postgres task, then exec):

```sh
CID=$(docker ps -q -f name=postgresql | head -1)
docker exec -i "$CID" psql -U postgres -d postgres <<'SQL'
CREATE USER plane WITH PASSWORD 'ChangeMe';
CREATE DATABASE plane OWNER plane;
GRANT ALL PRIVILEGES ON DATABASE plane TO plane;
SQL
docker exec -i "$CID" psql -U postgres -d plane <<'SQL'
GRANT ALL ON SCHEMA public TO plane;
ALTER SCHEMA public OWNER TO plane;
SQL
```

If the role already exists: `ALTER USER plane WITH PASSWORD '…';`. Align `PLANE_DATABASE_URL` with the same user / password / host / db name. Host must resolve on the shared overlay (`postgres`, `postgresql.otspace.ca`, etc.).

### Redis / Valkey

```env
PLANE_REDIS_HOST=redis
PLANE_REDIS_PORT=6379
PLANE_REDIS_URL=redis://redis:6379/
```

Use a Redis-compatible instance (Valkey works). Auth URL form if needed: `redis://:password@redis:6379/0` (or a DB index, e.g. `/3`). No special “create database” step beyond picking a free logical DB index if you share the instance.

### RabbitMQ

```env
PLANE_RABBITMQ_HOST=rabbitmq
PLANE_RABBITMQ_PORT=5672
PLANE_RABBITMQ_USER=plane
PLANE_RABBITMQ_PASSWORD=ChangeMe
PLANE_RABBITMQ_VHOST=plane
PLANE_AMQP_URL=amqp://plane:ChangeMe@rabbitmq:5672/plane
```

Celery needs a reachable broker. **Mismatch** (wrong user / password / vhost) shows up as API crash-loop:

`ACCESS_REFUSED - Login was refused using authentication mechanism PLAIN`

Either point `PLANE_AMQP_URL` at an existing user/vhost, **or** create a dedicated vhost + user on the external broker (same network alias, e.g. `rabbitmq`).

```sh
# Container of the RabbitMQ stack (service name may be broker / rabbitmq)
CID=$(docker ps -q -f name=rabbitmq | head -1)
# Prefer a precise filter if several match, e.g. -f name=rabbitmq-xxx_broker

docker exec "$CID" rabbitmqctl add_vhost plane
docker exec "$CID" rabbitmqctl add_user plane 'ChangeMe'
# If user already exists: rabbitmqctl set_password plane 'ChangeMe'
docker exec "$CID" rabbitmqctl set_permissions -p plane plane '.*' '.*' '.*'

docker exec "$CID" rabbitmqctl list_vhosts name
docker exec "$CID" rabbitmqctl list_permissions -p plane
```

Management UI (if enabled): Admin → Virtual Hosts / Users — same effect.

URL form:

| Piece | Example | Notes |
|-------|---------|--------|
| User / pass | `plane` / `ChangeMe` | Must match `add_user` / `set_password` |
| Host | `rabbitmq` | Overlay DNS / network alias of the broker |
| Vhost | `plane` | Path after host — `…:5672/plane` (not `/` unless you use the default vhost) |

Default broker vhost `/` would be:

`amqp://rabbit:…@rabbitmq:5672/` (trailing slash = vhost `/`).

After fixing AMQP, redeploy or force-update `api`, `worker`, and `beat-worker`.

### S3 / MinIO

```env
PLANE_USE_MINIO=0
PLANE_MINIO_ENDPOINT_SSL=0
PLANE_AWS_REGION=
PLANE_AWS_ACCESS_KEY_ID=access-key
PLANE_AWS_SECRET_ACCESS_KEY=ChangeMe
PLANE_S3_ENDPOINT_URL=https://s3.example.com
PLANE_S3_BUCKET_NAME=plane
```

| Mode | `PLANE_USE_MINIO` | Notes |
|------|-------------------|--------|
| Same-host MinIO (proxied) | `1` | Plane rewrites upload URLs to the **request host** (`https://<PLANE_DOMAIN>/<bucket>`). Needs a reverse-proxy path to MinIO on that host. |
| External S3 / rustfs / MinIO URL | `0` | Use when `PLANE_S3_ENDPOINT_URL` is a **different host** (e.g. `https://s3.example.com`). Browser uploads go there; configure **bucket CORS** for `https://<PLANE_DOMAIN>`. |

Plane talks to S3/MinIO **directly** via these vars — there is no `/uploads` Traefik route in this stack. For external object storage always set `PLANE_USE_MINIO=0`.


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
