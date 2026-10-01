# RabbitMQ

[RabbitMQ](https://www.rabbitmq.com/) message broker (`4-management-alpine`) — management UI via Traefik (HTTP **15672**). AMQP **5672** is published only in unlabeled `compose.yml`; `docker-compose.yml` exposes AMQP on the overlay (service DNS `broker`, plus aliases when using `compose.yml`).

## Quick start

```sh
make rabbitmq-setup
# Edit rabbitmq/.env — RABBITMQ_DOMAIN / RABBITMQ_APP_URL / credentials
make rabbitmq-stack-up      # Swarm
# or
make rabbitmq-compose-up    # Compose
```

Debug: `make rabbitmq-debug` / `make rabbitmq-debug-logs`.

`docker stack deploy` does **not** load Compose `env_file` reliably — use Make (exports root `.env`) + `environment:` interpolation.

## Base path

Management UI subpath is **not** configured. Keep `RABBITMQ_BASE_PATH=/` and a dedicated subdomain (`RABBITMQ_DOMAIN`).

## Traefik / Homepage

Labels only in `docker-compose.yml`. `compose.yml` is unlabeled. `APP_NAME` scopes Traefik router/service names (`APP_NAME=rabbitmq`; Dokploy may override).

| Listener | How |
|----------|-----|
| Management UI `:15672` | Traefik HTTP + Homepage (`RABBITMQ_PORT`) on `docker-compose.yml` — **no** host `ports:` |
| AMQP `:5672` | Long-form `ports:` **only** in `compose.yml` (`RABBITMQ_AMQP_*`) |
| Overlay DNS | Service key `broker`; `compose.yml` also sets aliases `${APP_NAME}` / `${RABBITMQ_ALIAS}` (default `rabbitmq`) |

## Credentials / AMQP URL

```env
RABBITMQ_DEFAULT_USER=rabbit
RABBITMQ_DEFAULT_PASS=ChangeMe
RABBITMQ_DEFAULT_VHOST=/
```

Example client URL: `amqp://rabbit:…@rabbitmq:5672/` (vhost `/`). `make rabbitmq-setup` generates `RABBITMQ_DEFAULT_PASS` when still `ChangeMe`.

`hostname` is fixed via `RABBITMQ_HOSTNAME` (default `rabbitmq`) so Mnesia data stays stable across restarts.

## env_file

`RABBITMQ_ENV_FILE` (default `.env.example`). Production → `.env`. `environment:` overrides. Swarm: Make-exported root `.env`.

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `EXTERNAL` |
|------|------------------------|------------|
| Stack-local (default) | `rabbitmq-network` | `false` |
| Shared Traefik / apps (e.g. Plane) | `dokploy-network` | `true` |

`make rabbitmq-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

```sh
docker network create rabbitmq-network --driver overlay   # Swarm
docker network create rabbitmq-network --driver bridge    # Compose
```

## Volumes

Compose key **`data`** → `${RABBITMQ_DATA_VOLUME_DIR:-/var/lib/rabbitmq}`:

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|------------|--------|--------|--------|
| Local named (default) | `false` | empty | empty | empty |
| Bind | `false` | `none` | `bind` | `/appdata/rabbitmq` |
| NFS | `false` | `nfs` | `addr=host,rw,nfsvers=4` | `:/exports/rabbitmq` |
| External | `true` | — | — | — |

```env
# Local named
RABBITMQ_DATA_VOLUME_TYPE=
RABBITMQ_DATA_VOLUME_OPTS=
RABBITMQ_DATA_VOLUME_PATH=
RABBITMQ_DATA_VOLUME_DIR=/var/lib/rabbitmq

# Bind
RABBITMQ_DATA_VOLUME_TYPE=none
RABBITMQ_DATA_VOLUME_OPTS=bind
RABBITMQ_DATA_VOLUME_PATH=/appdata/rabbitmq
```

```sh
docker volume create rabbitmq_data
```

## Required env

- `RABBITMQ_DOMAIN`, `RABBITMQ_APP_URL`
- `RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` (auto-generated if placeholder)
