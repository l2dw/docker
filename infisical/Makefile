## —— 🐝 Infisical commands ———————————————————————————————————
INFISICAL_STACK_NAME := infisical
INFISICAL_SERVICES_SHORT := backend
INFISICAL_ENV := $(INFISICAL_STACK_NAME)/.env
INFISICAL_ENV_EXAMPLE := $(INFISICAL_STACK_NAME)/.env.example
# Generated with openssl when empty (never invented here).
INFISICAL_SECRET_VARS := INFISICAL_ENCRYPTION_KEY INFISICAL_AUTH_SECRET
# Required but site-specific — warn only (do not invent).
INFISICAL_NOTIFY_VARS := INFISICAL_DOMAIN INFISICAL_SITE_URL INFISICAL_DB_CONNECTION_URI INFISICAL_REDIS_URL
INFISICAL_NETWORK_NAME := infisical-network

infisical-pull-images: ## Pull images for the infisical stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(INFISICAL_STACK_NAME)

infisical-setup: ## Ensure infisical/.env, generate secrets, warn on example.com / unreplaced <DB_HOST>/<REDIS_HOST>
	@set -e; \
	envf='$(INFISICAL_ENV)'; \
	exf='$(INFISICAL_ENV_EXAMPLE)'; \
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
			INFISICAL_ENCRYPTION_KEY) printf '%s' '$(INFISICAL_ENCRYPTION_KEY)' ;; \
			INFISICAL_AUTH_SECRET) printf '%s' '$(INFISICAL_AUTH_SECRET)' ;; \
			INFISICAL_DOMAIN) printf '%s' '$(INFISICAL_DOMAIN)' ;; \
			INFISICAL_SITE_URL) printf '%s' '$(INFISICAL_SITE_URL)' ;; \
			INFISICAL_DB_CONNECTION_URI) printf '%s' '$(INFISICAL_DB_CONNECTION_URI)' ;; \
			INFISICAL_REDIS_URL) printf '%s' '$(INFISICAL_REDIS_URL)' ;; \
		esac; \
	}; \
	for k in $(INFISICAL_SECRET_VARS); do \
		from_make=$$(make_get "$$k"); \
		v=$$from_make; \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available to generate it." >&2; \
				echo "Set $$k in $$envf manually (INFISICAL_ENCRYPTION_KEY: openssl rand -hex 16; INFISICAL_AUTH_SECRET: openssl rand -base64 32)." >&2; \
				exit 1; \
			fi; \
			case "$$k" in \
				INFISICAL_ENCRYPTION_KEY) v=$$(openssl rand -hex 16) ;; \
				*) v=$$(openssl rand -base64 32) ;; \
			esac; \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		elif [ -n "$$from_make" ]; then \
			upsert "$$envf" "$$k" "$$from_make"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$from_make"; fi; \
			echo "Saved $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(INFISICAL_NOTIFY_VARS); do \
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
			INFISICAL_DB_CONNECTION_URI:*'<DB_HOST>'*) echo "Warning: $$k still contains <DB_HOST> — point it at the external PostgreSQL server." >&2 ;; \
			INFISICAL_DB_CONNECTION_URI:*ChangeMe*) echo "Warning: $$k still contains ChangeMe — set the real DB password." >&2 ;; \
			INFISICAL_REDIS_URL:*'<REDIS_HOST>'*) echo "Warning: $$k still contains <REDIS_HOST> — point it at the external Redis server." >&2 ;; \
		esac; \
	done; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='$(INFISICAL_NETWORK_NAME)'; \
	case "$$net" in ''|'$(INFISICAL_NETWORK_NAME)') ext=false ;; \
		*) ext=true ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; fi; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "Infisical env OK ($$envf)."
.infisical-setup: infisical-setup
infisical-stack-up: .infisical-setup ## Deploy the infisical stack
	$(MAKE) stack-deploy STACK_NAME=$(INFISICAL_STACK_NAME)
infisical-stack-down: ## Remove the infisical stack
	$(MAKE) stack-rm STACK_NAME=$(INFISICAL_STACK_NAME)
infisical-stack-recreate: infisical-stack-down infisical-stack-up ## Recreate the infisical stack
infisical-stack-upgrade: ## Upgrade infisical swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(INFISICAL_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(INFISICAL_STACK_NAME)
infisical-stack-logs: ## Show logs of the infisical stack
	$(MAKE) stack-logs STACK_NAME=$(INFISICAL_STACK_NAME)
infisical-stack-watch-logs: ## Watch logs of the infisical stack
	$(MAKE) stack-watch-logs STACK_NAME=$(INFISICAL_STACK_NAME)
infisical-debug: ## Debug infisical swarm stack
	@echo "--- docker stack services ($(INFISICAL_STACK_NAME))"
	@$(DOCKER) stack services $(INFISICAL_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(INFISICAL_STACK_NAME))"
	@$(DOCKER) stack ps $(INFISICAL_STACK_NAME) --no-trunc
infisical-debug-logs: ## Tail recent logs for each infisical service
	@for s in $(INFISICAL_SERVICES_SHORT); do \
		echo "==================== $(INFISICAL_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(INFISICAL_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
infisical-compose-upgrade: ## Upgrade the infisical compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(INFISICAL_STACK_NAME)
infisical-compose-up: .infisical-setup ## Deploy infisical (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(INFISICAL_STACK_NAME)
infisical-compose-down: ## Remove infisical (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(INFISICAL_STACK_NAME)
infisical-compose-restart: ## Restart infisical (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(INFISICAL_STACK_NAME)
infisical-compose-recreate: infisical-compose-down infisical-compose-up ## Recreate infisical (compose)
infisical-compose-logs: ## Show logs of the infisical compose project
	$(MAKE) docker-project-logs PROJECT_NAME=$(INFISICAL_STACK_NAME)
infisical-compose-watch-logs: ## Watch infisical compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(INFISICAL_STACK_NAME)
