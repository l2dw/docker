## —— 🐝 Memcached commands ———————————————————————————————————
MEMCACHED_STACK_NAME := memcached
MEMCACHED_SERVICES_SHORT := memcached
MEMCACHED_ENV := $(MEMCACHED_STACK_NAME)/.env
MEMCACHED_ENV_EXAMPLE := $(MEMCACHED_STACK_NAME)/.env.example

memcached-pull-images: ## Pull images for the memcached stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(MEMCACHED_STACK_NAME)
memcached-setup: ## Ensure memcached/.env, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(MEMCACHED_ENV)'; \
	exf='$(MEMCACHED_ENV_EXAMPLE)'; \
	root='$(ENV_FILE)'; \
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
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='memcached-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "Memcached env OK ($$envf)."
.memcached-setup: memcached-setup
memcached-stack-up: .memcached-setup ## Deploy the memcached stack
	$(MAKE) stack-deploy STACK_NAME=$(MEMCACHED_STACK_NAME)
memcached-stack-down: ## Remove the memcached stack
	$(MAKE) stack-rm STACK_NAME=$(MEMCACHED_STACK_NAME)
memcached-stack-recreate: memcached-stack-down memcached-stack-up ## Recreate the memcached stack
memcached-stack-upgrade: ## Upgrade memcached swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(MEMCACHED_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(MEMCACHED_STACK_NAME)
memcached-stack-logs: ## Show logs of the memcached stack
	$(MAKE) stack-logs STACK_NAME=$(MEMCACHED_STACK_NAME)
memcached-stack-watch-logs: ## Watch logs of the memcached stack
	$(MAKE) stack-watch-logs STACK_NAME=$(MEMCACHED_STACK_NAME)
memcached-debug: ## Debug memcached swarm stack
	@echo "--- docker stack services ($(MEMCACHED_STACK_NAME))"
	@$(DOCKER) stack services $(MEMCACHED_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(MEMCACHED_STACK_NAME))"
	@$(DOCKER) stack ps $(MEMCACHED_STACK_NAME) --no-trunc
memcached-debug-logs: ## Tail recent logs for each memcached service
	@for s in $(MEMCACHED_SERVICES_SHORT); do \
		echo "==================== $(MEMCACHED_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(MEMCACHED_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
memcached-compose-upgrade: ## Upgrade the memcached compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(MEMCACHED_STACK_NAME)
memcached-compose-up: .memcached-setup ## Deploy memcached (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(MEMCACHED_STACK_NAME)
memcached-compose-down: ## Remove memcached (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(MEMCACHED_STACK_NAME)
memcached-compose-restart: ## Restart memcached (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(MEMCACHED_STACK_NAME)
memcached-compose-recreate: memcached-compose-down memcached-compose-up ## Recreate memcached (compose)
memcached-compose-logs: ## Show memcached compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(MEMCACHED_STACK_NAME)
memcached-compose-watch-logs: ## Watch memcached compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(MEMCACHED_STACK_NAME)
