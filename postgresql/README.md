# PostgreSQL

Swarm/compose template for Postgres 16 on the shared `dokploy-network`.

## Setup

```sh
# From devops/docker-templates (parent of postgresql/)
cp postgresql/.env.example postgresql/.env   # or merge into root .env
# set a real POSTGRESQL_PASSWORD
```

## Makefile

```sh
make postgresql-pull-images
make postgresql-stack-up
make postgresql-stack-down
make postgresql-stack-recreate
make postgresql-stack-logs
make postgresql-stack-watch-logs
make postgresql-debug
make postgresql-debug-logs
# compose (non-swarm)
make postgresql-compose-up
make postgresql-compose-down
make postgresql-compose-recreate
make postgresql-compose-logs
make postgresql-compose-watch-logs
```

Service DNS name on the overlay: `postgresql` (stack task: `postgresql_postgresql`).

## Notes

- `POSTGRESQL_PASSWORD` is required (no silent default).
- Default placement is `node.role == worker`; change for single-node / manager-only swarms.
- Leave `POSTGRESQL_DATA_DIR` / `POSTGRESQL_LOGS_DIR` empty to use named volumes.
