# Conventions — new application stack

Read this after [SKILL.md](SKILL.md) when generating files. Placeholders: `<projet>` = `myapp`, `<PREFIX>` = `MYAPP`.

## Compose (two files)

| File | Role |
|------|------|
| `<projet>/compose.yml` | Same stack, **no** Traefik/Homepage `labels` / `deploy.labels` |
| `<projet>/docker-compose.yml` | Same stack **plus** labels (Make / Swarm default) |

Do not emit `stack-compose.yml` unless requested. Keep the two files identical except labels.

`compose.yml` (no labels):

```yaml
networks:
  default:
    name: ${DEFAULT_NETWORK_NAME:-dokploy-network}
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
    environment:
      - TZ=${TZ:-America/Toronto}
    volumes:
      - ${MYAPP_DATA_DIR:-myapp_data}:/var/lib/myapp
    networks:
      default:
        aliases:
          - myapp
    deploy:
      mode: ${MYAPP_DEPLOY_MODE:-replicated}
      replicas: ${MYAPP_DEPLOY_REPLICAS:-1}
      placement:
        constraints:
          - ${MYAPP_PLACEMENT_CONSTRAINTS:-node.role==manager}
      restart_policy:
        condition: on-failure
        delay: 5s
```

`docker-compose.yml` = that file **plus** `deploy.labels` and service `labels` (see Traefik section). Do not leave empty `labels: []`.

Rules:

- `docker stack deploy` **rejects nested** `${A:-${B:-x}}`. One default per key.
- Swarm ignores `restart:`; Compose ignores most of `deploy:` except labels on some engines — keep both.
- Do not set `platform:` (Swarm rejects it). Use multi-arch images.
- Do not publish app HTTP ports if Traefik is the ingress (labels only).
- Do not mount the Docker socket unless the app needs it.
- Stateful services: `replicas: 1`. `mode: global` ignores replicas.
- Do **not** emit Compose `x-*` keys (`x-pull-policy`, etc.).
- Do **not** quote interpolations for booleans: `privileged: ${MYAPP_PRIVILEGED:-false}` and `external: ${DEFAULT_NETWORK_EXTERNAL:-false}` — never `"${…}"`.
- Pull images via Make (`<projet>-pull-images` / `*-stack-upgrade`), not `pull_policy` / `x-pull-policy` (Swarm rejects `pull_policy`).

## Env

Prefix every project key with `<PREFIX>_`. Root Make `-include`s `.env` and **exports** keys — required for Swarm.

Typical keys:

```
DEFAULT_NETWORK_NAME=dokploy-network
DEFAULT_NETWORK_EXTERNAL=false
MYAPP_IMAGE=
MYAPP_RESTART=unless-stopped
MYAPP_PRIVILEGED=false
MYAPP_DOMAIN=myapp.example.com
MYAPP_BASE_PATH=/
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
MYAPP_HOMEPAGE_HREF=http://myapp.example.com
```

- Bind vs named volume: empty `MYAPP_DATA_DIR` → named volume default in compose.
- Sync the same keys into **root** `.env.example` and `<projet>/.env.example`.
- GNU Make treats `$` in `.env` as Make syntax; prefer plain values. Compose hashes need `$$`.
- Never commit `.env` (gitignored via `**/.*` except `*.example`).

## Makefile

`<projet>/Makefile` (from branch `dictfp`, `dictfp/Makefile`):

```make
## —— 🐝 Myapp commands ———————————————————————————————————
MYAPP_STACK_NAME := myapp
MYAPP_SERVICES_SHORT := myapp
myapp-pull-images: ## Pull images for the myapp stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(MYAPP_STACK_NAME)
myapp-stack-setup: ## Ensure <projet>/.env, generate missing secrets, warn on required empties
	@echo "Setting up the myapp stack..."
.myapp-stack-setup: myapp-stack-setup
myapp-stack-up: .myapp-stack-setup ## Deploy the myapp stack
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
myapp-compose-up: ## Deploy the myapp stack
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
- "homepage.href=http://${MYAPP_DOMAIN:-myapp.example.com}${MYAPP_BASE_PATH:-/}"
- "homepage.description=${MYAPP_HOMEPAGE_DESCRIPTION:-}"
```

- Port = container listen port, not the published host port.
- Do not add a second Traefik service. Apps use `DEFAULT_NETWORK_NAME` (usually `dokploy-network`).
- Leave `MYAPP_MIDDLEWARES` empty unless the user wants extra middlewares; global WAF is on Traefik entrypoints.
Labels belong **only** in `docker-compose.yml`, never in `compose.yml`.

## Gitignore / local files

Do not add:

- `.env`, `.env.*` except `*.example`
- `docker-compose.override.yml` / `stack-compose.override.yml`
- `appdata/`, `certs/`, `*_trash`

Overrides are the supported way to pin host ports or binds locally.
