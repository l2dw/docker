# Arcane

[Arcane](https://getarcane.app) manager (`ghcr.io/getarcaneapp/manager`) — Docker management UI. Joins the existing overlay (`dokploy-network`); does not run Traefik/WAF.

Docs: [installation](https://getarcane.app/docs/setup/installation).

`.env` is **not** read by `docker stack deploy` alone — use Make (root `.env` is exported):

```sh
# From repo root — setup creates arcane/.env and fills empty secrets
make arcane-stack-setup
make arcane-stack-up
make arcane-compose-up
```

`make arcane-stack-setup` copies `arcane/.env.example` → `arcane/.env` if needed, generates `ARCANE_ENCRYPTION_KEY` / `ARCANE_JWT_SECRET` with `openssl rand -hex 32` when empty (also upserts root `.env` so Make/Swarm see them), and **saves** `ARCANE_APP_URL` / `ARCANE_DOMAIN` when you pass them on the command line (otherwise they are lost on the next `make`). Warns if those are empty or still `*.example.com`.

```sh
make arcane-stack-setup ARCANE_DOMAIN=arcane.local ARCANE_APP_URL=http://arcane.local
make arcane-compose-up
```

Copy [`arcane/.env.example`](.env.example) keys into the root `.env`. Set `ARCANE_APP_URL` to the **exact** URL the browser uses (scheme + host, and port if not 80/443). A mismatch causes `403 Cross-origin request blocked`.

On the `arcane` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `arcane/`.

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | Manager only, no Traefik / Homepage |
| [`docker-compose.yml`](docker-compose.yml) | Manager + Traefik / Homepage — used by `make` |
| [`agent-compose.yml`](agent-compose.yml) | Edge agent only (outbound; no HTTP labels) |

## Edge agent

Run the agent on a **remote** Docker host (or another node) to manage that engine from the manager UI — [remote environments](https://getarcane.app/docs/features/environments).

1. In Arcane: Environments → Add → **Edge** → generate config / token.
2. Set `ARCANE_AGENT_TOKEN` and `ARCANE_MANAGER_API_URL` (public manager URL, usually same as `ARCANE_APP_URL`) in `arcane/.env` (or root `.env`).
3. Deploy (Compose):

```sh
docker compose -f arcane/agent-compose.yml --env-file arcane/.env up -d
# production env_file: ARCANE_AGENT_ENV_FILE=.env
```

Uses its own volume `arcane-agent-data` (not the manager’s `arcane-data`). Mounts `DOCKER_RUNTIME_SOCKET`. No Traefik ports — the agent dials out (`EDGE_AGENT=true`, `EDGE_TRANSPORT=poll` by default).

If a token was ever committed or pasted into compose: **rotate it** in the manager UI.

## Base path

**Subpath deploy is not supported** by Arcane ([#1119](https://github.com/getarcaneapp/arcane/issues/1119)). Keep `ARCANE_BASE_PATH=/` and use a **subdomain** (`ARCANE_DOMAIN` + Host-only Traefik rule). Do not set `APP_URL` to `https://example.com/arcane`.

Behind Traefik, set `ARCANE_TRUSTED_PROXIES` to the shared Docker network CIDR (default `172.16.0.0/12`) so login rate limits see the real client IP — [websocket / reverse proxy docs](https://getarcane.app/docs/configuration/websockets-reverse-proxies).

## Makefile

```sh
make arcane-pull-images
make arcane-stack-up
make arcane-stack-upgrade
make arcane-stack-down
make arcane-stack-logs
make arcane-debug
make arcane-debug-logs
make arcane-compose-up
make arcane-compose-down
make arcane-compose-restart
```

Place the service on a **Swarm manager** (`ARCANE_PLACEMENT_CONSTRAINTS=node.role==manager`) so the Docker socket is useful.

## Required env

| Variable | Notes |
|----------|--------|
| `ARCANE_ENCRYPTION_KEY` | 32 bytes (raw, base64, or hex). `openssl rand -hex 32` |
| `ARCANE_JWT_SECRET` | `openssl rand -hex 32` |
| `ARCANE_APP_URL` | Public URL (e.g. `https://arcane.example.com`) — no path prefix |
| `ARCANE_DOMAIN` | Traefik `Host()` |
| `ARCANE_BASE_PATH` | Keep `/` (subpath unsupported) |
| `ARCANE_TRUSTED_PROXIES` | Proxy CIDR for `X-Forwarded-*` (default `172.16.0.0/12`) |
| `ARCANE_TRAEFIK_LABELS_SWARM_ENABLE` | `traefik.enable` on `deploy.labels` (default `true`) |
| `ARCANE_TRAEFIK_LABELS_DOCKER_ENABLE` | `traefik.enable` on service `labels` (default `true`) |

Default admin is created on first login — change that password immediately (see upstream docs).

## Volumes

| Mount | Default | Role |
|-------|---------|------|
| Docker socket | `DOCKER_RUNTIME_SOCKET` | Required to manage the engine |
| `/app/data` | named `arcane-data` or `ARCANE_DATA_DIR` | DB + project data |
| `/builds` | `arcane-builds` / `ARCANE_BUILDS_DIR` | Build workspace |
| `/backups` | `arcane-backups` / `ARCANE_BACKUPS_DIR` | Volume backups |

To manage **existing** Compose projects, host and container paths must match (absolute). Use a local override, not this file:

```yaml
# arcane/docker-compose.override.yml (gitignored)
services:
  arcane:
    volumes:
      - /opt/docker:/opt/docker
    environment:
      - PROJECTS_DIRECTORY=/opt/docker
```

HTTP port **3552** is not published; Traefik routes it. Traefik already upgrades WebSockets.

`cgroup: host` (self-upgrade / own container ID) is **not** valid for `docker stack deploy`. Add it in a Compose-only override if needed.

Hardened Docker access: upstream [socket proxy](https://getarcane.app/docs/security/socket-proxy) — add via override (`DOCKER_HOST=tcp://…`), do not put the proxy in this stack by default.
