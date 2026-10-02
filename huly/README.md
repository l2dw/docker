# Huly

Self-hosted [Huly](https://huly.io) (all-in-one PM / chat / CRM), based on [huly-selfhost](https://github.com/hcengineering/huly-selfhost) **v0.7.x**.

Platform source: [hcengineering/platform](https://github.com/hcengineering/platform#self-hosting). Prefer production tags (`v*`, e.g. `v0.7.426`).

This stack deploys **Huly application services only**. CockroachDB, Kafka/Redpanda, object storage, and Elasticsearch run **outside** the stack (separate compose stacks or managed services on the same overlay).

**Requirements:** ~8 GB RAM minimum (16 GB recommended) for the app tier; plan additional resources for external data stores.

## Quick start

```sh
make huly-setup
# Edit huly/.env: external URLs + HULY_DOMAIN / schemes / TLS
make huly-stack-up          # Swarm
# or: make huly-compose-up  # Compose
```

`docker stack deploy` does **not** load Compose `env_file` the same way — use Make (exports root `.env` + `environment:` interpolation).

## Services (this stack)

| Compose service | Role | Public path (Traefik) |
|-----------------|------|------------------------|
| `front` | Web UI | `Host(domain)` |
| `account` | Accounts API | `/_accounts` (strip) |
| `transactor` | WS / sync | `/_transactor` (strip), `/eyJ…` |
| `collaborator` | Collaboration WS | `/_collaborator` (strip) |
| `stats` | Stats | `/_stats` (strip) |
| `rekoni` | Recognition | `/_rekoni` (strip) |
| `workspace` / `fulltext` / `kvs` | Workers | internal |

Per-service files: `front-compose.yml`, `account-compose.yml`, … (same definitions + labels where applicable).

Nginx from upstream is **not** included — Traefik path routers replace `.huly.nginx`.

## External dependencies

Provision these **before** first deploy. Hostnames must resolve from the Huly stack network (e.g. join `dokploy-network` or use stack DNS aliases).

| Dependency | Env var(s) | Notes |
|------------|------------|--------|
| **CockroachDB** (Postgres wire) | `HULY_CR_DB_URL` | e.g. `postgres://huly:pass@postgresql:26257/huly` |
| **Kafka / Redpanda** | `HULY_QUEUE_CONFIG` | `host:9092` (no URI scheme) |
| **S3 / MinIO** | `HULY_STORAGE_CONFIG` | `minio\|host:9000?accessKey=…&secretKey=…` |
| **Elasticsearch 7.x** | `HULY_ELASTIC_URL`, `HULY_FULLTEXT_DB_URL` | Ingest-attachment plugin for fulltext |

Example `.env` fragment:

```env
HULY_CR_DB_URL=postgres://huly:ChangeMe@postgresql:26257/huly
HULY_QUEUE_CONFIG=kafka:9092
HULY_STORAGE_CONFIG=minio|minio:9000?accessKey=ChangeMe&secretKey=ChangeMe
HULY_ELASTIC_URL=http://elasticsearch:9200
HULY_FULLTEXT_DB_URL=http://elasticsearch:9200
```

## Base path

**Subpath is not supported.** Keep `HULY_BASE_PATH=/` and a dedicated subdomain (`HULY_DOMAIN`). Upstream paths (`/_accounts`, `/_transactor`, …) are absolute.

## Env / secrets

| Key | Notes |
|-----|--------|
| `HULY_SECRET` | Shared app secret (`make huly-setup` generates if `ChangeMe`) |
| `HULY_CR_DB_URL` | External Cockroach/Postgres URL |
| `HULY_QUEUE_CONFIG` | External Kafka broker |
| `HULY_STORAGE_CONFIG` | External object storage |
| `HULY_ELASTIC_URL` / `HULY_FULLTEXT_DB_URL` | External Elasticsearch |
| `HULY_HTTP_SCHEME` / `HULY_WS_SCHEME` | `https` / `wss` (or `http` / `ws`) |
| `HULY_INIT_REPO_DIR` | Set `/no-init-scripts` to skip default workspace content |

Each service has `env_file` (`HULY_<ROLE>_ENV_FILE`, default `.env.example`) **and** `environment:` (wins on conflict). Production: set `*_ENV_FILE=.env`.

`APP_NAME` scopes Traefik router/service names (Dokploy may override).

## Traefik / Homepage

Labels only in `docker-compose.yml` (and matching role files). `compose.yml` is unlabeled. Homepage on `front` only.

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `DEFAULT_NETWORK_EXTERNAL` |
|------|------------------------|----------------------------|
| Stack-local (default) | `huly-network` | `false` |
| Dokploy / shared Traefik + deps | `dokploy-network` | `true` |

`make huly-setup` upserts `EXTERNAL` (`true` only for `dokploy-network`) and creates the stack-local network when needed.

```sh
docker network create huly-network --driver overlay   # Swarm
```

## Volumes

This stack has **no persistent volumes** — state lives in external Cockroach, Kafka, S3, and Elasticsearch.

## Make targets

| Target | Role |
|--------|------|
| `huly-setup` | `.env`, secrets, network pairing |
| `huly-stack-up\|down\|recreate\|upgrade\|logs` | Swarm |
| `huly-compose-up\|down\|restart\|logs` | Compose |
| `huly-debug` / `huly-debug-logs` | Ops |
| `huly-pull-images` | Pull |

## Updates

Follow upstream [MIGRATION.md](https://github.com/hcengineering/huly-selfhost/blob/main/MIGRATION.md) before bumping `HULY_VERSION` / image tags. Then `make huly-stack-upgrade`.
