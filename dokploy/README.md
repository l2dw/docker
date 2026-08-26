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

Routers `dokploy-console` / `dokploy-traefik` and global middlewares (`waf`, `redirect-to-https`, …) use **fixed** infra names (not `${APP_NAME}`).

## Deploy

`.env` is **not** read by `docker stack deploy` alone — use Make (exports root `.env`) or export manually:

```sh
make dokploy-setup
make dokploy-stack-up      # or: make dokploy-compose-up
```

Compose also loads `env_file` (`DOKPLOY_*_ENV_FILE`, default `.env.example` under `dokploy/`). `environment:` overrides the file. For Swarm, rely on Make export + `environment:` interpolation.

Copy [`dokploy/.env.example`](.env.example) keys into root `.env` and set secrets before deploy.

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
