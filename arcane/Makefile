## —— 🐝 Arcane commands ———————————————————————————————————
ARCANE_STACK_NAME := arcane
ARCANE_SERVICES_SHORT := arcane
ARCANE_ENV := $(ARCANE_STACK_NAME)/.env
ARCANE_ENV_EXAMPLE := $(ARCANE_STACK_NAME)/.env.example
# Required at runtime (empty in .env.example). Generated with openssl if missing.
ARCANE_SECRET_VARS := ARCANE_ENCRYPTION_KEY ARCANE_JWT_SECRET
# Required but site-specific — notify only (do not invent).
ARCANE_NOTIFY_VARS := ARCANE_APP_URL ARCANE_DOMAIN

arcane-pull-images: ## Pull images for the arcane stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(ARCANE_STACK_NAME)
arcane-stack-setup: ## Ensure arcane/.env, generate missing secrets, warn on empty APP_URL/DOMAIN
	@set -e; \
	envf='$(ARCANE_ENV)'; \
	exf='$(ARCANE_ENV_EXAMPLE)'; \
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
			ARCANE_ENCRYPTION_KEY) printf '%s' '$(ARCANE_ENCRYPTION_KEY)' ;; \
			ARCANE_JWT_SECRET) printf '%s' '$(ARCANE_JWT_SECRET)' ;; \
			ARCANE_APP_URL) printf '%s' '$(ARCANE_APP_URL)' ;; \
			ARCANE_DOMAIN) printf '%s' '$(ARCANE_DOMAIN)' ;; \
		esac; \
	}; \
	for k in $(ARCANE_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available to generate it." >&2; \
				echo "Set $$k in $$envf (openssl rand -hex 32)." >&2; \
				exit 1; \
			fi; \
			v=$$(openssl rand -hex 32); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root for Make/Swarm)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(ARCANE_NOTIFY_VARS); do \
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
			*example.com*) echo "Warning: $$k=$$v still uses example.com — set the real value in $$envf" >&2 ;; \
		esac; \
	done; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "Arcane env OK ($$envf)."
.arcane-stack-setup: arcane-stack-setup
arcane-stack-up: .arcane-stack-setup ## Deploy the arcane stack
	$(MAKE) stack-deploy STACK_NAME=$(ARCANE_STACK_NAME)
arcane-stack-down: ## Remove the arcane stack
	$(MAKE) stack-rm STACK_NAME=$(ARCANE_STACK_NAME)
arcane-stack-recreate: arcane-stack-down arcane-stack-up ## Recreate the arcane stack
arcane-stack-upgrade: ## Upgrade arcane swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(ARCANE_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(ARCANE_STACK_NAME)
arcane-stack-logs: ## Show logs of the arcane stack
	$(MAKE) stack-logs STACK_NAME=$(ARCANE_STACK_NAME)
arcane-stack-watch-logs: ## Watch logs of the arcane stack
	$(MAKE) stack-watch-logs STACK_NAME=$(ARCANE_STACK_NAME)
arcane-debug: ## Debug arcane swarm stack: services, tasks (states/errors)
	@echo "--- docker stack services ($(ARCANE_STACK_NAME))"
	@$(DOCKER) stack services $(ARCANE_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker service ls (${ARCANE_STACK_NAME}_*) ---"
	@$(DOCKER) service ls --filter label=com.docker.stack.namespace=$(ARCANE_STACK_NAME) 2>/dev/null \
		|| $(DOCKER) service ls | grep '$(ARCANE_STACK_NAME)_' \
		|| echo "(could not filter services)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(ARCANE_STACK_NAME))"
	@$(DOCKER) stack ps $(ARCANE_STACK_NAME) --no-trunc
arcane-debug-logs: ## Tail recent logs for each arcane service (e.g. services at 0/1)
	@for s in $(ARCANE_SERVICES_SHORT); do \
		echo "==================== $(ARCANE_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(ARCANE_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
arcane-compose-upgrade: ## Upgrade the arcane stack
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(ARCANE_STACK_NAME)
arcane-compose-up: .arcane-stack-setup ## Deploy the arcane stack
	$(MAKE) docker-project-up PROJECT_NAME=$(ARCANE_STACK_NAME)
arcane-compose-down: ## Remove the arcane stack
	$(MAKE) docker-project-down PROJECT_NAME=$(ARCANE_STACK_NAME)
arcane-compose-restart: ## Restart the arcane stack
	$(MAKE) docker-project-restart PROJECT_NAME=$(ARCANE_STACK_NAME)
arcane-compose-recreate: arcane-compose-down arcane-compose-up ## Recreate the arcane stack
arcane-compose-logs: ## Show logs of the arcane stack
	$(MAKE) docker-project-logs PROJECT_NAME=$(ARCANE_STACK_NAME)
arcane-compose-watch-logs: ## Watch logs of the arcane stack
	$(MAKE) docker-project-watch PROJECT_NAME=$(ARCANE_STACK_NAME)
