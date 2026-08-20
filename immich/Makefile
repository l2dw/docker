## —— 🐝 immich commands ———————————————————————————————————
IMMICH_STACK_NAME := immich
IMMICH_SERVICES_SHORT := immich-server immich-machine-learning
IMMICH_ENV := $(IMMICH_STACK_NAME)/.env
IMMICH_ENV_EXAMPLE := $(IMMICH_STACK_NAME)/.env.example
IMMICH_NOTIFY_VARS := IMMICH_DOMAIN

immich-pull-images: ## Pull images for the immich stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(IMMICH_STACK_NAME)
immich-setup: ## Ensure immich/.env, warn on placeholders, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(IMMICH_ENV)'; \
	exf='$(IMMICH_ENV_EXAMPLE)'; \
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
			IMMICH_DOMAIN) printf '%s' '$(IMMICH_DOMAIN)' ;; \
		esac; \
	}; \
	for k in $(IMMICH_NOTIFY_VARS); do \
		from_make=$$(make_get "$$k"); \
		v=$$from_make; \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -n "$$from_make" ]; then \
			upsert "$$envf" "$$k" "$$from_make"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$from_make"; fi; \
			echo "Saved $$k → $$envf (and $$root)."; \
		fi; \
		case "$$v" in \
			*example.com*) echo "Warning: $$k=$$v still uses example.com — set the real value in $$envf" >&2 ;; \
		esac; \
	done; \
	bp=$$(file_get "$$envf" IMMICH_BASE_PATH); \
	[ -n "$$bp" ] || bp=$$(file_get "$$root" IMMICH_BASE_PATH); \
	[ -n "$$bp" ] || bp='/'; \
	case "$$bp" in \
		/|'') ;; \
		*) echo "Warning: Immich does not support subpath (IMMICH_BASE_PATH=$$bp). Use a dedicated subdomain and IMMICH_BASE_PATH=/." >&2 ;; \
	esac; \
	upsert "$$envf" IMMICH_BASE_PATH /; \
	if [ -n "$$root" ]; then upsert "$$root" IMMICH_BASE_PATH /; fi; \
	redis=$$(file_get "$$envf" IMMICH_REDIS_PASSWORD); \
	[ -n "$$redis" ] || redis=$$(file_get "$$root" IMMICH_REDIS_PASSWORD); \
	case "$$redis" in \
		ChangeMe|'') echo "Warning: IMMICH_REDIS_PASSWORD empty or ChangeMe — paste REDIS_PASSWORD from the redis stack." >&2 ;; \
	esac; \
	dbhost=$$(file_get "$$envf" IMMICH_DB_HOSTNAME); \
	[ -n "$$dbhost" ] || dbhost=$$(file_get "$$root" IMMICH_DB_HOSTNAME); \
	if [ -z "$$dbhost" ]; then \
		echo "Warning: IMMICH_DB_HOSTNAME is empty — set the external Postgres host (VectorChord required)." >&2; \
	fi; \
	dbp=$$(file_get "$$envf" IMMICH_DB_PASSWORD); \
	[ -n "$$dbp" ] || dbp=$$(file_get "$$root" IMMICH_DB_PASSWORD); \
	case "$$dbp" in \
		ChangeMe|'') echo "Warning: IMMICH_DB_PASSWORD empty or ChangeMe — must match the external Postgres role." >&2 ;; \
	esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='immich-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "immich env OK ($$envf)."
.immich-setup: immich-setup
immich-stack-up: .immich-setup ## Deploy the immich stack
	$(MAKE) stack-deploy STACK_NAME=$(IMMICH_STACK_NAME)
immich-stack-down: ## Remove the immich stack
	$(MAKE) stack-rm STACK_NAME=$(IMMICH_STACK_NAME)
immich-stack-recreate: immich-stack-down immich-stack-up ## Recreate the immich stack
immich-stack-upgrade: ## Upgrade immich swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(IMMICH_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(IMMICH_STACK_NAME)
immich-stack-logs: ## Show logs of the immich stack
	$(MAKE) stack-logs STACK_NAME=$(IMMICH_STACK_NAME)
immich-stack-watch-logs: ## Watch logs of the immich stack
	$(MAKE) stack-watch-logs STACK_NAME=$(IMMICH_STACK_NAME)
immich-debug: ## Debug immich swarm stack
	@echo "--- docker stack services ($(IMMICH_STACK_NAME))"
	@$(DOCKER) stack services $(IMMICH_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(IMMICH_STACK_NAME))"
	@$(DOCKER) stack ps $(IMMICH_STACK_NAME) --no-trunc
immich-debug-logs: ## Tail recent logs for each immich service
	@for s in $(IMMICH_SERVICES_SHORT); do \
		echo "==================== $(IMMICH_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(IMMICH_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
immich-compose-upgrade: ## Upgrade the immich compose project
	$(MAKE) docker-pull-images PROJECT_NAME=$(IMMICH_STACK_NAME)
	$(MAKE) docker-project-up PROJECT_NAME=$(IMMICH_STACK_NAME)
immich-compose-up: .immich-setup ## Deploy immich (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(IMMICH_STACK_NAME)
immich-compose-down: ## Remove immich (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(IMMICH_STACK_NAME)
immich-compose-restart: ## Restart immich (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(IMMICH_STACK_NAME)
immich-compose-recreate: immich-compose-down immich-compose-up ## Recreate immich (compose)
immich-compose-logs: ## Show immich compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(IMMICH_STACK_NAME)
immich-compose-watch-logs: ## Watch immich compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(IMMICH_STACK_NAME)
