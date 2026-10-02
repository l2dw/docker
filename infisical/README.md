# Infisical

[Infisical](https://infisical.com) — open-source secrets management (`infisical/infisical`, HTTP **8080**). Traefik on `docker-compose.yml`; Homepage on both compose files.

PostgreSQL and Redis are **external** — this stack has **no** `db` / `redis` services (see § PostgreSQL externe / § Redis externe).

## Quick start

```sh
make infisical-setup
# Edit infisical/.env — DOMAIN / SITE_URL / APP_URL / DB + Redis URIs
make infisical-stack-up      # Swarm
# or
make infisical-compose-up    # Compose
```

**Prerequisite:** create the PostgreSQL role and database **before first start**. First successful boot: open `INFISICAL_SITE_URL` and create the admin account (first signup becomes admin).

Debug: `make infisical-debug` / `make infisical-debug-logs`.

`docker stack deploy` does **not** load Compose `env_file` reliably — use Make (exports root `.env`) + `environment:` interpolation.

## Base path

Subpath is **not** supported. Keep `INFISICAL_BASE_PATH=/` and a dedicated subdomain. `INFISICAL_SITE_URL` must match the public URL (protocol + host) for OAuth/SSO redirects. No `stripPrefix`.

## Traefik / Homepage

Labels: Traefik only in `docker-compose.yml`. Homepage on both compose files. `APP_NAME` scopes Traefik router/service names. `passhostheader=true` for OAuth/SSO.

| Service | Role | Port |
|---------|------|------|
| `infisical` | API + UI | **8080** |

## Credentials

| Var | Note |
|-----|------|
| `INFISICAL_ENCRYPTION_KEY` | `openssl rand -hex 16` — **encrypts all stored secrets** (backup this) |
| `INFISICAL_AUTH_SECRET` | `openssl rand -base64 32` — JWT signing |
| `INFISICAL_DB_CONNECTION_URI` | External Postgres DSN |
| `INFISICAL_REDIS_URL` | External Redis URL |

`make infisical-setup` generates the two secrets when empty.

## env_file

`INFISICAL_ENV_FILE` (default `.env.example`). Production → `.env`. `environment:` overrides. Swarm: Make-exported root `.env`.

Keep `INFISICAL_HOST=0.0.0.0` (vendor binary defaults to localhost). `NODE_OPTIONS=--max-old-space-size=768` stays under `INFISICAL_MEMORY_LIMIT=1G`.

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `EXTERNAL` |
|------|------------------------|------------|
| Stack-local (default) | `infisical-network` | `false` |
| Shared Traefik / apps / DB on overlay | `dokploy-network` | `true` |

`make infisical-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

External Postgres/Redis must be reachable from the overlay (same Swarm network, or a routable address). Never expose **5432** / **6379** publicly.

```sh
docker network create infisical-network --driver overlay   # Swarm
docker network create infisical-network --driver bridge    # Compose
```

## Volumes

This stack has **no volumes** — persistent state lives in external PostgreSQL/Redis.

## PostgreSQL externe

Create the role and database **before first start**. The role must **own** the database with full DDL rights (Infisical runs migrations on boot).

```sh
DB_PASS=$(openssl rand -hex 24)
DB_HOST=<adresse IP ou DNS Postgres>
psql -h "$DB_HOST" -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE USER infisical WITH PASSWORD '$DB_PASS'"
psql -h "$DB_HOST" -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE infisical OWNER infisical"
```

```env
INFISICAL_DB_CONNECTION_URI=postgresql://infisical:<mdp>@<DB_HOST>:5432/infisical
# TLS example: .../infisical?sslmode=verify-full
```

`make infisical-setup` warns if the URI still contains `dbhost` or `ChangeMe`.

## Redis externe

Redis is **required** — Infisical will not start without it.

```env
INFISICAL_REDIS_URL=redis://<REDIS_HOST>:6379
# With password: redis://:<mdp>@<REDIS_HOST>:6379
# TLS: rediss://...
```

`make infisical-setup` warns if the URL still contains `redishost`.

## Required env

- `INFISICAL_DOMAIN`, `INFISICAL_SITE_URL`, `INFISICAL_APP_URL`
- `INFISICAL_ENCRYPTION_KEY`, `INFISICAL_AUTH_SECRET` (auto-generated if empty)
- `INFISICAL_DB_CONNECTION_URI`, `INFISICAL_REDIS_URL`
