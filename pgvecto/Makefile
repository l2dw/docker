## —— 🐝 pgvecto commands ———————————————————————————————————
PGVECTO_STACK_NAME := pgvecto
PGVECTO_SERVICES_SHORT := pgvecto
PGVECTO_ENV := $(PGVECTO_STACK_NAME)/.env
PGVECTO_ENV_EXAMPLE := $(PGVECTO_STACK_NAME)/.env.example
PGVECTO_SECRET_VARS := PGVECTO_PASSWORD

pgvecto-pull-images: ## Pull images for the pgvecto stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(PGVECTO_STACK_NAME)
pgvecto-setup: ## Ensure pgvecto/.env, generate PGVECTO_PASSWORD if empty, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(PGVECTO_ENV)'; \
	exf='$(PGVECTO_ENV_EXAMPLE)'; \
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
			PGVECTO_PASSWORD) printf '%s' '$(PGVECTO_PASSWORD)' ;; \
		esac; \
	}; \
	for k in $(PGVECTO_SECRET_VARS); do \
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
	echo "pgvecto env OK ($$envf)."
.pgvecto-setup: pgvecto-setup
pgvecto-stack-up: .pgvecto-setup ## Deploy the pgvecto stack
	$(MAKE) stack-deploy STACK_NAME=$(PGVECTO_STACK_NAME)
pgvecto-stack-down: ## Remove the pgvecto stack
	$(MAKE) stack-rm STACK_NAME=$(PGVECTO_STACK_NAME)
pgvecto-stack-recreate: pgvecto-stack-down pgvecto-stack-up ## Recreate the pgvecto stack
pgvecto-stack-upgrade: ## Upgrade pgvecto swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(PGVECTO_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(PGVECTO_STACK_NAME)
pgvecto-stack-logs: ## Show logs of the pgvecto stack
	$(MAKE) stack-logs STACK_NAME=$(PGVECTO_STACK_NAME)
pgvecto-stack-watch-logs: ## Watch logs of the pgvecto stack
	$(MAKE) stack-watch-logs STACK_NAME=$(PGVECTO_STACK_NAME)
pgvecto-debug: ## Debug pgvecto swarm stack
	@echo "--- docker stack services ($(PGVECTO_STACK_NAME))"
	@$(DOCKER) stack services $(PGVECTO_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(PGVECTO_STACK_NAME))"
	@$(DOCKER) stack ps $(PGVECTO_STACK_NAME) --no-trunc
pgvecto-debug-logs: ## Tail recent logs for each pgvecto service
	@for s in $(PGVECTO_SERVICES_SHORT); do \
		echo "==================== $(PGVECTO_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(PGVECTO_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
pgvecto-compose-upgrade: ## Upgrade the pgvecto compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(PGVECTO_STACK_NAME)
pgvecto-compose-up: .pgvecto-setup ## Deploy pgvecto (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(PGVECTO_STACK_NAME)
pgvecto-compose-down: ## Remove pgvecto (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(PGVECTO_STACK_NAME)
pgvecto-compose-restart: ## Restart pgvecto (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(PGVECTO_STACK_NAME)
pgvecto-compose-recreate: pgvecto-compose-down pgvecto-compose-up ## Recreate pgvecto (compose)
pgvecto-compose-logs: ## Show pgvecto compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(PGVECTO_STACK_NAME)
pgvecto-compose-watch-logs: ## Watch pgvecto compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(PGVECTO_STACK_NAME)
