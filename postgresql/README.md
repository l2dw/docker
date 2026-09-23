# PostgreSQL

Official [Postgres 16](https://hub.docker.com/_/postgres) on a stack-local `postgresql-network` by default. To join the existing `dokploy-network`, set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true`; this stack does **not** expose HTTP via Traefik.

`.env` is **not** read by `docker stack deploy` alone — use Make (root `.env` is exported):

```sh
make postgresql-setup POSTGRESQL_PASSWORD='…'
make postgresql-stack-up
# or
make postgresql-compose-up
```

On the `postgresql` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `postgresql/`. The current compose file also carries Homepage labels for both Compose and Swarm providers.

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

When configured with `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true`, other stacks should use host `postgresql-server` (or your configured alias), port `5432`. Port is **not** published on the host by default — use an override if you need host access.

## Initialize from a backup

The `scripts` volume is mounted at `/docker-entrypoint-initdb.d`. The official
PostgreSQL image processes files in this directory **only when the data
directory is empty**, during the first initialization of the cluster. It does
not re-run them after PostgreSQL has already initialized `PGDATA`.

Supported automatic-init files are:

- `*.sql` — executed with `psql`;
- `*.sql.gz` — decompressed and executed with `psql`;
- executable `*.sh` — executed by the entrypoint shell.

The image does not recursively scan arbitrary subdirectories, so put the
restore script and backup file directly in the configured scripts directory.
For a custom-format `pg_dump -Fc` backup, use an executable restore script:

```text
scripts/
├── 010-restore.sh
└── backup.dump
```

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# The entrypoint starts a temporary local server before running this script.
# POSTGRES_USER and POSTGRES_DB come from the compose environment.
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do sleep 1; done

pg_restore \
  --exit-on-error \
  --no-owner \
  --dbname="$POSTGRES_DB" \
  /docker-entrypoint-initdb.d/backup.dump
```

Make the script executable before starting the stack:

```bash
chmod 0755 scripts/010-restore.sh
```

For a plain SQL backup, use a file such as `010-backup.sql` instead; no shell
script is needed. For a compressed plain SQL backup, use `010-backup.sql.gz`.
Do not use `pg_restore` for plain SQL dumps.

### First initialization workflow

1. Place the backup and an executable restore script in the host path selected
   by `POSTGRESQL_SCRIPTS_HOST_PATH` (default: `scripts`).
2. Ensure the data volume is new or empty. Existing PostgreSQL data is not
   overwritten by init scripts.
3. Set `POSTGRESQL_PASSWORD`, `POSTGRESQL_USER`, and `POSTGRESQL_DB`.
4. Start the stack with `make postgresql-setup` then
   `make postgresql-stack-up`.
5. Verify the restore with `psql`, for example:

```bash
docker exec -it postgresql_postgresql.1.<task-id> \
  psql -U "$POSTGRESQL_USER" -d "$POSTGRESQL_DB" -c '\\dt'
```

For an existing data volume, use an explicit `pg_restore`/`psql` operation
against the running service instead of relying on `/docker-entrypoint-initdb.d`.
Inspect backups from an untrusted source before restoring: PostgreSQL warns
that restore input can execute arbitrary code from source superusers.

Sources:

- [Docker Official Postgres image](https://github.com/docker-library/docs/blob/master/postgres/README.md)
- [PostgreSQL SQL Dump documentation](https://www.postgresql.org/docs/current/backup-dump.html)
- [PostgreSQL `pg_restore` documentation](https://www.postgresql.org/docs/current/app-pgrestore.html)

## Makefile

```sh
make postgresql-pull-images
make postgresql-setup POSTGRESQL_PASSWORD='…'
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

Placement defaults to any Linux node. Pin with `POSTGRESQL_PLACEMENT_CONSTRAINTS` when needed. The stack mounts data, logs, and initialization scripts through the configurable `POSTGRESQL_*_HOST_PATH` / `POSTGRESQL_*_CONTAINER_PATH` variables. Homepage metadata is controlled by the `POSTGRESQL_HOMEPAGE_*` variables.
