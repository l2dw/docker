# Guacamole

[Apache Guacamole](https://guacamole.apache.org/doc/gug/guacamole-docker.html) remote desktop gateway: web console (`guacamole/guacamole:1.6.0`, HTTP **8080**) + `guacamole-guacd` (`guacamole/guacd:1.6.0`, TCP **4822**). **PostgreSQL is external** (same overlay).

## Quick start

```sh
make guacamole-setup
# create Postgres role/DB + load schema (see below), then:
make guacamole-compose-up   # or: make guacamole-stack-up
```

Default login after schema init: `guacadmin` **/** `guacadmin` (change immediately).

Use Make for Swarm: `docker stack deploy` does not load `.env` alone.

## PostgreSQL (externe)

Créer le rôle et la base **avant** le premier démarrage, puis charger le schéma Guacamole.

### Rôle et base

Via Make (`.create-db` → `bin/create-db.sh`) :

```sh
set -a && source guacamole/.env && set +a
make .create-db \
  DB_USER="${GUACAMOLE_POSTGRESQL_USERNAME:-guacamole_user}" \
  DB_PASS="${GUACAMOLE_POSTGRESQL_PASSWORD}" \
  DB_NAME="${GUACAMOLE_POSTGRESQL_DATABASE:-guacamole_db}"
```

Ou en SQL :

```sql
CREATE USER guacamole_user WITH PASSWORD 'ChangeMe';
CREATE DATABASE guacamole_db OWNER guacamole_user;
```

```sh
docker exec -i <postgres-container> psql -U postgres -d postgres <<'SQL'
CREATE USER guacamole_user WITH PASSWORD 'ChangeMe';
CREATE DATABASE guacamole_db OWNER guacamole_user;
SQL
```



### Schéma Guacamole

L’image fournit `initdb.sh` (Guacamole **ne** crée **pas** les tables tout seul) :

```sh
docker run --rm docker.io/guacamole/guacamole:1.6.0 \
  /opt/guacamole/bin/initdb.sh --postgresql \
  | docker exec -i <postgres-container> \
      psql -U guacamole_user -d guacamole_db -f -
```

Aligner user/DB/password avec `GUACAMOLE_POSTGRESQL_*`.

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
| `guacamole-stack-up` / `guacamole-compose-up` | Deploy                                            |
| `guacamole-debug` / `guacamole-debug-logs`    | Swarm inspect                                     |
| `guacamole-pull-images`                       | Pull images                                       |


