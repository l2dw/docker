# Dokploy stack

Infra platform: **Dokploy** + **PostgreSQL** + **Redis** + **Traefik** + **certs-dumper** + **WAF** (ModSecurity CRS).

This is the shared overlay host (`dokploy-network`), not an app stack that joins it. Service DNS aliases (`dokploy-postgresql`, `dokploy-redis`, `dokploy-waf`, `dokploy-traefik`) stay stable for other stacks.

## Layout

| File | Role |
|------|------|
| [`docker-compose.yml`](docker-compose.yml) | Full stack (Make / Swarm). Traefik + Homepage labels on `dokploy` and `traefik`. |
| [`dokploy-compose.yml`](dokploy-compose.yml) | Console service only (`dokploy`) + same Traefik/Homepage labels. Expects Postgres/Redis (and Traefik) already on the overlay. |
| [`compose.yml`](compose.yml) | Symlink → `dokploy-compose.yml` |

Root symlinks (on this branch): `README.md`, `compose.yml`, `docker-compose.yml` → `dokploy/…`.

Routers `${APP_NAME:-dokploy}-console` / `${APP_NAME:-dokploy}-traefik` scope Traefik ingress per Dokploy app instance. Global middlewares (`waf`, `redirect-to-https`, …) stay fixed on the Traefik service. `APP_NAME` is injected by Dokploy — not listed in `.env.example`.

## Deploy

`.env` is **not** read by `docker stack deploy` alone — use Make (exports root `.env`) or export manually:

```sh
make dokploy-setup
make dokploy-stack-up      # or: make dokploy-compose-up
```

Compose also loads `env_file` (`DOKPLOY_*_ENV_FILE`, default `.env.example` under `dokploy/`). `environment:` overrides the file. For Swarm, rely on Make export + `environment:` interpolation.

Copy [`dokploy/.env.example`](.env.example) keys into root `.env` and set secrets before deploy.

Required runtime variables include `DOKPLOY_DATABASE_URL`,
`DOKPLOY_POSTGRES_PASSWORD`, `DOKPLOY_POSTGRES_SUPERUSER_PASSWORD`,
`DOKPLOY_BETTER_AUTH_SECRET`, and `DOKPLOY_ADVERTISE_ADDR`. The setup target
rejects empty or placeholder values for the secrets and database URL.

The Docker client configuration is persisted through `DOKPLOY_DOCKER_DIR`,
`DOKPLOY_DOCKER_VOLUME_NAME`, and `DOKPLOY_DOCKER_VOLUME_EXTERNAL`. PostgreSQL
and Redis container mount paths are configurable with the respective
`*_PGDATA_PATH`, `*_LOGS_PATH`, and `*_DATA_PATH` variables.

`docker stack deploy` does **not** support nested interpolation (`${A:-${B:-x}}`). Each key uses a single-level default.

| Service | Mode | Replicas | Placement | Memory |
|---------|------|----------|-----------|--------|
| postgresql | `DOKPLOY_POSTGRES_DEPLOY_MODE` | `DOKPLOY_POSTGRES_DEPLOY_REPLICAS` | `DOKPLOY_POSTGRES_PLACEMENT_CONSTRAINTS` | `DOKPLOY_POSTGRES_MEMORY_LIMIT` (default 1G) |
| redis | `DOKPLOY_REDIS_*` | … | … | `DOKPLOY_REDIS_MEMORY_LIMIT` |
| dokploy | `DOKPLOY_DOKPLOY_*` | … | … | `DOKPLOY_MEMORY_LIMIT` |
| traefik | `DOKPLOY_TRAEFIK_*` | … | … | `DOKPLOY_TRAEFIK_MEMORY_LIMIT` |
| certs-dumper | `DOKPLOY_CERTS_DUMPER_*` | … | … | `DOKPLOY_CERTS_DUMPER_MEMORY_LIMIT` |
| waf | `DOKPLOY_WAF_*` | … | … | `DOKPLOY_WAF_MEMORY_LIMIT` |

Stateful services (postgres/redis) should stay at `replicas=1`. Network: `DEFAULT_NETWORK_NAME=dokploy-network` ⇒ `DEFAULT_NETWORK_EXTERNAL=true` (`make dokploy-setup` upserts the pair).

### Swarm `endpoint_mode` (postgres / redis)

| Variable | Default | Effect |
|----------|---------|--------|
| `DOKPLOY_POSTGRES_ENDPOINT_MODE` | `vip` | Stable DNS: `dokploy-postgresql` (alias) and `dokploy_postgresql` |
| `DOKPLOY_REDIS_ENDPOINT_MODE` | `vip` | Same pattern for `dokploy-redis` |

Use `dnsrr` only if you need per-task DNS. Then clients must use `tasks.dokploy_postgresql` (the compose alias often does **not** resolve under dnsrr). Prefer `vip` with `update_config.order: stop-first` (already set) when PGDATA is bind-mounted.

### Shared Bitnami PGDATA

To reuse `/infra/postgresql-16` data under Swarm:

```env
DOKPLOY_POSTGRES_IMAGE=bitnami/postgresql:16
DOKPLOY_POSTGRES_DATA_DIR=/appdata/postgresql-16/data
DOKPLOY_POSTGRES_PGDATA_PATH=/bitnami/postgresql/data
DOKPLOY_POSTGRES_USER=root          # match Bitnami POSTGRESQL_USERNAME
DOKPLOY_POSTGRES_DB=root
DOKPLOY_POSTGRES_PASSWORD=…         # POSTGRESQL_PASSWORD
DOKPLOY_POSTGRES_SUPERUSER_PASSWORD=…  # POSTGRESQL_POSTGRES_PASSWORD
```

