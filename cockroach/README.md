# CockroachDB

[CockroachDB](https://www.cockroachlabs.com/) — Postgres-wire distributed SQL (`start-single-node`, insecure TLS). DB Console via Traefik (HTTP **8080**). SQL **26257** is published in both compose files.

Useful as the external DB for stacks like Huly (`HULY_CR_DB_URL=postgres://selfhost:…@cockroach:26257/defaultdb`). Single-node Docker is for lab / shared overlay — not multi-region HA.

## Quick start

```sh
make cockroach-setup
# Edit cockroach/.env — COCKROACH_DOMAIN / COCKROACH_APP_URL / password
make cockroach-stack-up      # Swarm
# or
make cockroach-compose-up    # Compose
```

Debug: `make cockroach-debug` / `make cockroach-debug-logs`.

`docker stack deploy` does **not** load Compose `env_file` reliably — use Make (exports root `.env`) + `environment:` interpolation.

## Base path

DB Console subpath is **not** supported. Keep `COCKROACH_BASE_PATH=/` and a dedicated subdomain (`COCKROACH_DOMAIN`).

## Traefik / Homepage

Labels: Traefik only in `docker-compose.yml`. Homepage labels are on both compose files. `APP_NAME` scopes Traefik router/service names.

| Listener | How |
|----------|-----|
| DB Console `:8080` | Traefik HTTP + Homepage on `docker-compose.yml` — **no** host `ports:` |
| SQL `:26257` | Long-form `ports:` in **both** compose files (`COCKROACH_SQL_*`) |
| Overlay DNS | Service key `cockroach`; `compose.yml` also sets alias `${COCKROACH_ALIAS}` (default `cockroach`) |

## Credentials / client URL

```env
COCKROACH_DATABASE=defaultdb
COCKROACH_USER=selfhost
COCKROACH_PASSWORD=ChangeMe
```

Example client URL (Postgres protocol):

```text
postgres://selfhost:…@cockroach:26257/defaultdb
```

`make cockroach-setup` generates `COCKROACH_PASSWORD` when still `ChangeMe`.

## env_file

`COCKROACH_ENV_FILE` (default `.env.example`). Production → `.env`. `environment:` overrides. Swarm: Make-exported root `.env`.

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `EXTERNAL` |
|------|------------------------|------------|
| Stack-local (default) | `cockroach-network` | `false` |
| Shared Traefik / apps (e.g. Huly) | `dokploy-network` | `true` |

`make cockroach-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

```sh
docker network create cockroach-network --driver overlay   # Swarm
docker network create cockroach-network --driver bridge    # Compose
```

## Volumes

| Compose key | Container path | Default name |
|-------------|----------------|--------------|
| `data` | `/cockroach/cockroach-data` | `cockroach_data` |
| `certs` | `/cockroach/certs` | `cockroach_certs` |

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|------------|--------|--------|--------|
| Local named (default) | `false` | empty | empty | empty |
| Bind | `false` | `none` | `bind` | `/appdata/cockroach` |
| NFS | `false` | `nfs` | `addr=host,rw,nfsvers=4` | `:/exports/cockroach` |
| External | `true` | — | — | — |

```env
# Local named
COCKROACH_DATA_VOLUME_TYPE=
COCKROACH_DATA_VOLUME_OPTS=
COCKROACH_DATA_VOLUME_PATH=

# Bind
COCKROACH_DATA_VOLUME_TYPE=none
COCKROACH_DATA_VOLUME_OPTS=bind
COCKROACH_DATA_VOLUME_PATH=/appdata/cockroach
```

```sh
docker volume create cockroach_data
docker volume create cockroach_certs
```

## Required env

- `COCKROACH_DOMAIN`, `COCKROACH_APP_URL`
- `COCKROACH_USER` / `COCKROACH_PASSWORD` (auto-generated if placeholder)
