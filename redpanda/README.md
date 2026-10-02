# Redpanda

[Redpanda](https://www.redpanda.com/) — Kafka-compatible streaming broker (`dev-container` single node) plus [Console](https://docs.redpanda.com/current/console/) UI via Traefik.

Useful as the external queue for stacks like Huly (`HULY_QUEUE_CONFIG=redpanda:9092`). Docker single-broker is intended for lab / shared overlay use — not multi-AZ production HA.

## Quick start

```sh
make redpanda-setup
# Edit redpanda/.env — REDPANDA_DOMAIN / REDPANDA_APP_URL / admin password
make redpanda-stack-up      # Swarm
# or
make redpanda-compose-up    # Compose
```

Debug: `make redpanda-debug` / `make redpanda-debug-logs`.

`docker stack deploy` does **not** load Compose `env_file` reliably — use Make (exports root `.env`) + `environment:` interpolation.

## Services

| Compose service | Role | File |
|-----------------|------|------|
| `redpanda` | Kafka API `:9092`, schema `:8081`, pandaproxy `:8082`, admin `:9644` | `redpanda-compose.yml` |
| `console` | Web UI `:8080` | `console-compose.yml` |

## Base path

Console subpath is **not** supported. Keep `REDPANDA_BASE_PATH=/` and a dedicated subdomain (`REDPANDA_DOMAIN`).

## Traefik / Homepage

Labels only in `docker-compose.yml` (on `console`). `compose.yml` is unlabeled. `APP_NAME` scopes Traefik names.

| Listener | How |
|----------|-----|
| Console `:8080` | Traefik HTTP + Homepage on `docker-compose.yml` — **no** host `ports:` |
| Kafka `:9092` | Long-form `ports:` **only** in `compose.yml` (`REDPANDA_KAFKA_*`) |
| Overlay DNS | Service key `redpanda`; `compose.yml` also sets alias `${REDPANDA_ALIAS}` (default `redpanda`) |

## Credentials / client URL

```env
REDPANDA_ADMIN_USER=superadmin
REDPANDA_ADMIN_PASSWORD=ChangeMe
```

Example for Huly / Kafka clients on the same overlay: `redpanda:9092` (`HULY_QUEUE_CONFIG=redpanda:9092`).

`make redpanda-setup` generates `REDPANDA_ADMIN_PASSWORD` when still `ChangeMe`.

## env_file

`REDPANDA_ENV_FILE` / `REDPANDA_CONSOLE_ENV_FILE` (default `.env.example`). Production → `.env`. `environment:` overrides. Swarm: Make-exported root `.env`.

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `EXTERNAL` |
|------|------------------------|------------|
| Stack-local (default) | `redpanda-network` | `false` |
| Shared Traefik / apps (e.g. Huly) | `dokploy-network` | `true` |

`make redpanda-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

```sh
docker network create redpanda-network --driver overlay   # Swarm
docker network create redpanda-network --driver bridge    # Compose
```

## Volumes

Compose key **`data`** → `${REDPANDA_DATA_VOLUME_DIR:-/var/lib/redpanda/data}`:

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|------------|--------|--------|--------|
| Local named (default) | `false` | empty | empty | empty |
| Bind | `false` | `none` | `bind` | `/appdata/redpanda` |
| NFS | `false` | `nfs` | `addr=host,rw,nfsvers=4` | `:/exports/redpanda` |
| External | `true` | — | — | — |

```env
# Local named
REDPANDA_DATA_VOLUME_TYPE=
REDPANDA_DATA_VOLUME_OPTS=
REDPANDA_DATA_VOLUME_PATH=

# Bind
REDPANDA_DATA_VOLUME_TYPE=none
REDPANDA_DATA_VOLUME_OPTS=bind
REDPANDA_DATA_VOLUME_PATH=/appdata/redpanda
```

```sh
docker volume create redpanda_data
```

## Required env

- `REDPANDA_DOMAIN`, `REDPANDA_APP_URL`
- `REDPANDA_ADMIN_USER` / `REDPANDA_ADMIN_PASSWORD` (auto-generated if placeholder)
