## —— 🐝 redis commands ———————————————————————————————————
REDIS_STACK_NAME := redis
REDIS_SERVICES_SHORT := redis
REDIS_ENV := $(REDIS_STACK_NAME)/.env
REDIS_ENV_EXAMPLE := $(REDIS_STACK_NAME)/.env.example
REDIS_SECRET_VARS := REDIS_PASSWORD

redis-pull-images: ## Pull images for the redis stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(REDIS_STACK_NAME)
redis-setup: ## Ensure redis/.env, generate REDIS_PASSWORD if empty, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(REDIS_ENV)'; \
	exf='$(REDIS_ENV_EXAMPLE)'; \
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
	make_get() { \
		case $$1 in \
			REDIS_PASSWORD) printf '%s' '$(REDIS_PASSWORD)' ;; \
		esac; \
	}; \
	for k in $(REDIS_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 32); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='dokploy-network'; \
	case "$$net" in \
		''|dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "redis env OK ($$envf)."
.redis-setup: redis-setup
redis-stack-up: .redis-setup ## Deploy the redis stack
	$(MAKE) stack-deploy STACK_NAME=$(REDIS_STACK_NAME)
redis-stack-down: ## Remove the redis stack
	$(MAKE) stack-rm STACK_NAME=$(REDIS_STACK_NAME)
redis-stack-recreate: redis-stack-down redis-stack-up ## Recreate the redis stack
redis-stack-upgrade: ## Upgrade redis swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(REDIS_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(REDIS_STACK_NAME)
redis-stack-logs: ## Show logs of the redis stack
	$(MAKE) stack-logs STACK_NAME=$(REDIS_STACK_NAME)
redis-stack-watch-logs: ## Watch logs of the redis stack
	$(MAKE) stack-watch-logs STACK_NAME=$(REDIS_STACK_NAME)
redis-debug: ## Debug redis swarm stack
	@echo "--- docker stack services ($(REDIS_STACK_NAME))"
	@$(DOCKER) stack services $(REDIS_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(REDIS_STACK_NAME))"
	@$(DOCKER) stack ps $(REDIS_STACK_NAME) --no-trunc
redis-debug-logs: ## Tail recent logs for each redis service
	@for s in $(REDIS_SERVICES_SHORT); do \
		echo "==================== $(REDIS_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(REDIS_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
redis-compose-upgrade: ## Upgrade the redis compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(REDIS_STACK_NAME)
redis-compose-up: .redis-setup ## Deploy redis (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(REDIS_STACK_NAME)
redis-compose-down: ## Remove redis (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(REDIS_STACK_NAME)
redis-compose-restart: ## Restart redis (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(REDIS_STACK_NAME)
redis-compose-recreate: redis-compose-down redis-compose-up ## Recreate redis (compose)
redis-compose-logs: ## Show redis compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(REDIS_STACK_NAME)
redis-compose-watch-logs: ## Watch redis compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(REDIS_STACK_NAME)
