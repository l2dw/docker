# logto

[Logto](https://logto.io) — self-hosted OIDC identity (`ghcr.io/logto-io/logto`). **External Postgres** (`DB_URL`); no database in this stack. Joins `dokploy-network`. Traefik/Homepage labels live only in `docker-compose.yml`.

Ports **3001/3002 are not published on the host**. Two DNS names: `LOGTO_DOMAIN` → OIDC (**3001**), `LOGTO_ADMIN_DOMAIN` → Admin Console (**3002**). `TRUST_PROXY_HEADER=1` so Traefik `X-Forwarded-*` is trusted.

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${LOGTO_ENV_FILE:-.env.example}`; production: `LOGTO_ENV_FILE=.env`. `environment:` wins on key conflicts.

Create the Postgres database and role first (e.g. on `dokploy-postgresql`), then:

```sh
make logto-setup \
  LOGTO_DOMAIN=logto.example.com \
  LOGTO_ADMIN_DOMAIN=admin.logto.example.com \
  LOGTO_ENDPOINT=http://logto.example.com \
  LOGTO_ADMIN_ENDPOINT=http://admin.logto.example.com \
  LOGTO_DB_URL='postgres://logto:secret@dokploy-postgresql:5432/logto'
make logto-stack-up
# or
make logto-compose-up
```

On the `logto` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `logto/`.

Startup runs `npm run cli db seed -- --swe` then `npm start` (skip seed when the DB already exists). See [deployment](https://docs.logto.io/logto-oss/deployment-and-configuration).

## Base path

**Not supported for OIDC.** `ENDPOINT` is the issuer origin — do **not** put the API under `PathPrefix` or `stripPrefix`. Default `LOGTO_BASE_PATH=/` is unused. Traefik is **Host-only**: `LOGTO_DOMAIN` → 3001, `LOGTO_ADMIN_DOMAIN` → 3002. Align `LOGTO_ENDPOINT` / `LOGTO_ADMIN_ENDPOINT` with those hosts.

## Required env

| Variable | Notes |
|----------|--------|
| `LOGTO_DOMAIN` / `LOGTO_ADMIN_DOMAIN` | Traefik Host() (warns if `example.com`) |
| `LOGTO_ENDPOINT` / `LOGTO_ADMIN_ENDPOINT` | Public OIDC + Admin URLs (must match Traefik) |
| `LOGTO_DB_URL` | External Postgres DSN (warns if `ChangeMe`) |
| `LOGTO_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `APP_NAME` | Optional. Dokploy sets this; **not** in `.env.example`. Traefik router/service names default to `logto` / `logto-admin`; with `APP_NAME` they become `${APP_NAME}` / `${APP_NAME}-admin` so two Logto apps on the same Traefik do not collide. |

Do not commit `logto/.env` or real secrets.

## Makefile

```sh
make logto-setup
make logto-pull-images
make logto-stack-up
make logto-stack-upgrade
make logto-stack-down
make logto-debug
make logto-debug-logs
make logto-compose-up
make logto-compose-down
make logto-compose-logs
```
