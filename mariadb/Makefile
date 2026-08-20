## —— 🐝 mariadb commands ———————————————————————————————————
MARIADB_STACK_NAME := mariadb
MARIADB_SERVICES_SHORT := mariadb
MARIADB_ENV := $(MARIADB_STACK_NAME)/.env
MARIADB_ENV_EXAMPLE := $(MARIADB_STACK_NAME)/.env.example
MARIADB_SECRET_VARS := MARIADB_ROOT_PASSWORD MARIADB_PASSWORD

mariadb-pull-images: ## Pull images for the mariadb stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(MARIADB_STACK_NAME)
mariadb-setup: ## Ensure mariadb/.env, generate DB passwords if empty, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(MARIADB_ENV)'; \
	exf='$(MARIADB_ENV_EXAMPLE)'; \
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
			MARIADB_ROOT_PASSWORD) printf '%s' '$(MARIADB_ROOT_PASSWORD)' ;; \
			MARIADB_PASSWORD) printf '%s' '$(MARIADB_PASSWORD)' ;; \
		esac; \
	}; \
	for k in $(MARIADB_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ] || [ "$$v" = ChangeMe ]; then \
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
	echo "mariadb env OK ($$envf)."
.mariadb-setup: mariadb-setup
mariadb-stack-up: .mariadb-setup ## Deploy the mariadb stack
	$(MAKE) stack-deploy STACK_NAME=$(MARIADB_STACK_NAME)
mariadb-stack-down: ## Remove the mariadb stack
	$(MAKE) stack-rm STACK_NAME=$(MARIADB_STACK_NAME)
mariadb-stack-recreate: mariadb-stack-down mariadb-stack-up ## Recreate the mariadb stack
mariadb-stack-upgrade: ## Upgrade mariadb swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(MARIADB_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(MARIADB_STACK_NAME)
mariadb-stack-logs: ## Show logs of the mariadb stack
	$(MAKE) stack-logs STACK_NAME=$(MARIADB_STACK_NAME)
mariadb-stack-watch-logs: ## Watch logs of the mariadb stack
	$(MAKE) stack-watch-logs STACK_NAME=$(MARIADB_STACK_NAME)
mariadb-debug: ## Debug mariadb swarm stack
	@echo "--- docker stack services ($(MARIADB_STACK_NAME))"
	@$(DOCKER) stack services $(MARIADB_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(MARIADB_STACK_NAME))"
	@$(DOCKER) stack ps $(MARIADB_STACK_NAME) --no-trunc
mariadb-debug-logs: ## Tail recent logs for each mariadb service
	@for s in $(MARIADB_SERVICES_SHORT); do \
		echo "==================== $(MARIADB_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(MARIADB_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
mariadb-compose-upgrade: ## Upgrade the mariadb compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(MARIADB_STACK_NAME)
mariadb-compose-up: .mariadb-setup ## Deploy mariadb (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(MARIADB_STACK_NAME)
mariadb-compose-down: ## Remove mariadb (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(MARIADB_STACK_NAME)
mariadb-compose-restart: ## Restart mariadb (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(MARIADB_STACK_NAME)
mariadb-compose-recreate: mariadb-compose-down mariadb-compose-up ## Recreate mariadb (compose)
mariadb-compose-logs: ## Show mariadb compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(MARIADB_STACK_NAME)
mariadb-compose-watch-logs: ## Watch mariadb compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(MARIADB_STACK_NAME)
