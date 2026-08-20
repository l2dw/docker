## —— 🐝 paperless commands ———————————————————————————————————
PAPERLESS_STACK_NAME := paperless
PAPERLESS_SERVICES_SHORT := paperless
PAPERLESS_ENV := $(PAPERLESS_STACK_NAME)/.env
PAPERLESS_ENV_EXAMPLE := $(PAPERLESS_STACK_NAME)/.env.example
PAPERLESS_SECRET_VARS := PAPERLESS_SECRET_KEY PAPERLESS_ADMIN_PASSWORD
PAPERLESS_NOTIFY_VARS := PAPERLESS_DOMAIN PAPERLESS_URL

paperless-pull-images: ## Pull images for the paperless stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(PAPERLESS_STACK_NAME)
paperless-setup: ## Ensure paperless/.env, generate secrets, sync base path + DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(PAPERLESS_ENV)'; \
	exf='$(PAPERLESS_ENV_EXAMPLE)'; \
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
			PAPERLESS_SECRET_KEY) printf '%s' '$(PAPERLESS_SECRET_KEY)' ;; \
			PAPERLESS_ADMIN_PASSWORD) printf '%s' '$(PAPERLESS_ADMIN_PASSWORD)' ;; \
			PAPERLESS_DOMAIN) printf '%s' '$(PAPERLESS_DOMAIN)' ;; \
			PAPERLESS_URL) printf '%s' '$(PAPERLESS_URL)' ;; \
		esac; \
	}; \
	for k in $(PAPERLESS_SECRET_VARS); do \
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
	au=$$(file_get "$$envf" PAPERLESS_ADMIN_USER); \
	[ -n "$$au" ] || au=$$(file_get "$$root" PAPERLESS_ADMIN_USER); \
	if [ -z "$$au" ]; then \
		upsert "$$envf" PAPERLESS_ADMIN_USER admin; \
		if [ -n "$$root" ]; then upsert "$$root" PAPERLESS_ADMIN_USER admin; fi; \
		echo "Set PAPERLESS_ADMIN_USER=admin"; \
	fi; \
	for k in $(PAPERLESS_NOTIFY_VARS); do \
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
	redis=$$(file_get "$$envf" PAPERLESS_REDIS); \
	[ -n "$$redis" ] || redis=$$(file_get "$$root" PAPERLESS_REDIS); \
	case "$$redis" in \
		*ChangeMe*) echo "Warning: PAPERLESS_REDIS still contains ChangeMe — paste REDIS_PASSWORD from the redis stack." >&2 ;; \
	esac; \
	dbp=$$(file_get "$$envf" PAPERLESS_DBPASS); \
	[ -n "$$dbp" ] || dbp=$$(file_get "$$root" PAPERLESS_DBPASS); \
	case "$$dbp" in \
		ChangeMe|'') echo "Warning: PAPERLESS_DBPASS is empty or ChangeMe — create DB paperless on dokploy-postgresql first." >&2 ;; \
	esac; \
	bp=$$(file_get "$$envf" PAPERLESS_BASE_PATH); \
	[ -n "$$bp" ] || bp=$$(file_get "$$root" PAPERLESS_BASE_PATH); \
	[ -n "$$bp" ] || bp='/paperless'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" PAPERLESS_BASE_PATH /; \
			upsert "$$envf" PAPERLESS_FORCE_SCRIPT_NAME ""; \
			upsert "$$envf" PAPERLESS_STATIC_URL /static/; \
			upsert "$$envf" PAPERLESS_HEALTHCHECK_URL http://127.0.0.1:8000/; \
			if [ -n "$$root" ]; then \
				upsert "$$root" PAPERLESS_BASE_PATH /; \
				upsert "$$root" PAPERLESS_FORCE_SCRIPT_NAME ""; \
				upsert "$$root" PAPERLESS_STATIC_URL /static/; \
				upsert "$$root" PAPERLESS_HEALTHCHECK_URL http://127.0.0.1:8000/; \
			fi; \
			echo "PAPERLESS_BASE_PATH=/ → Host-only (empty FORCE_SCRIPT_NAME, STATIC_URL=/static/)."; \
			;; \
		*) \
			upsert "$$envf" PAPERLESS_FORCE_SCRIPT_NAME "$$bp"; \
			upsert "$$envf" PAPERLESS_STATIC_URL "$$bp/static/"; \
			upsert "$$envf" PAPERLESS_HEALTHCHECK_URL "http://127.0.0.1:8000$$bp/"; \
			if [ -n "$$root" ]; then \
				upsert "$$root" PAPERLESS_FORCE_SCRIPT_NAME "$$bp"; \
				upsert "$$root" PAPERLESS_STATIC_URL "$$bp/static/"; \
				upsert "$$root" PAPERLESS_HEALTHCHECK_URL "http://127.0.0.1:8000$$bp/"; \
			fi; \
			echo "PAPERLESS_BASE_PATH=$$bp → FORCE_SCRIPT_NAME + STATIC_URL aligned (no Traefik stripPrefix)."; \
			;; \
	esac; \
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
	echo "paperless env OK ($$envf)."
.paperless-setup: paperless-setup
paperless-stack-up: .paperless-setup ## Deploy the paperless stack
	$(MAKE) stack-deploy STACK_NAME=$(PAPERLESS_STACK_NAME)
paperless-stack-down: ## Remove the paperless stack
	$(MAKE) stack-rm STACK_NAME=$(PAPERLESS_STACK_NAME)
paperless-stack-recreate: paperless-stack-down paperless-stack-up ## Recreate the paperless stack
paperless-stack-upgrade: ## Upgrade paperless swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(PAPERLESS_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(PAPERLESS_STACK_NAME)
paperless-stack-logs: ## Show logs of the paperless stack
	$(MAKE) stack-logs STACK_NAME=$(PAPERLESS_STACK_NAME)
paperless-stack-watch-logs: ## Watch logs of the paperless stack
	$(MAKE) stack-watch-logs STACK_NAME=$(PAPERLESS_STACK_NAME)
paperless-debug: ## Debug paperless swarm stack
	@echo "--- docker stack services ($(PAPERLESS_STACK_NAME))"
	@$(DOCKER) stack services $(PAPERLESS_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(PAPERLESS_STACK_NAME))"
	@$(DOCKER) stack ps $(PAPERLESS_STACK_NAME) --no-trunc
paperless-debug-logs: ## Tail recent logs for each paperless service
	@for s in $(PAPERLESS_SERVICES_SHORT); do \
		echo "==================== $(PAPERLESS_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(PAPERLESS_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
paperless-compose-upgrade: ## Upgrade the paperless compose project
	$(MAKE) docker-pull-images PROJECT_NAME=$(PAPERLESS_STACK_NAME)
	$(MAKE) docker-project-up PROJECT_NAME=$(PAPERLESS_STACK_NAME)
paperless-compose-up: .paperless-setup ## Deploy paperless (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(PAPERLESS_STACK_NAME)
paperless-compose-down: ## Remove paperless (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(PAPERLESS_STACK_NAME)
paperless-compose-restart: ## Restart paperless (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(PAPERLESS_STACK_NAME)
paperless-compose-recreate: paperless-compose-down paperless-compose-up ## Recreate paperless (compose)
paperless-compose-logs: ## Show paperless compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(PAPERLESS_STACK_NAME)
paperless-compose-watch-logs: ## Watch paperless compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(PAPERLESS_STACK_NAME)