**Do not** run the Compose container `postgresql` (`/infra/postgresql-16`) while `dokploy_postgresql` is up — same PGDATA → corruption. Stop one before starting the other (`docker update --restart=no postgresql` if leaving the old container stopped).

Official `postgres:16` cannot mount Bitnami data as-is (UID **1001** vs **999**).

### HTTPS / Traefik labels

Console router uses **`DOKPLOY_ENTRYPOINTS` / `DOKPLOY_TLS_*`** (not `DOKPLOY_TRAEFIK_*`):

```env
DOKPLOY_ENTRYPOINTS=websecure
DOKPLOY_TLS_ENABLED=true
DOKPLOY_TLS_CERTRESOLVER=default
DOKPLOY_DOMAIN=ops-dev.example.edu
```

Dashboard router uses `DOKPLOY_TRAEFIK_ENTRYPOINTS`, `DOKPLOY_TRAEFIK_TLS_*`, and needs `DOKPLOY_TRAEFIK_LABELS_SWARM_ENABLE=true`. Dashboard URL: `https://$DOKPLOY_DOMAIN/traefik/dashboard/` (not bare `/traefik/`).

Passwords in `DOKPLOY_DATABASE_URL` that contain `@` must be URL-encoded (`@` → `%40`).

## Makefile

```sh
make dokploy-pull-images
make dokploy-setup
make dokploy-stack-up
make dokploy-stack-upgrade
make dokploy-stack-down
make dokploy-stack-logs
make dokploy-debug
make dokploy-debug-logs
make dokploy-compose-up
make dokploy-compose-down
```

## Traefik

Configuration is via `command:` in [`docker-compose.yml`](docker-compose.yml) (no `traefik.yml`). Dynamic middlewares live in [`etc/traefik/rules/`](../etc/traefik/rules/).

### Global WAF middleware

| Source | Reference |
|--------|-----------|
| Traefik service labels (swarm + docker) | `waf` / `waf@swarm` / `waf@docker` |
| [`etc/traefik/rules/middlewares.yml`](../etc/traefik/rules/middlewares.yml) | `waf@file` |

| Variable | Default |
|----------|---------|
| `DOKPLOY_TRAEFIK_WEB_MIDDLEWARES` | `waf` |
| `DOKPLOY_TRAEFIK_WEBSECURE_MIDDLEWARES` | `waf` |
| `DOKPLOY_WAF_MODSECURITY_URL` | `http://dokploy-waf:8080` |
| `DOKPLOY_WAF_BACKEND` | `http://dokploy-waf-dummy:80` |

```sh
DOKPLOY_WAF_MODSECURITY_URL=http://dokploy-waf:8080
DOKPLOY_WAF_BACKEND=http://dokploy-waf-dummy:80
```

**`waf-dummy`** (`traefik/whoami`) is the CRS Apache upstream (`BACKEND`). Without a reachable backend, ModSecurity proxies to `localhost:80` inside the WAF container and Traefik’s plugin returns **503**. Keep `DOKPLOY_WAF_BACKEND` on `dokploy-waf-dummy` (or another real HTTP service on the overlay).

Certificates bind path: set `DOKPLOY_TRAEFIK_CERTIFICATES_DIR` when using a host directory instead of the named volume (Traefik + certs-dumper + Dokploy console mount).

`stack-deploy` resolves compose under `$(INFRA_DIR)/$(STACK_NAME)/` and sources that project’s `.env` before deploy.

### Real client IP

- Access log keeps `ClientHost` / `ClientAddr` and `X-Forwarded-For` / `X-Real-Ip`.
- `DOKPLOY_TRAEFIK_FORWARDED_HEADERS_TRUSTED_IPS` — trusted peers for `X-Forwarded-*`.
- WAF: `DOKPLOY_WAF_PROXY=1` + `DOKPLOY_WAF_REMOTEIP_INT_PROXY` (space-separated CIDRs).

## WAF custom rules

Versioned under [`etc/waf/rules/`](../etc/waf/rules/). Delivered as **Swarm configs**:

| Config | Source env | Target in container |
|--------|------------|---------------------|
| `dokploy_waf_before_crs` | `DOKPLOY_WAF_BEFORE_CRS_RULES` | `…/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` |
| `dokploy_waf_after_crs` | `DOKPLOY_WAF_AFTER_CRS_RULES` | `…/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf` |

After editing rule files, bump `DOKPLOY_WAF_*_CRS_CONFIG_NAME` and redeploy.

## Base path

Dokploy console: `DOKPLOY_BASE_PATH=/` (Host-only by default). Traefik dashboard: `DOKPLOY_TRAEFIK_BASE_PATH=/traefik`.

## Troubleshoot

1. Swarm service `0/1`: `make dokploy-debug` / `dokploy-debug-logs`.
2. Image tag unchanged but digest moved: `make dokploy-stack-upgrade`.
3. HTTPS `404 page not found` but HTTP works: console stuck on `entrypoints=web` — set `DOKPLOY_ENTRYPOINTS=websecure` + `DOKPLOY_TLS_ENABLED=true` (not only `DOKPLOY_TRAEFIK_*`).
4. `wait-for-postgres` timeout: check `DOKPLOY_DATABASE_URL` host (`dokploy-postgresql` with vip; `tasks.dokploy_postgresql` with dnsrr) and URL-encoding of passwords with `@`.
5. certs-dumper exit 1 / `apk … jq`: set `DOKPLOY_CERTS_DUMPER_ENV_FILE=.env` and campus proxy **IP** in `HTTP_PROXY` / `http_proxy` (see commented block in `.env.example`, e.g. `10.139.33.12:80`).
6. Never start `/infra/postgresql-16` and `dokploy_postgresql` together on the same `DOKPLOY_POSTGRES_DATA_DIR`.
