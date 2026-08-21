# Conventions — new application stack

Read this after [SKILL.md](SKILL.md) when generating files. Placeholders: `<projet>` = `myapp`, `<PREFIX>` = `MYAPP`.

## Compose (two files)

| File | Role |
|------|------|
| `<projet>/docker-compose.yml` | Canonical stack (Make / Swarm). With Traefik/Homepage labels when HTTP ingress is wanted |
| `<projet>/compose.yml` | Unlabeled copy **or** symlink to `docker-compose.yml` when there are no labels |

Do not emit `stack-compose.yml` unless requested.

**With labels:** keep two real files identical except labels (labels only in `docker-compose.yml`).

**Without labels** (TCP/DB, or user omits Traefik/Homepage): write only `docker-compose.yml`, then:

```sh
cd <projet> && ln -sfn docker-compose.yml compose.yml
```

Do not maintain a duplicate unlabeled file. Root symlinks still point at `<projet>/compose.yml` and `<projet>/docker-compose.yml` (the former may resolve through the inner symlink).

`compose.yml` when it is a real unlabeled file:

```yaml
networks:
  default:
    name: ${DEFAULT_NETWORK_NAME:-myapp-network}
    external: ${DEFAULT_NETWORK_EXTERNAL:-false}

volumes:
  myapp_data:
    name: ${MYAPP_DATA_VOLUME_NAME:-myapp_data}
    external: ${MYAPP_DATA_VOLUME_EXTERNAL:-false}

services:
  myapp:
    image: ${MYAPP_IMAGE:-docker.io/library/myapp:latest}
    restart: ${MYAPP_RESTART:-unless-stopped}
    privileged: ${MYAPP_PRIVILEGED:-false}
    env_file:
      - ${MYAPP_ENV_FILE:-.env.example}
    environment:
      - TZ=${TZ:-America/Toronto}
    volumes:
      - ${MYAPP_DATA_DIR:-myapp_data}:/var/lib/myapp
    deploy:
      mode: ${MYAPP_DEPLOY_MODE:-replicated}
      replicas: ${MYAPP_DEPLOY_REPLICAS:-1}
      placement:
        constraints:
          - ${MYAPP_PLACEMENT_CONSTRAINTS:-node.role==manager}
      restart_policy:
        condition: on-failure
        delay: 5s
      resources:
        limits:
          memory: ${MYAPP_MEMORY_LIMIT:-1G}
```

`docker-compose.yml` with labels = that file **plus** `deploy.labels` and service `labels` (see Traefik section). Do not leave empty `labels: []`. When there are no labels, skip that section and symlink `compose.yml` → `docker-compose.yml` instead.

## Per-service compose (multi-service stacks)

If there are **two or more** services, also emit `<role>-compose.yml` files (role = suffix after `<projet>-`, e.g. `woodpecker-server` → `server-compose.yml`).

Each file: same `networks.default`, only volumes used by that service, single service entry (including `env_file` + `environment:`). **Preserve** Traefik/Homepage labels from `docker-compose.yml` when that service has them. No root symlinks for these files.

Example layout for Woodpecker:

```
woodpecker/
  compose.yml              # full stack, no labels
  docker-compose.yml       # full stack, labels on server
  server-compose.yml       # woodpecker-server only (+ labels)
  agent-compose.yml        # woodpecker-agent only (no HTTP labels)
```

Rules:

