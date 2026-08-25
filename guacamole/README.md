# Guacamole

[Apache Guacamole](https://guacamole.apache.org/doc/gug/guacamole-docker.html) remote desktop gateway: web console (`guacamole/guacamole:1.6.0`, HTTP **8080**) + `guacamole-guacd` (`guacamole/guacd:1.6.0`, TCP **4822**). **PostgreSQL is external** (same overlay).

## Quick start

```sh
make guacamole-setup
# edit guacamole/.env — keep:
#   GUACAMOLE_POSTGRESQL_USERNAME=guacamole_user
#   GUACAMOLE_POSTGRESQL_DATABASE=guacamole_db
#   GUACAMOLE_POSTGRESQL_PASSWORD=...
#   GUACAMOLE_POSTGRESQL_HOSTNAME=<reachable Postgres on the overlay>
make guacamole-compose-up   # or: make guacamole-stack-up
# ↑ runs guacamole-db-init (role + schema) then deploys
```

Default login after schema init: `guacadmin` **/** `guacadmin` (change immediately).

Use Make for Swarm: `docker stack deploy` does not load `.env` alone.

## PostgreSQL (externe)

Compose maps `GUACAMOLE_POSTGRESQL_*` → container `POSTGRESQL_*`. Guacamole expects a dedicated role/DB (defaults **`guacamole_user`** / **`guacamole_db`**). The schema is **not** created by the app — `make guacamole-db-init` (also pulled in by `*-up`) does:

1. `bin/create-db.sh` — create/sync role + DB owner (auto-finds `dokploy_postgresql` or `infrastructure_postgresql`; override with `GUACAMOLE_PG_SERVICE=...`)
2. `bin/guacamole-init-schema.sh` — load `/opt/guacamole/bin/initdb.sh --postgresql` if `guacamole_entity` is missing

```sh
make guacamole-db-init
# or: make guacamole-db-init GUACAMOLE_PG_SERVICE=dokploy_postgresql
```

Manual equivalent:

```sql
CREATE USER guacamole_user WITH PASSWORD 'ChangeMe';
CREATE DATABASE guacamole_db OWNER guacamole_user;
```

```sh
docker run --rm docker.io/guacamole/guacamole:1.6.0 \
  /opt/guacamole/bin/initdb.sh --postgresql \
  | docker exec -i <postgres-container> \
      psql -U guacamole_user -d guacamole_db -f -
```

**Dokploy / Swarm:** set the same values on the service env that the container reads (`POSTGRESQL_USERNAME=guacamole_user`, etc.). Do not leave `POSTGRESQL_USERNAME=postgres` while `GUACAMOLE_POSTGRESQL_USERNAME=guacamole_user` — the app uses `POSTGRESQL_*`.

## Base path

Supported via vendor `WEBAPP_CONTEXT`. Default `GUACAMOLE_BASE_PATH=/guacamole` → `WEBAPP_CONTEXT=guacamole` (no stripPrefix). Host-only: `GUACAMOLE_BASE_PATH=/` → `WEBAPP_CONTEXT=ROOT`. Empty/`/` always allowed. `guacamole-setup` syncs context + Homepage monitor URL.

## Env / env_file

- `GUACAMOLE_ENV_FILE`, `GUACAMOLE_GUACD_ENV_FILE` (default `.env.example`; prod → `.env`).
- Compose merges `env_file` + `environment:`; `environment:` **wins**.
- Swarm relies on Make-exported root `.env` + compose interpolation.
- `REMOTE_IP_VALVE_ENABLED=true` for Traefik `X-Forwarded-*`.
- `APP_NAME` (Dokploy) scopes Traefik router/service names; not listed in `.env.example`.

## Network / Traefik

Default `DEFAULT_NETWORK_NAME=guacamole-network` (`EXTERNAL=false`). Shared overlay + Traefik/Postgres: set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true` **explicitly**. No network aliases by default.

## Per-service compose

| File                    | Service              |
| ----------------------- | -------------------- |
| `guacamole-compose.yml` | `guacamole` (labels) |
| `guacd-compose.yml`     | `guacamole-guacd`    |

Full stack: `docker-compose.yml` (labels) / `compose.yml` (no labels).

## Ops

| Target                                        | Role                                              |
| --------------------------------------------- | ------------------------------------------------- |
| `guacamole-setup`                             | Env, DB password, WEBAPP_CONTEXT, network pairing |
| `guacamole-db-init`                           | Create `guacamole_user`/`guacamole_db` + schema   |
| `guacamole-stack-up` / `guacamole-compose-up` | `db-init` then deploy                             |
| `guacamole-debug` / `guacamole-debug-logs`    | Swarm inspect                                     |
| `guacamole-pull-images`                       | Pull images                                       |
