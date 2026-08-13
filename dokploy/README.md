# Dokploy stack

WordPress platform stack: **Dokploy** + **PostgreSQL** + **Redis** + **Traefik** + **certs-dumper** + **WAF** (ModSecurity CRS).

Compose file: [`docker-compose.yml`](docker-compose.yml) (Swarm `stack deploy` and Compose).

`.env` is **not** read by `docker stack deploy` alone — export it (or use `make`, which loads the repo-root `.env`):

```sh
# From devops/docker-templates (parent of dokploy/)
make dokploy-stack-up
# or:
set -a && source .env && set +a
docker stack deploy -c dokploy/docker-compose.yml dokploy --with-registry-auth
```

Copy [`dokploy/.env.example`](.env.example) keys into the root `.env` (and/or `dokploy/.env`) and set secrets before deploy.

## Deploy (Swarm)

Per-service vars fall back to stack defaults (`DOKPLOY_DEPLOY_*` / `DOKPLOY_PLACEMENT_CONSTRAINTS`), then hard-coded defaults (`replicated` / `1` / `node.role == manager`).

| Service | Mode | Replicas | Placement |
|---------|------|----------|-----------|
| postgresql | `DOKPLOY_POSTGRES_DEPLOY_MODE` | `DOKPLOY_POSTGRES_DEPLOY_REPLICAS` | `DOKPLOY_POSTGRES_PLACEMENT_CONSTRAINTS` |
| redis | `DOKPLOY_REDIS_DEPLOY_MODE` | `DOKPLOY_REDIS_DEPLOY_REPLICAS` | `DOKPLOY_REDIS_PLACEMENT_CONSTRAINTS` |
| dokploy | `DOKPLOY_DOKPLOY_DEPLOY_MODE` | `DOKPLOY_DOKPLOY_DEPLOY_REPLICAS` | `DOKPLOY_DOKPLOY_PLACEMENT_CONSTRAINTS` |
| traefik | `DOKPLOY_TRAEFIK_DEPLOY_MODE` | `DOKPLOY_TRAEFIK_DEPLOY_REPLICAS` | `DOKPLOY_TRAEFIK_PLACEMENT_CONSTRAINTS` |
| certs-dumper | `DOKPLOY_CERTS_DUMPER_DEPLOY_MODE` | `DOKPLOY_CERTS_DUMPER_DEPLOY_REPLICAS` | `DOKPLOY_CERTS_DUMPER_PLACEMENT_CONSTRAINTS` |
| waf | `DOKPLOY_WAF_DEPLOY_MODE` | `DOKPLOY_WAF_DEPLOY_REPLICAS` | `DOKPLOY_WAF_PLACEMENT_CONSTRAINTS` |

`mode`: `replicated` (default) or `global` (replicas ignored). Stateful services (postgres/redis) should stay at `replicas=1`.

Compose-only: `restart: unless-stopped` via `DOKPLOY_RESTART` / `DOKPLOY_*_RESTART` (Swarm uses `deploy.restart_policy`).

```sh
DOKPLOY_DEPLOY_MODE=replicated
DOKPLOY_DEPLOY_REPLICAS=1
DOKPLOY_PLACEMENT_CONSTRAINTS=node.role == manager
DOKPLOY_TRAEFIK_PLACEMENT_CONSTRAINTS=node.labels.ingress==true
```

Network: `DEFAULT_NETWORK_NAME` (default `dokploy-network`). `make dokploy-setup` creates that name (not a hard-coded string).

## Makefile (from repo root)

```sh
make dokploy-pull-images
make dokploy-stack-up
make dokploy-stack-upgrade
make dokploy-stack-down
make dokploy-stack-logs
make dokploy-debug          # inspects dokploy_traefik ports
make dokploy-debug-logs
make dokploy-compose-up
make dokploy-compose-down
```

## Traefik

### Static vs CLI

