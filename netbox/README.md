# NetBox

[NetBox](https://github.com/netbox-community/netbox-docker) DCIM/IPAM (`netboxcommunity/netbox:v4.6-5.0.2`) on **HTTP 8080**. Services: `netbox` (web) + `netbox-worker` (RQ). **PostgreSQL and Redis are external** (same overlay).

## Quick start

```sh
make netbox-setup
# edit netbox/.env (domain, DB/Redis hosts) and root .env for Swarm
make netbox-compose-up   # or: make netbox-stack-up
# first admin (SKIP_SUPERUSER=true by default):
# docker compose -f netbox/docker-compose.yml exec netbox /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py createsuperuser
```

Use Make for Swarm: `docker stack deploy` does not load `.env` alone.

## PostgreSQL (externe)

Créer le rôle et la base **avant** le premier démarrage (aligner avec `NETBOX_DB_*` dans `netbox/.env`).

Via Make (cible repo `.create-db` → `bin/create-db.sh`, service Swarm `infrastructure_postgresql` par défaut) :

```sh
# après make netbox-setup (génère NETBOX_DB_PASSWORD si vide)
set -a && source netbox/.env && set +a
make .create-db \
  DB_USER="${NETBOX_DB_USER:-netbox}" \
  DB_PASS="${NETBOX_DB_PASSWORD}" \
  DB_NAME="${NETBOX_DB_NAME:-netbox}"
# autre service Postgres : PG_SERVICE=mon_stack_postgresql make .create-db ...
```

Ou en SQL (`psql` en superuser sur l’hôte Postgres) :

```sql
CREATE USER netbox WITH PASSWORD 'ChangeMe';
CREATE DATABASE netbox OWNER netbox;
```

Exemple via `docker exec` sur un conteneur Postgres déjà lancé :

```sh
docker exec -i <postgres-container> psql -U postgres -d postgres <<'SQL'
CREATE USER netbox WITH PASSWORD 'ChangeMe';
CREATE DATABASE netbox OWNER netbox;
SQL
```

Remplacer `ChangeMe` / les noms par les valeurs de `NETBOX_DB_USER`, `NETBOX_DB_PASSWORD`, `NETBOX_DB_NAME`. Redis : configurer `NETBOX_REDIS_PASSWORD` sur l’instance externe (DB 0 tâches, DB 1 cache).

## Base path

**Unsupported / fragile** in netbox-docker (Unit static routes). Default `NETBOX_BASE_PATH=/` (Host-only subdomain). Do not rely on Traefik stripPrefix alone.

## Env / env_file

- `NETBOX_ENV_FILE`, `NETBOX_WORKER_ENV_FILE` (default `.env.example`; prod → `.env`).
- Compose merges `env_file` + `environment:`; **`environment:` wins**.
- Swarm relies on Make-exported root `.env` + compose interpolation (not Compose `env_file`).
- `netbox-setup` generates `NETBOX_SECRET_KEY`, `NETBOX_DB_PASSWORD`, `NETBOX_REDIS_PASSWORD` if empty (sync credentials on external Postgres/Redis), copies Redis password → cache password when unset, syncs `ALLOWED_HOSTS` from `NETBOX_DOMAIN`.
- `APP_NAME` (Dokploy) scopes Traefik router/service names; not listed in `.env.example`.

## Network / Traefik

Default `DEFAULT_NETWORK_NAME=netbox-network` (`EXTERNAL=false`). For shared overlay + Traefik/Postgres/Redis: set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true` **explicitly**.

No network aliases by default.

## Per-service compose

| File | Service |
|------|---------|
| `netbox-compose.yml` | `netbox` (labels) |
| `worker-compose.yml` | `netbox-worker` |

Full stack: `docker-compose.yml` (labels) / `compose.yml` (no labels).

## Ops

| Target | Role |
|--------|------|
| `netbox-setup` | Env, secrets, ALLOWED_HOSTS, network pairing |
| `netbox-stack-up` / `netbox-compose-up` | Deploy |
| `netbox-debug` / `netbox-debug-logs` | Swarm inspect |
| `netbox-pull-images` | Pull images |
