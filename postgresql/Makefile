## —— 🐝 PostgreSQL commands ———————————————————————————————————
POSTGRESQL_STACK_NAME := postgresql
POSTGRESQL_SERVICES_SHORT := postgresql
POSTGRESQL_ENV := $(POSTGRESQL_STACK_NAME)/.env
POSTGRESQL_ENV_EXAMPLE := $(POSTGRESQL_STACK_NAME)/.env.example
POSTGRESQL_SECRET_VARS := POSTGRESQL_PASSWORD

postgresql-pull-images: ## Pull images for the postgresql stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-stack-setup: ## Ensure postgresql/.env and require POSTGRESQL_PASSWORD
	@set -e; \
	envf='$(POSTGRESQL_ENV)'; \
	exf='$(POSTGRESQL_ENV_EXAMPLE)'; \
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
			POSTGRESQL_PASSWORD) printf '%s' '$(POSTGRESQL_PASSWORD)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(POSTGRESQL_SECRET_VARS); do \
		from_make=$$(make_get "$$k"); \
		v=$$from_make; \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			echo "Missing required $$k — set it in $$envf or pass $$k=... on the make command line." >&2; \
			missing=1; \
			continue; \
		fi; \
		if [ -n "$$from_make" ]; then \
			upsert "$$envf" "$$k" "$$from_make"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$from_make"; fi; \
			echo "Saved $$k → $$envf (and $$root)."; \
		fi; \
		case "$$v" in \
			ChangeMe|changeme|password|postgres) echo "Warning: $$k looks weak — use a strong secret in $$envf" >&2 ;; \
		esac; \
	done; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "PostgreSQL env OK ($$envf)."
.postgresql-stack-setup: postgresql-stack-setup
postgresql-stack-up: .postgresql-stack-setup ## Deploy the postgresql stack
	$(MAKE) stack-deploy STACK_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-stack-down: ## Remove the postgresql stack
	$(MAKE) stack-rm STACK_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-stack-recreate: postgresql-stack-down postgresql-stack-up ## Recreate the postgresql stack
postgresql-stack-upgrade: ## Upgrade postgresql swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(POSTGRESQL_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-stack-logs: ## Show logs of the postgresql stack
	$(MAKE) stack-logs STACK_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-stack-watch-logs: ## Watch logs of the postgresql stack
	$(MAKE) stack-watch-logs STACK_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-debug: ## Debug postgresql swarm stack: services, tasks, inspect
	@echo "--- docker stack services ($(POSTGRESQL_STACK_NAME))"
	@$(DOCKER) stack services $(POSTGRESQL_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker service ls (${POSTGRESQL_STACK_NAME}_*) ---"
	@$(DOCKER) service ls --filter label=com.docker.stack.namespace=$(POSTGRESQL_STACK_NAME) 2>/dev/null \
		|| $(DOCKER) service ls | grep '$(POSTGRESQL_STACK_NAME)_' \
		|| echo "(could not filter services)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(POSTGRESQL_STACK_NAME))"
	@$(DOCKER) stack ps $(POSTGRESQL_STACK_NAME) --no-trunc
	@echo
	@echo "--- postgresql service inspect ---"
	@$(DOCKER) service inspect $(POSTGRESQL_STACK_NAME)_postgresql --pretty 2>/dev/null || echo "(no postgresql service or inspect failed)"
postgresql-debug-logs: ## Tail recent logs for each postgresql service
	@for s in $(POSTGRESQL_SERVICES_SHORT); do \
		echo "==================== $(POSTGRESQL_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(POSTGRESQL_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
postgresql-compose-upgrade: ## Upgrade the postgresql compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-compose-up: .postgresql-stack-setup ## Deploy the postgresql stack (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-compose-down: ## Remove the postgresql stack (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-compose-restart: ## Restart the postgresql stack (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-compose-recreate: postgresql-compose-down postgresql-compose-up ## Recreate the postgresql stack
postgresql-compose-logs: ## Show logs of the postgresql stack (compose)
	$(MAKE) docker-project-logs PROJECT_NAME=$(POSTGRESQL_STACK_NAME)
postgresql-compose-watch-logs: ## Watch logs of the postgresql stack (compose)
	$(MAKE) docker-project-watch PROJECT_NAME=$(POSTGRESQL_STACK_NAME)