| Layer | Where | Role |
|-------|--------|------|
| Static | [`etc/traefik/traefik.yml`](../etc/traefik/traefik.yml) via Swarm config → `/etc/traefik/traefik.yml` | entryPoints addresses/timeouts, file provider, ACME storage, access-log fields, plugins |
| CLI | `command:` in compose | `api.basePath`, providers, ACME email, log level, **entrypoint middlewares**, **forwardedHeaders**, `DOKPLOY_TRAEFIK_COMMAND` |
| Dynamic | [`etc/traefik/rules/`](../etc/traefik/rules/) | middlewares (file provider) |

After editing `traefik.yml`, bump `DOKPLOY_TRAEFIK_STATIC_CONFIG_NAME` and redeploy (Swarm configs are immutable).

### Global WAF middleware

| Source | Reference |
|--------|-----------|
| Traefik service labels (swarm + docker) | `waf` / `waf@swarm` / `waf@docker` |
| [`etc/traefik/rules/middlewares.yml`](../etc/traefik/rules/middlewares.yml) | `waf@file` |

Entrypoints attach WAF for **all** HTTP(S) traffic (no per-app label required):

| Variable | Default |
|----------|---------|
| `DOKPLOY_TRAEFIK_WEB_MIDDLEWARES` | `waf` |
| `DOKPLOY_TRAEFIK_WEBSECURE_MIDDLEWARES` | `waf` |

```sh
DOKPLOY_TRAEFIK_WEB_MIDDLEWARES=waf
DOKPLOY_TRAEFIK_WEBSECURE_MIDDLEWARES=waf
# or: waf@file
DOKPLOY_WAF_MODSECURITY_URL=http://waf:8080
```

### Real client IP (logs + backends)

- Access log keeps `ClientHost` / `ClientAddr` and headers `X-Forwarded-For` / `X-Real-Ip`.
- `DOKPLOY_TRAEFIK_FORWARDED_HEADERS_TRUSTED_IPS` — when the peer is in this list, Traefik uses `X-Forwarded-*` for logs and for outbound `X-Forwarded-For` / `X-Real-Ip`.
- Edge (host ports, no LB): `ClientHost` is the TCP client; Traefik still injects that IP toward backends.
- Do **not** set `X-Forwarded-For` in `forward-https-headers` (Proto/Port only).
- WAF: `DOKPLOY_WAF_PROXY=1` + `DOKPLOY_WAF_REMOTEIP_INT_PROXY` so ModSecurity trusts Traefik’s docker/overlay IPs.

Behind Cloudflare / a public LB, put that provider’s CIDRs in `TRUSTED_IPS`. Avoid `DOKPLOY_TRAEFIK_FORWARDED_HEADERS_INSECURE=true` in production.

## WAF custom rules

Versioned under [`etc/waf/rules/`](../etc/waf/rules/). Delivered as **Swarm configs** (not host binds):

| Config | Source env | Target in container |
|--------|------------|---------------------|
| `dokploy_waf_before_crs` | `DOKPLOY_WAF_BEFORE_CRS_RULES` | `…/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` |
| `dokploy_waf_after_crs` | `DOKPLOY_WAF_AFTER_CRS_RULES` | `…/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf` |

Do not bind-mount the whole CRS `rules/` directory (that hides upstream rules). After editing rule files, bump `DOKPLOY_WAF_*_CRS_CONFIG_NAME` and redeploy.

## Troubleshoot

1. Permissions (Podman / SELinux example):

```sh
podman unshare bash -c '
  chown -R 999:999 /home/admin/appdata/dokploy/redis
  chown -R 999:999 /home/admin/appdata/logs/redis
  chown -R 999:999 /home/admin/appdata/logs/apache2
  chmod -R u+rwX /home/admin/appdata/logs/apache2
  chcon -R -t container_file_t -l s0 /home/admin/appdata/logs/apache2
'
podman start dokploy_waf_1
```

2. Swarm service `0/1`: `make dokploy-debug` / `dokploy-debug-logs`.
3. Image tag unchanged but digest moved: `make dokploy-stack-upgrade`.
