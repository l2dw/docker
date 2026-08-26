# Portainer CE

Docker Swarm / Compose stack for [Portainer CE](https://docs.portainer.io/). The **Portainer Agent** lives in a separate compose file (`agent-compose.yml`), not in the main stack.

## Quick start

```sh
make portainer-setup
make portainer-stack-up      # Swarm (server only)
# or
make portainer-compose-up    # Compose (server only)
```

Set real values in `portainer/.env` (created from `.env.example`). Mirror keys also live in the root `.env.example` for Make/`stack deploy` export.

For Traefik on the shared Dokploy overlay: set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true` in `portainer/.env` (`portainer-setup` syncs EXTERNAL from NAME).

## Services

| Compose service | Role | File |
|-----------------|------|------|
| `portainer` | CE UI (HTTP 9000 via Traefik) | `docker-compose.yml` / `compose.yml` / `portainer-compose.yml` |
| `portainer-agent` | Global agent (Docker sock + volumes) | `agent-compose.yml` only |

Main stack uses the local Docker socket (`DOCKER_RUNTIME_SOCKET`). Add other environments later via the Portainer UI (Agent / Edge Agent).

## Environment variables

Types below are conceptual (Compose interpolates everything as strings). Booleans must be unquoted `true`/`false` in compose.

### Shared (root + project)

| Variable | Type | Default | Values / notes |
|----------|------|---------|----------------|
| `DEFAULT_NETWORK_NAME` | string | `portainer-network` | Stack overlay name. Use `dokploy-network` to join Traefik’s shared network |
| `DEFAULT_NETWORK_EXTERNAL` | bool | `false` | `true` **only** if NAME is `dokploy-network`; else `false` (`portainer-setup` syncs this) |
| `DOCKER_RUNTIME_SOCKET` | path | `/var/run/docker.sock` | Host Docker/Podman socket bind (no `unix://` prefix for volume mounts). Podman example: `/run/user/501/podman/podman.sock` |
| `DOCKER_VOLUMES_PATH` | path | `/var/lib/docker/volumes` | Host Docker volumes dir (agent only) |
| `TZ` | string | `America/Toronto` (compose) / `America/Montreal` (root example) | Container timezone |

### Portainer server

| Variable | Type | Default | Values / notes |
|----------|------|---------|----------------|
| `PORTAINER_IMAGE` | image ref | `docker.io/portainer/portainer-ce:lts` | Full image reference |
| `PORTAINER_RESTART` | string | `unless-stopped` | Compose restart policy (Swarm ignores; uses `deploy.restart_policy`) |
| `PORTAINER_PRIVILEGED` | bool | `false` | `true` \| `false` |
| `PORTAINER_ENV_FILE` | path | `.env.example` | Relative to `portainer/`; prod → `.env` |
| `PORTAINER_MEMORY_LIMIT` | memory | `1G` | Swarm/Compose `deploy.resources.limits.memory` (e.g. `512M`, `1G`) |
| `PORTAINER_PORT` | int | `9000` | Container listen port for Traefik loadbalancer (not a host publish) |
| `PORTAINER_DATA_DIR` | path or empty | empty | Empty → named volume `portainer_data`; else host bind path |
| `PORTAINER_DATA_VOLUME_NAME` | string | `portainer_data` | Named volume name when `PORTAINER_DATA_DIR` is empty |
| `PORTAINER_DATA_VOLUME_EXTERNAL` | bool | `false` | `true` \| `false` |
| `PORTAINER_DOMAIN` | hostname | `portainer.example.com` | Traefik `Host()` |
| `PORTAINER_BASE_PATH` | path | `/portainer` | `/portainer` or `/` (Host-only). Drives `--base-url` + PathPrefix |
| `PORTAINER_APP_URL` | URL | `http://portainer.example.com/portainer` | Public URL (Homepage `href`) |
| `PORTAINER_TRUSTED_ORIGINS` | CSV hosts | `portainer.example.com` | Hostnames only (no scheme), for `--trusted-origins` |
| `PORTAINER_TRAEFIK_LABELS_SWARM_ENABLE` | bool | `true` | Gate `deploy.labels` Traefik |
| `PORTAINER_TRAEFIK_LABELS_DOCKER_ENABLE` | bool | `true` | Gate service `labels` Traefik |
| `PORTAINER_ENTRYPOINTS` | string | `web` | Traefik entrypoint name(s) |
| `PORTAINER_MIDDLEWARES` | string | `portainer-strip` | Traefik middleware list. Clear when `BASE_PATH=/`. If Dokploy sets `APP_NAME`, use `<APP_NAME>-strip` |
| `PORTAINER_TLS_ENABLED` | bool | `false` | Traefik router TLS |
| `PORTAINER_TLS_CERTRESOLVER` | string | `letsencrypt` | Traefik cert resolver name |
| `PORTAINER_DEPLOY_MODE` | enum | `replicated` | `replicated` \| `global` |
| `PORTAINER_DEPLOY_REPLICAS` | int | `1` | Used when `replicated` |
| `PORTAINER_PLACEMENT_CONSTRAINTS` | string | `node.role==manager` | Swarm placement constraint |
| `PORTAINER_HOMEPAGE_*` | string | see `.env.example` | Homepage labels (`GROUP`, `NAME`, `ICON`, `HREF`, `DESCRIPTION`, `SITEMONITOR`) |

`APP_NAME` is **not** listed in `.env.example` (Dokploy / host may set it). Traefik router/service names default to `portainer`.

### Portainer Agent (`agent-compose.yml` only)

| Variable | Type | Default | Values / notes |
|----------|------|---------|----------------|
| `PORTAINER_AGENT_IMAGE` | image ref | `docker.io/portainer/agent:lts` | Full image reference |
| `PORTAINER_AGENT_RESTART` | string | `unless-stopped` | Compose restart policy |
| `PORTAINER_AGENT_PRIVILEGED` | bool | `false` | `true` \| `false` |
| `PORTAINER_AGENT_ENV_FILE` | path | `.env.example` | Relative to `portainer/` |
| `PORTAINER_AGENT_MEMORY_LIMIT` | memory | `1G` | e.g. `512M`, `1G` |
| `PORTAINER_AGENT_SECRET` | secret string | empty | Maps to `AGENT_SECRET`; set when TCP 9001 is reachable outside a trusted overlay |
| `PORTAINER_AGENT_PUBLISHED_PORT` | int | `9001` | Host port published to agent **target** `9001` (target is fixed in compose) |
| `PORTAINER_AGENT_PORT_MODE` | enum | `ingress` | Swarm publish mode — see below |
| `PORTAINER_AGENT_DEPLOY_MODE` | enum | `replicated` | `replicated` \| `global` (one task per node) |
| `PORTAINER_AGENT_DEPLOY_REPLICAS` | int | `1` | Used when `replicated` (ignored if `global`) |
| `PORTAINER_AGENT_PLACEMENT_CONSTRAINTS` | string | `node.platform.os==linux` | Swarm placement constraint |

#### `PORTAINER_AGENT_PORT_MODE`

Compose long-syntax `ports[].mode` ([Docker docs](https://docs.docker.com/reference/compose-file/services/#ports)):

| Value | Type | Meaning |
|-------|------|---------|
| `ingress` | enum (default here) | Swarm **routing mesh**: any node accepts the published port and load-balances to a task |
| `host` | enum | Bind published port on each **node that runs a task** (no ingress mesh). Use when Portainer must hit the node’s own agent directly |

Agent `ports` in compose:

```yaml
ports:
  - target: 9001                                          # fixed (container Agent API)
    published: ${PORTAINER_AGENT_PUBLISHED_PORT:-9001}  # host port (int)
    protocol: tcp                                       # tcp | udp (fixed tcp here)
    mode: ${PORTAINER_AGENT_PORT_MODE:-ingress}         # ingress | host
```

## Portainer Agent and HTTP

Yes — the **standard Agent** exposes an **Agent API** on **TCP port 9001** (HTTP API, typically over TLS). It is **not** a browser UI.

| Topic | Detail |
|-------|--------|
| Protocol | TCP **9001** — Portainer Server connects here (`https://<host>:9001` style Agent endpoint in the UI) |
| Publish | For a **remote** Portainer Server, publish host port 9001 (default `PORTAINER_AGENT_PORT_MODE=ingress`; set `host` for per-node bind) |
| Same overlay | If agent and server share a private overlay, you can omit the `ports:` block |
| Secret | Set `PORTAINER_AGENT_SECRET` when 9001 is reachable beyond a trusted network |
| Traefik | **Do not** put Traefik/Homepage labels on the agent — reverse-proxying 9001 as a normal HTTP website is unsupported/unsafe; expose TCP (firewall + secret) instead |
| Edge Agent | Different model: agent dials out to Portainer (tunnel **8000**); no need to expose 9001 on the environment |

Deploy agent only:

```sh
docker stack deploy -c portainer/agent-compose.yml portainer-agent
# or
docker compose -f portainer/agent-compose.yml --env-file portainer/.env up -d
```

Then in Portainer UI: **Environments → Add environment → Agent**, point at `https://<node-ip>:9001` (and the shared secret if set).

## Base path

Portainer supports a subpath via `--base-url` **and** Traefik `stripPrefix` (required by upstream docs).

- Default: `PORTAINER_BASE_PATH=/portainer` with `PORTAINER_MIDDLEWARES=portainer-strip`
- Host-only subdomain: set `PORTAINER_BASE_PATH=/` (setup clears middlewares)
- If Dokploy sets `APP_NAME`, set `PORTAINER_MIDDLEWARES=<APP_NAME>-strip` to match the label middleware name

## Env file wiring

Each service uses `env_file` (`PORTAINER_ENV_FILE` / `PORTAINER_AGENT_ENV_FILE`, default `.env.example`) plus an explicit `environment:` list (`environment:` wins on conflicts).

`docker stack deploy` does not reliably apply Compose `env_file` — use `make portainer-stack-*` so the root `.env` is exported and compose `${VAR}` interpolation works.

## Ops

```sh
make portainer-pull-images
make portainer-stack-upgrade
make portainer-debug
make portainer-debug-logs
```

Validate:

```sh
docker compose -f portainer/compose.yml --env-file portainer/.env.example config
docker compose -f portainer/agent-compose.yml --env-file portainer/.env.example config
```
