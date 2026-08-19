## —— 🐝 Keycloak commands ———————————————————————————————————
KEYCLOAK_STACK_NAME := keycloak
KEYCLOAK_SERVICES_SHORT := keycloak
KEYCLOAK_ENV := $(KEYCLOAK_STACK_NAME)/.env
KEYCLOAK_ENV_EXAMPLE := $(KEYCLOAK_STACK_NAME)/.env.example
KEYCLOAK_SECRET_VARS := KEYCLOAK_DB_PASSWORD KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD
KEYCLOAK_NOTIFY_VARS := KEYCLOAK_APP_URL KEYCLOAK_DOMAIN KEYCLOAK_DB_URL

keycloak-pull-images: ## Pull images for the keycloak stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-setup: ## Ensure keycloak/.env, generate admin/DB passwords, warn on APP_URL/DOMAIN/DB_URL
	@set -e; \
	envf='$(KEYCLOAK_ENV)'; \
	exf='$(KEYCLOAK_ENV_EXAMPLE)'; \
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
			KEYCLOAK_DB_PASSWORD) printf '%s' '$(KEYCLOAK_DB_PASSWORD)' ;; \
			KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD) printf '%s' '$(KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD)' ;; \
			KEYCLOAK_APP_URL) printf '%s' '$(KEYCLOAK_APP_URL)' ;; \
			KEYCLOAK_DOMAIN) printf '%s' '$(KEYCLOAK_DOMAIN)' ;; \
			KEYCLOAK_DB_URL) printf '%s' '$(KEYCLOAK_DB_URL)' ;; \
		esac; \
	}; \
	for k in $(KEYCLOAK_SECRET_VARS); do \
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
	missing=0; \
	for k in $(KEYCLOAK_NOTIFY_VARS); do \
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
		case "$$k:$$v" in \
			*example.com*) echo "Warning: $$k=$$v still uses example.com — set the real value in $$envf" >&2 ;; \
			KEYCLOAK_DB_URL:*keycloak-db*) echo "Warning: $$k still points at removed service keycloak-db — set an external JDBC URL." >&2 ;; \
		esac; \
	done; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "Keycloak env OK ($$envf)."
.keycloak-setup: keycloak-setup
keycloak-stack-up: .keycloak-setup ## Deploy the keycloak stack
	$(MAKE) stack-deploy STACK_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-stack-down: ## Remove the keycloak stack
	$(MAKE) stack-rm STACK_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-stack-recreate: keycloak-stack-down keycloak-stack-up ## Recreate the keycloak stack
keycloak-stack-upgrade: ## Upgrade keycloak swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(KEYCLOAK_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-stack-logs: ## Show logs of the keycloak stack
	$(MAKE) stack-logs STACK_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-stack-watch-logs: ## Watch logs of the keycloak stack
	$(MAKE) stack-watch-logs STACK_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-debug: ## Debug keycloak swarm stack
	@echo "--- docker stack services ($(KEYCLOAK_STACK_NAME))"
	@$(DOCKER) stack services $(KEYCLOAK_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(KEYCLOAK_STACK_NAME))"
	@$(DOCKER) stack ps $(KEYCLOAK_STACK_NAME) --no-trunc
keycloak-debug-logs: ## Tail recent logs for each keycloak service
	@for s in $(KEYCLOAK_SERVICES_SHORT); do \
		echo "==================== $(KEYCLOAK_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(KEYCLOAK_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
keycloak-compose-upgrade: ## Upgrade the keycloak compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-compose-up: .keycloak-setup ## Deploy keycloak (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-compose-down: ## Remove keycloak (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-compose-restart: ## Restart keycloak (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-compose-recreate: keycloak-compose-down keycloak-compose-up ## Recreate keycloak (compose)
keycloak-compose-logs: ## Show keycloak compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(KEYCLOAK_STACK_NAME)
keycloak-compose-watch-logs: ## Watch keycloak compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(KEYCLOAK_STACK_NAME)
