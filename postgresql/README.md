# PostgreSQL

Official [Postgres 16](https://hub.docker.com/_/postgres) on the shared overlay (`dokploy-network`). Joins existing Traefik/infra; this stack does **not** expose HTTP via Traefik.

`.env` is **not** read by `docker stack deploy` alone — use Make (root `.env` is exported):

```sh
make postgresql-stack-setup POSTGRESQL_PASSWORD='…'
make postgresql-stack-up
# or
make postgresql-compose-up
```

On the `postgresql` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `postgresql/`. Inside the project, `compose.yml` → `docker-compose.yml` (no Traefik/Homepage labels; files would be identical).

## Images

Set `POSTGRESQL_IMAGE` in `.env` (default: official Postgres 16). Examples:

| Use case | Example `POSTGRESQL_IMAGE` | Docs |
|----------|----------------------------|------|
| Postgres (default) | `docker.io/library/postgres:16` | [Docker Hub](https://hub.docker.com/_/postgres) · [PostgreSQL docs](https://www.postgresql.org/docs/current/) |
| PostGIS | `docker.io/postgis/postgis:16-3.5` | [Docker Hub](https://hub.docker.com/r/postgis/postgis) · [PostGIS docs](https://postgis.net/documentation/) |
| PostGIS (PG15) | `docker.io/postgis/postgis:15-3.5` | same as above |
| Vector (`pgvecto.rs`) | `docker.io/tensorchord/pgvecto-rs:pg15-v0.3.0` | [Docker Hub](https://hub.docker.com/r/tensorchord/pgvecto-rs) · [GitHub / docs](https://github.com/tensorchord/pgvecto.rs) |

```sh
# PostGIS — https://hub.docker.com/r/postgis/postgis
POSTGRESQL_IMAGE=docker.io/postgis/postgis:16-3.5

# Vector (pgvecto.rs on Postgres 15) — https://hub.docker.com/r/tensorchord/pgvecto-rs
POSTGRESQL_IMAGE=docker.io/tensorchord/pgvecto-rs:pg15-v0.3.0
```

Changing the image after the data volume already exists can break the cluster (major version / extension mismatch). Prefer a fresh volume or a documented upgrade path.

After extensions are available in the image, enable them in SQL as needed, e.g. `CREATE EXTENSION postgis;` or the vector extension documented by the image ([pgvecto.rs usage](https://github.com/tensorchord/pgvecto.rs#quick-start)).

## Connectivity

| Name | Role |
|------|------|
| Swarm service | `postgresql_postgresql` |
| Network alias | `POSTGRESQL_NETWORK_ALIAS` (default `postgresql-server`) |

Other stacks on `dokploy-network` should use host `postgresql-server` (or your alias), port `5432`. Port is **not** published on the host by default — use an override if you need host access.

## Makefile

```sh
make postgresql-pull-images
make postgresql-stack-setup POSTGRESQL_PASSWORD='…'
make postgresql-stack-up
make postgresql-stack-upgrade
make postgresql-stack-down
make postgresql-stack-logs
make postgresql-debug
make postgresql-debug-logs
make postgresql-compose-up
make postgresql-compose-down
```

## Required env

| Variable | Notes |
|----------|--------|
| `POSTGRESQL_PASSWORD` | Required — no silent default |
| `POSTGRESQL_USER` | Default `postgres` |
| `POSTGRESQL_DB` | Default `postgres` |
| `POSTGRESQL_NETWORK_ALIAS` | Stable DNS for other apps (default `postgresql-server`) |

Placement defaults to any Linux node. Pin with `POSTGRESQL_PLACEMENT_CONSTRAINTS` when needed. `update_config.order=stop-first` avoids two tasks sharing the same PGDATA bind/volume during rolling updates.
