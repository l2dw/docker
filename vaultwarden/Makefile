## —— 🐝 Vaultwarden commands ———————————————————————————————————
VAULTWARDEN_STACK_NAME := vaultwarden
VAULTWARDEN_SERVICES_SHORT := vaultwarden
VAULTWARDEN_ENV := $(VAULTWARDEN_STACK_NAME)/.env
VAULTWARDEN_ENV_EXAMPLE := $(VAULTWARDEN_STACK_NAME)/.env.example
VAULTWARDEN_SECRET_VARS := VAULTWARDEN_ADMIN_TOKEN
VAULTWARDEN_NOTIFY_VARS := VAULTWARDEN_APP_URL VAULTWARDEN_DOMAIN

vaultwarden-pull-images: ## Pull images for the vaultwarden stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-setup: ## Ensure vaultwarden/.env, generate ADMIN_TOKEN, warn on APP_URL/DOMAIN
	@set -e; \
	envf='$(VAULTWARDEN_ENV)'; \
	exf='$(VAULTWARDEN_ENV_EXAMPLE)'; \
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
			VAULTWARDEN_ADMIN_TOKEN) printf '%s' '$(VAULTWARDEN_ADMIN_TOKEN)' ;; \
			VAULTWARDEN_APP_URL) printf '%s' '$(VAULTWARDEN_APP_URL)' ;; \
			VAULTWARDEN_DOMAIN) printf '%s' '$(VAULTWARDEN_DOMAIN)' ;; \
		esac; \
	}; \
	for k in $(VAULTWARDEN_SECRET_VARS); do \
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
	for k in $(VAULTWARDEN_NOTIFY_VARS); do \
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
	echo "Vaultwarden env OK ($$envf)."
.vaultwarden-setup: vaultwarden-setup
vaultwarden-stack-up: .vaultwarden-setup ## Deploy the vaultwarden stack
	$(MAKE) stack-deploy STACK_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-stack-down: ## Remove the vaultwarden stack
	$(MAKE) stack-rm STACK_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-stack-recreate: vaultwarden-stack-down vaultwarden-stack-up ## Recreate the vaultwarden stack
vaultwarden-stack-upgrade: ## Upgrade vaultwarden swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(VAULTWARDEN_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-stack-logs: ## Show logs of the vaultwarden stack
	$(MAKE) stack-logs STACK_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-stack-watch-logs: ## Watch logs of the vaultwarden stack
	$(MAKE) stack-watch-logs STACK_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-debug: ## Debug vaultwarden swarm stack
	@echo "--- docker stack services ($(VAULTWARDEN_STACK_NAME))"
	@$(DOCKER) stack services $(VAULTWARDEN_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(VAULTWARDEN_STACK_NAME))"
	@$(DOCKER) stack ps $(VAULTWARDEN_STACK_NAME) --no-trunc
vaultwarden-debug-logs: ## Tail recent logs for each vaultwarden service
	@for s in $(VAULTWARDEN_SERVICES_SHORT); do \
		echo "==================== $(VAULTWARDEN_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(VAULTWARDEN_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
vaultwarden-compose-upgrade: ## Upgrade the vaultwarden compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-compose-up: .vaultwarden-setup ## Deploy vaultwarden (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-compose-down: ## Remove vaultwarden (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-compose-restart: ## Restart vaultwarden (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-compose-recreate: vaultwarden-compose-down vaultwarden-compose-up ## Recreate vaultwarden (compose)
vaultwarden-compose-logs: ## Show vaultwarden compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(VAULTWARDEN_STACK_NAME)
vaultwarden-compose-watch-logs: ## Watch vaultwarden compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(VAULTWARDEN_STACK_NAME)
