# Xibo CMS

Digital signage CMS ([xibo-docker](https://github.com/xibosignage/xibo-docker)): web (`xibo`), XMR (`xibo-xmr`), QuickChart. **MySQL and memcached are external** (same overlay as the stack).

## Quick start

```sh
make xibo-setup
# edit xibo/.env (domain, XIBO_MYSQL_*, XIBO_MEMCACHED_HOST, SMTP) and root .env for Swarm
make xibo-compose-up   # or: make xibo-stack-up
```

Use Make for Swarm: `docker stack deploy` does not load `.env` alone.

## Base path

Supported via vendor `CMS_ALIAS`. Default `XIBO_BASE_PATH=/xibo` (aligned `XIBO_APP_URL` / `XIBO_CMS_ALIAS`). Empty or `/` is Host-only (dedicated subdomain). Do **not** add Traefik stripPrefix — the CMS serves the alias itself.

## Env / env_file

- `XIBO_ENV_FILE`, `XIBO_XMR_ENV_FILE`, `XIBO_QUICKCHART_ENV_FILE` (default `.env.example`; prod → `.env`).
- Compose merges `env_file` + `environment:`; **`environment:` wins**.
- Swarm relies on Make-exported root `.env` + compose interpolation (not Compose `env_file`).
- External MySQL: set `XIBO_MYSQL_HOST` (default `mysql`). `XIBO_MYSQL_PASSWORD` alphanumeric (~16 chars); `xibo-setup` can generate it — create the matching DB user outside this stack.
- External memcached: `XIBO_MEMCACHED_HOST` (default `memcached`), or `XIBO_CMS_USE_MEMCACHED=false` for file cache.
- `APP_NAME` (Dokploy) scopes Traefik router/service names; not listed in `.env.example`.

## Network / Traefik

Default `DEFAULT_NETWORK_NAME=xibo-network` (`EXTERNAL=false`). To reach shared MySQL/memcached/Traefik on Dokploy: `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true`.

XMR is TCP **9505** (players). This stack does not publish host ports by default — add a compose override or Traefik TCP entrypoint if players are off-network.

Full stack: `docker-compose.yml` (labels) / `compose.yml` (no labels).

## Ops

| Target | Role |
|--------|------|
| `xibo-setup` | Env, MySQL password, CMS_ALIAS, network pairing |
| `xibo-stack-up` / `xibo-compose-up` | Deploy |
| `xibo-debug` / `xibo-debug-logs` | Swarm inspect |
| `xibo-pull-images` | Pull images |