- `docker stack deploy` **rejects nested** `${A:-${B:-x}}`. One default per key.
- Swarm ignores `restart:`; Compose ignores most of `deploy:` except labels on some engines — keep both.
- Do not set `platform:` (Swarm rejects it). Use multi-arch images.
- Do not publish app HTTP ports if Traefik is the ingress (labels only).
- Do not mount the Docker socket unless the app needs it.
- Stateful services: `replicas: 1`. `mode: global` ignores replicas.
- Do **not** emit Compose `x-*` keys (`x-pull-policy`, etc.).
- Do **not** quote interpolations for booleans: `privileged: ${MYAPP_PRIVILEGED:-false}` and `external: ${DEFAULT_NETWORK_EXTERNAL:-false}` — never `"${…}"`.
- Overlay pairing (two keys; **no nested** `${A:-${B}}`): **compose defaults** `DEFAULT_NETWORK_NAME` → `<projet>-network` (e.g. `myapp-network`) and `DEFAULT_NETWORK_EXTERNAL` → `false` (stack-local network Swarm/Compose can create). If NAME is **`dokploy-network`**, EXTERNAL must be `true` (join the existing shared overlay + Traefik). Any other NAME → EXTERNAL `false`. `<projet>-setup` upserts EXTERNAL to match NAME; when NAME is empty in env, fallback to `<projet>-network` then EXTERNAL `false`. To share Redis/DB/Traefik on Dokploy: set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true` in `.env`.
- **Memory limit:** every service must set `deploy.resources.limits.memory` to `${<PREFIX>_MEMORY_LIMIT:-1G}` or a per-role `${<PREFIX>_<ROLE>_MEMORY_LIMIT:-1G}`. Default is always **1G** unless the user requests otherwise. Mirror the key(s) in `.env.example`.
- Pull images via Make (`<projet>-pull-images` / `*-stack-upgrade`), not `pull_policy` / `x-pull-policy` (Swarm rejects `pull_policy`).
- Do **not** add `networks.default.aliases` by default. The Compose service name is already the DNS name. Add aliases **only** when the user asks, or when a stable alternate hostname is required (Dokploy-style: e.g. `dokploy-postgresql`, `dokploy-redis` for other services to resolve).
- Do **not** add `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` to service `environment:` unless the user explicitly wants proxy passthrough (root `.env` may still define them for other tools).
- Prefer Compose **`env_file` + `environment:`** together (see § Env file). Do not use Swarm `configs:` as a substitute for dotenv injection.

## Env file (`env_file` + `environment`)

Always declare both on app services (and on each `<role>-compose.yml` service):

```yaml
services:
  myapp:
    env_file:
      - ${MYAPP_ENV_FILE:-.env.example}
    environment:
      - TZ=${TZ:-America/Toronto}
      - APP_URL=${MYAPP_APP_URL:-http://myapp.example.com/myapp}
```

Multi-role example:

```yaml
# server-compose.yml
env_file:
  - ${WOODPECKER_SERVER_ENV_FILE:-.env.example}
# agent-compose.yml
env_file:
  - ${WOODPECKER_AGENT_ENV_FILE:-.env.example}
```

| Rule | Detail |
|------|--------|
| Override order | `environment:` overrides keys from `env_file` |
| Path | Relative to `<projet>/` |
| Default | `.env.example` in scaffold; prod → `.env` via `*_ENV_FILE=.env` |
| Swarm | `stack deploy` does not reliably apply `env_file` — Make exports root `.env` and compose `environment:` `${VAR}` interpolation |
| Not `configs:` | Swarm configs mount a file; they do not parse dotenv into process env |

## Env

Prefix every project key with `<PREFIX>_`. Root Make `-include`s `.env` and **exports** keys — required for Swarm.

Typical keys:

```
DEFAULT_NETWORK_NAME=myapp-network
DEFAULT_NETWORK_EXTERNAL=false
MYAPP_IMAGE=
MYAPP_RESTART=unless-stopped
MYAPP_PRIVILEGED=false
MYAPP_MEMORY_LIMIT=1G
MYAPP_DOMAIN=myapp.example.com
MYAPP_BASE_PATH=/myapp
MYAPP_APP_URL=http://myapp.example.com/myapp
MYAPP_TRAEFIK_LABELS_SWARM_ENABLE=true
MYAPP_TRAEFIK_LABELS_DOCKER_ENABLE=true
MYAPP_ENTRYPOINTS=web
MYAPP_MIDDLEWARES=
MYAPP_TLS_ENABLED=false
MYAPP_TLS_CERTRESOLVER=letsencrypt
MYAPP_DEPLOY_MODE=replicated
MYAPP_DEPLOY_REPLICAS=1
MYAPP_PLACEMENT_CONSTRAINTS=node.role==manager
MYAPP_DATA_DIR=
MYAPP_DATA_VOLUME_NAME=myapp_data
MYAPP_DATA_VOLUME_EXTERNAL=false
MYAPP_HOMEPAGE_GROUP=
MYAPP_HOMEPAGE_NAME=Myapp
MYAPP_HOMEPAGE_ICON=myapp.png
MYAPP_HOMEPAGE_HREF=http://myapp.example.com/myapp
# Compose env_file (path relative to <projet>/). environment: overrides the file.
MYAPP_ENV_FILE=.env.example
```

- Always define `<PREFIX>_BASE_PATH`. If the app **supports** subpath (step 1b), default to `/<projet>` and align public URL vars; if not, default `/`. See § Base path.
- Bind vs named volume: empty `MYAPP_DATA_DIR` → named volume default in compose.
- Sync the same keys into **root** `.env.example` and `<projet>/.env.example`.
- GNU Make treats `$` in `.env` as Make syntax; prefer plain values. Compose hashes need `$$`.
- Never commit `.env` (gitignored via `**/.*` except `*.example`).

## Base path

Traefik always has `<PREFIX>_BASE_PATH` in the **labeled** file (`PathPrefix` + `homepage.href`). That alone is **not** enough for subpath deploy.

**Verify in the app docs** whether the process can generate URLs / assets under a path prefix.

| App supports subpath? | Config |
|-----------------------|--------|
| Yes | **Default** `<PREFIX>_BASE_PATH=/<projet>` in `.env.example` only. In compose Traefik labels use `PathPrefix(\`${<PREFIX>_BASE_PATH:-/}\`)` so **empty or unset becomes `/` (Host-only)** — never `${…:-/<projet>}` (that re-fills an intentional empty). Align public URL vars to the chosen path. Map vendor env when documented. Always allow `/` or empty for a dedicated subdomain even when the app supports subpath. |
| No / unknown | Keep `<PREFIX>_BASE_PATH=/`. Prefer subdomain (`Host` only). Do not invent vendor env vars. Do not add `stripPrefix` unless the user explicitly requests it. |

Example when the app supports a path (Woodpecker-style `HOST` includes the path):

```env
MYAPP_DOMAIN=myapp.example.com
MYAPP_BASE_PATH=/myapp
MYAPP_APP_URL=http://myapp.example.com/myapp
```

```yaml
environment:
  - TZ=${TZ:-America/Toronto}
  - APP_URL=${MYAPP_APP_URL:-http://myapp.example.com/myapp}
  # Vendor path: ${VAR:-} keeps empty; do not use ${VAR:-/subpath} or bare ${VAR-}
  - BASE_HREF=${MYAPP_BASE_HREF:-}
```

Traefik (labeled file):

```yaml
- "traefik.http.routers.${APP_NAME:-myapp}.rule=Host(`${MYAPP_DOMAIN:-myapp.example.com}`) && PathPrefix(`${MYAPP_BASE_PATH:-/}`)"
```

Trailing slash: follow the vendor. If unspecified, use `/myapp` (no trailing slash on the path segment) and include that path in the public URL default.

## Root symlinks

On the stack branch, after `<projet>/README.md`, `compose.yml`, and `docker-compose.yml` exist, create relative symlinks at the **repo root**:

```sh
ln -sfn <projet>/README.md README.md
ln -sfn <projet>/compose.yml compose.yml
ln -sfn <projet>/docker-compose.yml docker-compose.yml
```

| Root entry | Points to |
|------------|-----------|
| `README.md` | `<projet>/README.md` |
| `compose.yml` | `<projet>/compose.yml` |
| `docker-compose.yml` | `<projet>/docker-compose.yml` |

Do **not** symlink `.env.example` or `Makefile` to the project (root keeps Make/`bin` layout). Do not replace an existing regular root file without asking. Commit the three symlinks with the stack.

## Makefile

`<projet>/Makefile` (from `_trash/template/Makefile`, gitignored scaffold):

```make
## —— 🐝 Myapp commands ———————————————————————————————————
MYAPP_STACK_NAME := myapp
MYAPP_SERVICES_SHORT := myapp
myapp-pull-images: ## Pull images for the myapp stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(MYAPP_STACK_NAME)
myapp-setup: ## Ensure <projet>/.env, generate missing secrets, sync DEFAULT_NETWORK_EXTERNAL (true only for dokploy-network)
	@echo "Setting up the myapp stack..."
.myapp-setup: myapp-setup
myapp-stack-up: .myapp-setup ## Deploy the myapp stack
	$(MAKE) stack-deploy STACK_NAME=$(MYAPP_STACK_NAME)
myapp-stack-down: ## Remove the myapp stack
	$(MAKE) stack-rm STACK_NAME=$(MYAPP_STACK_NAME)
myapp-stack-recreate: myapp-stack-down myapp-stack-up ## Recreate the myapp stack
myapp-stack-upgrade: ## Upgrade myapp swarm images
	$(MAKE) docker-pull-images PROJECT_NAME=$(MYAPP_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(MYAPP_STACK_NAME)
myapp-stack-logs: ## Show logs of the myapp stack
	$(MAKE) stack-logs STACK_NAME=$(MYAPP_STACK_NAME)
myapp-debug: ## Debug myapp swarm stack
	@echo "--- docker stack services ($(MYAPP_STACK_NAME))"
	@$(DOCKER) stack services $(MYAPP_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@$(DOCKER) stack ps $(MYAPP_STACK_NAME) --no-trunc
myapp-debug-logs: ## Tail recent logs for each myapp service
	@for s in $(MYAPP_SERVICES_SHORT); do \
		echo "==================== $(MYAPP_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(MYAPP_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
myapp-compose-up: .myapp-setup ## Deploy the myapp stack
	$(MAKE) docker-project-up PROJECT_NAME=$(MYAPP_STACK_NAME)
myapp-compose-down: ## Remove the myapp stack
	$(MAKE) docker-project-down PROJECT_NAME=$(MYAPP_STACK_NAME)
myapp-compose-restart: ## Restart the myapp stack
	$(MAKE) docker-project-restart PROJECT_NAME=$(MYAPP_STACK_NAME)
myapp-compose-recreate: myapp-compose-down myapp-compose-up ## Recreate the myapp stack
myapp-compose-logs: ## Show logs of the myapp stack
	$(MAKE) docker-project-logs PROJECT_NAME=$(MYAPP_STACK_NAME)
myapp-compose-watch-logs: ## Watch logs of the myapp stack
	$(MAKE) docker-project-watch PROJECT_NAME=$(MYAPP_STACK_NAME)
```

Naming: use **`<projet>-setup`** (e.g. `woodpecker-setup`), **not** `<projet>-stack-setup`. Keep `*-stack-*` only for Swarm deploy/rm/logs/upgrade.

Root `Makefile` (once):

```make
-include myapp/Makefile
```

If `stack-upgrade` is missing on the current branch, implement pull + `stack-deploy` as above.

`MYAPP_SERVICES_SHORT` = compose **service names** (Swarm name is `<stack>_<service>`).

## Traefik + Homepage labels

Duplicate the block on `deploy.labels` (Swarm provider) and service `labels` (Docker provider). Use list form `"key=value"`. Gate each with its own enable var:

- Swarm: `traefik.enable=${MYAPP_TRAEFIK_LABELS_SWARM_ENABLE:-true}` under `deploy.labels`
- Compose: `traefik.enable=${MYAPP_TRAEFIK_LABELS_DOCKER_ENABLE:-true}` under service `labels`

```yaml
# deploy.labels (Swarm)
- "traefik.enable=${MYAPP_TRAEFIK_LABELS_SWARM_ENABLE:-true}"
# service labels (Compose) — same keys, but:
- "traefik.enable=${MYAPP_TRAEFIK_LABELS_DOCKER_ENABLE:-true}"
- "traefik.http.services.myapp.loadbalancer.server.port=8080"
- "traefik.http.routers.myapp.entrypoints=${MYAPP_ENTRYPOINTS:-web}"
- "traefik.http.routers.myapp.rule=Host(`${MYAPP_DOMAIN:-myapp.example.com}`) && PathPrefix(`${MYAPP_BASE_PATH:-/}`)"
- "traefik.http.routers.myapp.service=myapp"
- "traefik.http.routers.myapp.middlewares=${MYAPP_MIDDLEWARES:-}"
- "traefik.http.routers.myapp.tls=${MYAPP_TLS_ENABLED:-false}"
- "traefik.http.routers.myapp.tls.certresolver=${MYAPP_TLS_CERTRESOLVER:-letsencrypt}"
- "homepage.group=${MYAPP_HOMEPAGE_GROUP:-}"
- "homepage.name=${MYAPP_HOMEPAGE_NAME:-Myapp}"
- "homepage.icon=${MYAPP_HOMEPAGE_ICON:-myapp.png}"
- "homepage.href=${MYAPP_APP_URL:-http://myapp.example.com/myapp}"
- "homepage.description=${MYAPP_HOMEPAGE_DESCRIPTION:-}"
```

- Port = container listen port, not the published host port.
- Do not add a second Traefik service. Default stack network is `<projet>-network` (local). For Traefik on the shared overlay, set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true`.
- Leave `MYAPP_MIDDLEWARES` empty unless the user wants extra middlewares; global WAF is on Traefik entrypoints.
- `MYAPP_BASE_PATH` drives `PathPrefix` and `homepage.href`. Wire the app’s own base-path env only when step **1b** confirmed support (see § Base path).
- Labels belong **only** in `docker-compose.yml`, never in a separate unlabeled `compose.yml`. If the stack has **no** labels, do not invent empty Traefik/Homepage blocks — symlink `compose.yml` → `docker-compose.yml` instead.

## Git — `master` before new stack

After a clean tree (SKILL step **0**), before `git checkout -b <projet>`:

```sh
git fetch origin master
git checkout master
git pull --ff-only origin master
git checkout -b <projet>
```

- **FF-only** — do not merge/rebase automatically if pull fails; stop and ask the user.
- Remotes: **`origin`** first; **`l2dw`** fallback if `origin` is unreachable (same as push).
- One stack ≈ one branch from **updated** `master`, not from another app branch or stale local `master`.

## Git — skill on `master` when pushing

Skill edits under `.cursor/skills/create-docker-stack/` are **not** stack-scoped. After pushing branch `<projet>` (when the user asked), mirror skill commits onto `master`:

```sh
git log --oneline master..<projet> -- .cursor/skills/create-docker-stack/
git checkout master && git pull --ff-only origin master
git cherry-pick <sha>    # skill commits only, oldest first
git push origin master && git push l2dw master
git checkout <projet>
```

Do **not** merge `<projet>` into `master` just for the skill — cherry-pick skill commits only. If there are no skill commits in the range, skip.

## Gitignore / local files

Do not add:

- `.env`, `.env.*` except `*.example`
- `docker-compose.override.yml` / `stack-compose.override.yml`
- `appdata/`, `certs/`, `*_trash`, `_trash/` (local scaffold; never commit)

Overrides are the supported way to pin host ports or binds locally.
