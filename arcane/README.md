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

`make arcane-stack-setup` copies `arcane/.env.example` → `arcane/.env` if needed, generates `ARCANE_ENCRYPTION_KEY` / `ARCANE_JWT_SECRET` with `openssl rand -hex 32` when empty (also upserts root `.env` so Make/Swarm see them), and warns if `ARCANE_APP_URL` / `ARCANE_DOMAIN` are empty or still `*.example.com`.

Copy [`arcane/.env.example`](.env.example) keys into the root `.env`. Set `ARCANE_APP_URL` to the **exact** URL the browser uses (scheme + host, and port if not 80/443). A mismatch causes `403 Cross-origin request blocked`.

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | None (no Traefik / Homepage) |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage — used by `make` |

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
| `ARCANE_APP_URL` | Public URL (e.g. `https://arcane.example.com`) |
| `ARCANE_DOMAIN` | Traefik `Host()` |
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
