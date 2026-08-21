# Wallos

[Wallos](https://github.com/ellite/Wallos) personal subscription tracker — image `bellamy/wallos:5.4.2` (HTTP **80**). SQLite lives under `/var/www/html/db`; logos under `/var/www/html/images/uploads/logos`.

Default overlay is **`wallos-network`** (`DEFAULT_NETWORK_EXTERNAL=false`). To reach Traefik on a shared overlay, set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true`.

Docs: [installation](https://github.com/ellite/Wallos#installation), [OIDC](https://github.com/ellite/Wallos#oidc), [Docker Hub](https://hub.docker.com/r/bellamy/wallos).

`.env` is **not** read by `docker stack deploy` alone — use Make (root `.env` is exported). Compose `env_file` loads `${WALLOS_ENV_FILE:-.env.example}`; `environment:` wins on conflicts. Production: `WALLOS_ENV_FILE=.env`.

```sh
make wallos-setup \
  WALLOS_DOMAIN=wallos.example.com \
  WALLOS_APP_URL=https://wallos.example.com
make wallos-stack-up
# or
make wallos-compose-up
```

On the `wallos` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `wallos/`.

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | None (no Traefik / Homepage) |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage — used by `make` |

## Base path

**Not supported.** Wallos expects to be served at `/`. Keep `WALLOS_BASE_PATH=/` on a dedicated subdomain (Host-only). Do not rely on Traefik `stripPrefix` for a subpath — the UI will break. `wallos-setup` warns if `BASE_PATH` is not `/`.

## Makefile

```sh
make wallos-setup
make wallos-pull-images
make wallos-stack-up
make wallos-stack-upgrade
make wallos-stack-down
make wallos-stack-logs
make wallos-debug
make wallos-debug-logs
make wallos-compose-up
make wallos-compose-down
make wallos-compose-restart
```

Setup warns on `example.com`, forces Host-only `BASE_PATH=/` messaging, and syncs `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`).

## Required env

| Variable | Notes |
|----------|--------|
| `WALLOS_DOMAIN` | Traefik `Host()` |
| `WALLOS_APP_URL` | Public URL (no path suffix) |
| `WALLOS_BASE_PATH` | Must stay `/` |
| `WALLOS_MEMORY_LIMIT` | Default `1G` |
| `WALLOS_ENV_FILE` | Compose dotenv (default `.env.example`; use `.env` in production) |
| `DEFAULT_NETWORK_NAME` / `DEFAULT_NETWORK_EXTERNAL` | Default `wallos-network` / `false` |

Optional `WALLOS_OIDC_*` / `WALLOS_SSRF_ALLOWLIST` map to vendor OIDC env (see upstream README). First boot creates an admin user in the UI.

HTTP **80** is not published; Traefik routes it.
