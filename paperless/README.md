# paperless

[Paperless-ngx](https://docs.paperless-ngx.com/) document management on **TCP 8000**. Joins `dokploy-network`. Traefik is the ingress; port 8000 is **not** published on the host.

This stack is the **webserver only**. Redis and PostgreSQL must already be on the overlay:

| Need | Default hostname | Env |
|------|------------------|-----|
| Broker | `dokploy-redis:6379` | `PAPERLESS_REDIS=redis://:<REDIS_PASSWORD>@dokploy-redis:6379` |
| Database | `dokploy-postgresql:5432` | `PAPERLESS_DBHOST`, `PAPERLESS_DBNAME=paperless`, user/password |

Create the Postgres database/user before the first start. Tika/Gotenberg (Office/.eml) are **not** included; add them later if you need those converters.

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${PAPERLESS_ENV_FILE:-.env.example}`; production: `PAPERLESS_ENV_FILE=.env`. `environment:` wins on key conflicts.

```sh
make paperless-setup
make paperless-stack-up
# or
make paperless-compose-up
```

## Base path

Paperless **supports** a URL prefix via `PAPERLESS_FORCE_SCRIPT_NAME` and `PAPERLESS_STATIC_URL` (trailing slash on STATIC_URL). Do **not** add Traefik `stripPrefix` — the app must see `/paperless/...`.

`PAPERLESS_URL` is the public origin **without a path** (CSRF / ALLOWED_HOSTS). Example: `http://paperless.example.com` even when the UI lives at `/paperless`.

| `PAPERLESS_BASE_PATH` | Traefik | App |
|-----------------------|---------|-----|
| `/paperless` (default) | `Host` + `PathPrefix(/paperless)` | `FORCE_SCRIPT_NAME=/paperless`, `STATIC_URL=/paperless/static/` |
| `/` | Host-only | empty `FORCE_SCRIPT_NAME`, `STATIC_URL=/static/` |

`make paperless-setup` aligns FORCE / STATIC / healthcheck URL from `PAPERLESS_BASE_PATH`. Set `PAPERLESS_HOMEPAGE_HREF` to the public URL including the path when using a prefix.

## Volumes

Four **named volumes** (Swarm treats `${PAPERLESS_*_BIND}:/usr/src/paperless/...` as named volumes after interpolation — do not put `/appdata/...` in those vars). Named `*_BIND` so they do not collide with Paperless’s own path settings.

| Var | Container path |
|-----|----------------|
| `PAPERLESS_DATA_BIND` | `/usr/src/paperless/data` |
| `PAPERLESS_MEDIA_BIND` | `/usr/src/paperless/media` |
| `PAPERLESS_EXPORT_BIND` | `/usr/src/paperless/export` |
| `PAPERLESS_CONSUME_BIND` | `/usr/src/paperless/consume` (drop PDFs here) |

Host bind: gitignored Compose override `type: bind` (directory must exist).

## Makefile

```sh
make paperless-setup
make paperless-pull-images
make paperless-stack-up
make paperless-stack-upgrade
make paperless-stack-down
make paperless-debug
make paperless-debug-logs
make paperless-compose-up
make paperless-compose-down
make paperless-compose-logs
```

Setup generates `PAPERLESS_SECRET_KEY` and `PAPERLESS_ADMIN_PASSWORD` when empty, warns on `example.com` / `ChangeMe` Redis or DB password, and syncs `DEFAULT_NETWORK_EXTERNAL`.

## Required env

| Variable | Notes |
|----------|--------|
| `PAPERLESS_DOMAIN` | Public host (warns on `example.com`) |
| `PAPERLESS_URL` | Origin without path |
| `PAPERLESS_REDIS` | Full Redis URL including password |
| `PAPERLESS_DBPASS` | Postgres password for `PAPERLESS_DBUSER` |
| `PAPERLESS_BASE_PATH` | Default `/paperless`; `/` for a dedicated subdomain |
| `PAPERLESS_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `DEFAULT_NETWORK_NAME` / `DEFAULT_NETWORK_EXTERNAL` | Join `dokploy-network` with `external=true` |

Do not commit `paperless/.env`.
