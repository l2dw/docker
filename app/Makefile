## —— 🐝 App commands ———————————————————————————————————
APP_STACK_NAME := app
APP_SERVICES_SHORT := app

# APP_TRAEFIK_MODE=http|tcp selects compose file (homepage-only otherwise).
define APP_RESOLVE_STACK_FILE
	mode='$(APP_TRAEFIK_MODE)'; \
	if [ -f app/.env ]; then \
		m=$$(sed -n 's/^APP_TRAEFIK_MODE=//p' app/.env | head -n 1); \
		[ -n "$$m" ] && mode=$$m; \
	fi; \
	case "$$mode" in \
		http|web) echo app/web.docker-compose.yml ;; \
		tcp)      echo app/tcp.docker-compose.yml ;; \
		*)        echo app/docker-compose.yml ;; \
	esac
endef

app-pull-images: ## Pull images for the app stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(APP_STACK_NAME)
app-setup: ## Ensure app/.env, sync DEFAULT_NETWORK_EXTERNAL (true only for dokploy-network)
	@set -e; \
	envf='app/.env'; \
	exf='app/.env.example'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; echo "Created $$envf from .env.example"; fi; \
	upsert() { \
		_f=$$1; _k=$$2; _v=$$3; \
		if [ ! -f "$$_f" ]; then printf '%s=%s\n' "$$_k" "$$_v" > "$$_f"; return; fi; \
		tmp=$$(mktemp); \
		awk -v k="$$_k" -v v="$$_v" 'BEGIN{done=0} index($$0,k"=")==1 {print k"="v; done=1; next} {print} END{if(!done) print k"="v}' "$$_f" > "$$tmp" && mv "$$tmp" "$$_f"; \
	}; \
	file_get() { \
		_f=$$1; _k=$$2; \
		[ -f "$$_f" ] || return 0; \
		sed -n "s/^$${_k}=//p" "$$_f" | head -n 1; \
	}; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='app-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	echo "DEFAULT_NETWORK_NAME=$$net -> DEFAULT_NETWORK_EXTERNAL=$$ext (app/.env only)"; \
	img=$$(file_get "$$envf" APP_IMAGE); \
	if [ -z "$$img" ]; then echo "Warning: APP_IMAGE is empty in $$envf — set the image to deploy." >&2; fi; \
	mode=$$(file_get "$$envf" APP_TRAEFIK_MODE); \
	[ -n "$$mode" ] || mode=http; \
	case "$$mode" in http|web|tcp|"") ;; *) echo "Warning: APP_TRAEFIK_MODE=$$mode (expected http|tcp)" >&2 ;; esac; \
	echo "APP_TRAEFIK_MODE=$$mode → $$($(APP_RESOLVE_STACK_FILE))"; \
	case "$$mode" in \
		http|web) \
			case "$$(file_get "$$envf" APP_DOMAIN)" in \
				*example.com*) echo "Warning: APP_DOMAIN still uses example.com — set the real value in $$envf" >&2 ;; \
			esac ;; \
		tcp) \
			ep=$$(file_get "$$envf" APP_TRAEFIK_ENTRYPOINTS); \
			case "$$ep" in web|websecure) \
				echo "Note: tcp mode — set APP_TRAEFIK_ENTRYPOINTS to a Traefik TCP entrypoint (e.g. mysql)." >&2 ;; \
			esac ;; \
	esac; \
	echo "App env OK ($$envf)."
.app-setup: app-setup
app-stack-up: .app-setup ## Deploy the app stack
	@sf=$$($(APP_RESOLVE_STACK_FILE)); echo "STACK_FILE=$$sf"; \
	$(MAKE) stack-deploy STACK_NAME=$(APP_STACK_NAME) STACK_FILE=$$sf
app-stack-down: ## Remove the app stack
	$(MAKE) stack-rm STACK_NAME=$(APP_STACK_NAME)
app-stack-recreate: app-stack-down app-stack-up ## Recreate the app stack
app-stack-upgrade: ## Upgrade app swarm images
	$(MAKE) docker-pull-images PROJECT_NAME=$(APP_STACK_NAME)
	@sf=$$($(APP_RESOLVE_STACK_FILE)); \
	$(MAKE) stack-deploy STACK_NAME=$(APP_STACK_NAME) STACK_FILE=$$sf
app-stack-logs: ## Show logs of the app stack
	$(MAKE) stack-logs STACK_NAME=$(APP_STACK_NAME)
app-stack-watch-logs: ## Watch logs of the app stack
	$(MAKE) stack-watch-logs STACK_NAME=$(APP_STACK_NAME)
app-debug: ## Debug app swarm stack
	@sf=$$($(APP_RESOLVE_STACK_FILE)); echo "STACK_FILE=$$sf"
	@echo "--- docker stack services ($(APP_STACK_NAME))"
	@$(DOCKER) stack services $(APP_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(APP_STACK_NAME))"
	@$(DOCKER) stack ps $(APP_STACK_NAME) --no-trunc
app-debug-logs: ## Tail recent logs for each app service
	@for s in $(APP_SERVICES_SHORT); do \
		echo "==================== $(APP_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(APP_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
app-compose-up: .app-setup ## Deploy the app stack (compose)
	@sf=$$($(APP_RESOLVE_STACK_FILE)); echo "DOCKER_COMPOSE_FILE=$$sf"; \
	$(MAKE) docker-project-up PROJECT_NAME=$(APP_STACK_NAME) DOCKER_COMPOSE_FILE=$$sf
app-compose-down: ## Remove the app stack (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(APP_STACK_NAME)
app-compose-restart: ## Restart the app stack (compose)
	@sf=$$($(APP_RESOLVE_STACK_FILE)); \
	$(MAKE) docker-project-restart PROJECT_NAME=$(APP_STACK_NAME) DOCKER_COMPOSE_FILE=$$sf
app-compose-recreate: app-compose-down app-compose-up ## Recreate the app stack (compose)
app-compose-upgrade: ## Upgrade the app compose project
	$(MAKE) docker-pull-images PROJECT_NAME=$(APP_STACK_NAME)
	@sf=$$($(APP_RESOLVE_STACK_FILE)); \
	$(MAKE) docker-project-down PROJECT_NAME=$(APP_STACK_NAME); \
	$(MAKE) docker-project-up PROJECT_NAME=$(APP_STACK_NAME) DOCKER_COMPOSE_FILE=$$sf
app-compose-logs: ## Show logs of the app stack (compose)
	$(MAKE) docker-project-logs PROJECT_NAME=$(APP_STACK_NAME)
app-compose-watch-logs: ## Watch logs of the app stack (compose)
	$(MAKE) docker-project-watch PROJECT_NAME=$(APP_STACK_NAME)
