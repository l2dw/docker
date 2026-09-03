## —— 🐝 App commands ———————————————————————————————————
APP_STACK_NAME := app
APP_SERVICES_SHORT := app
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
	case "$$(file_get "$$envf" APP_DOMAIN)" in \
		*example.com*) echo "Warning: APP_DOMAIN still uses example.com — set the real value in $$envf" >&2 ;; \
	esac; \
	echo "App env OK ($$envf)."
.app-setup: app-setup
app-stack-up: .app-setup ## Deploy the app stack
	$(MAKE) stack-deploy STACK_NAME=$(APP_STACK_NAME)
app-stack-down: ## Remove the app stack
	$(MAKE) stack-rm STACK_NAME=$(APP_STACK_NAME)
app-stack-recreate: app-stack-down app-stack-up ## Recreate the app stack
app-stack-upgrade: ## Upgrade app swarm images
	$(MAKE) docker-pull-images PROJECT_NAME=$(APP_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(APP_STACK_NAME)
app-stack-logs: ## Show logs of the app stack
	$(MAKE) stack-logs STACK_NAME=$(APP_STACK_NAME)
app-stack-watch-logs: ## Watch logs of the app stack
	$(MAKE) stack-watch-logs STACK_NAME=$(APP_STACK_NAME)
app-debug: ## Debug app swarm stack
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
	$(MAKE) docker-project-up PROJECT_NAME=$(APP_STACK_NAME)
app-compose-down: ## Remove the app stack (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(APP_STACK_NAME)
app-compose-restart: ## Restart the app stack (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(APP_STACK_NAME)
app-compose-recreate: app-compose-down app-compose-up ## Recreate the app stack (compose)
app-compose-upgrade: ## Upgrade the app compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(APP_STACK_NAME)
app-compose-logs: ## Show logs of the app stack (compose)
	$(MAKE) docker-project-logs PROJECT_NAME=$(APP_STACK_NAME)
app-compose-watch-logs: ## Watch logs of the app stack (compose)
	$(MAKE) docker-project-watch PROJECT_NAME=$(APP_STACK_NAME)
