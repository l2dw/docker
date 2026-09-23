# App (generic stack template)

Generic wrapper to deploy **any image** on Swarm/Compose. Pick a compose file for Homepage-only, HTTP Traefik, or TCP Traefik.

## Files

| File | Role |
|------|------|
| `docker-compose.yml` | Homepage only (no Traefik). `compose.yml` → symlink |
| `web.docker-compose.yml` | HTTP Traefik + host publish + Homepage |
| `tcp.docker-compose.yml` | TCP Traefik + host publish + Homepage |
| `.env.example` | All `APP_*` / network keys |
| `Makefile` | `app-*`; selects compose file from `APP_TRAEFIK_MODE` |

## Usage

```sh
cp app/.env.example app/.env
# edit APP_IMAGE, APP_DOMAIN, APP_BASE_PATH, …
make app-setup
make app-stack-up
```

Dokploy: set the compose path to `web.docker-compose.yml` or `tcp.docker-compose.yml` (not the Homepage-only file) when you need Traefik.

## Traefik

| Mode (`APP_TRAEFIK_MODE`) | Compose file | Rule |
|---------------------------|--------------|------|
| `http` (default) | `web.docker-compose.yml` | `Host(\`$APP_DOMAIN\`) && PathPrefix(\`$APP_BASE_PATH\`)` |
| `tcp` | `tcp.docker-compose.yml` | `HostSNI(\`*\`)` (hardcoded) |
| other / unset for Make homepage | `docker-compose.yml` | none |

No `APP_TRAEFIK_RULE` — set domain/path (or TCP entrypoint) only.

### Example: `https://example.com/app`

```env
APP_TRAEFIK_MODE=http
APP_DOMAIN=example.com
APP_BASE_PATH=/app
APP_TRAEFIK_ENTRYPOINTS=web
```

Dokploy compose file: `app/web.docker-compose.yml`.

If the app does not strip `/app`, add a strip-prefix middleware and set `APP_TRAEFIK_MIDDLEWARES`.

### Example: MySQL via Traefik TCP

Prefer the dedicated `mysql/` stack when possible. Generic wrapper:

```env
APP_TRAEFIK_MODE=tcp
APP_IMAGE=docker.io/library/mysql:8.0
APP_NAME=mysql
APP_TRAEFIK_SERVICE=mysql
APP_PORT=3306
APP_TRAEFIK_ENTRYPOINTS=mysql
DEFAULT_NETWORK_NAME=dokploy-network
DEFAULT_NETWORK_EXTERNAL=true
```

Dokploy compose file: `app/tcp.docker-compose.yml`. Traefik static config must define the TCP entrypoint, e.g. `mysql: ":3306"`.

## Network / volume / Homepage

- Default network `app-network`; for Dokploy use `dokploy-network` + `EXTERNAL=true`.
- NFS via `APP_DATA_VOLUME_DRIVER*`; bind via `APP_DATA_HOST_PATH`.
- Homepage: `APP_HOMEPAGE_URL` / `SITEMONITOR` / `PING` (ICMP host, not a URL).

```sh
make app-debug
make app-debug-logs
```

Do not commit `app/.env` with real secrets or production domains.
