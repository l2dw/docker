## —— 🐝 NocoDB commands ———————————————————————————————————
NOCODB_STACK_NAME := nocodb
NOCODB_SERVICES_SHORT := nocodb
NOCODB_ENV := $(NOCODB_STACK_NAME)/.env
NOCODB_ENV_EXAMPLE := $(NOCODB_STACK_NAME)/.env.example
NOCODB_SECRET_VARS := NOCODB_AUTH_JWT_SECRET
NOCODB_NOTIFY_VARS := NOCODB_APP_URL NOCODB_DOMAIN NOCODB_SITE_URL

nocodb-pull-images: ## Pull images for the nocodb stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(NOCODB_STACK_NAME)
nocodb-setup: ## Ensure nocodb/.env, generate JWT, sync SITE_URL / network
	@set -e; \
	envf='$(NOCODB_ENV)'; \
	exf='$(NOCODB_ENV_EXAMPLE)'; \
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
			NOCODB_AUTH_JWT_SECRET) printf '%s' '$(NOCODB_AUTH_JWT_SECRET)' ;; \
			NOCODB_APP_URL) printf '%s' '$(NOCODB_APP_URL)' ;; \
			NOCODB_DOMAIN) printf '%s' '$(NOCODB_DOMAIN)' ;; \
			NOCODB_SITE_URL) printf '%s' '$(NOCODB_SITE_URL)' ;; \
		esac; \
	}; \
	for k in $(NOCODB_SECRET_VARS); do \
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
	for k in $(NOCODB_NOTIFY_VARS); do \
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
	site=$$(file_get "$$envf" NOCODB_SITE_URL); \
	[ -n "$$site" ] || site=$$(file_get "$$envf" NOCODB_APP_URL); \
	[ -n "$$site" ] || site=$$(file_get "$$root" NOCODB_APP_URL); \
	if [ -n "$$site" ]; then \
		upsert "$$envf" NOCODB_SITE_URL "$$site"; \
		if [ -n "$$root" ]; then upsert "$$root" NOCODB_SITE_URL "$$site"; fi; \
	fi; \
	bp_set=0; \
	if grep -q '^NOCODB_BASE_PATH=' "$$envf" 2>/dev/null; then \
		bp=$$(file_get "$$envf" NOCODB_BASE_PATH); bp_set=1; \
	elif [ -n "$$root" ] && grep -q '^NOCODB_BASE_PATH=' "$$root" 2>/dev/null; then \
		bp=$$(file_get "$$root" NOCODB_BASE_PATH); bp_set=1; \
	fi; \
	[ "$$bp_set" -eq 1 ] || bp='/'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" NOCODB_BASE_PATH "/"; \
			upsert "$$envf" NOCODB_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then \
				upsert "$$root" NOCODB_BASE_PATH "/"; \
				upsert "$$root" NOCODB_MIDDLEWARES ""; \
			fi; \
			echo "NOCODB_BASE_PATH=/ (Host-only; subpath unsupported)."; \
			;; \
		*) \
			echo "Warning: NOCODB_BASE_PATH=$$bp — NocoDB subpath deploy is unsupported/fragile; prefer / on a dedicated subdomain." >&2; \
			upsert "$$envf" NOCODB_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then upsert "$$root" NOCODB_MIDDLEWARES ""; fi; \
			;; \
	esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='nocodb-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "NocoDB env OK ($$envf)."
.nocodb-setup: nocodb-setup
nocodb-stack-up: .nocodb-setup ## Deploy the nocodb stack
	$(MAKE) stack-deploy STACK_NAME=$(NOCODB_STACK_NAME)
nocodb-stack-down: ## Remove the nocodb stack
	$(MAKE) stack-rm STACK_NAME=$(NOCODB_STACK_NAME)
nocodb-stack-recreate: nocodb-stack-down nocodb-stack-up ## Recreate the nocodb stack
nocodb-stack-upgrade: ## Upgrade nocodb swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(NOCODB_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(NOCODB_STACK_NAME)
nocodb-stack-logs: ## Show logs of the nocodb stack
	$(MAKE) stack-logs STACK_NAME=$(NOCODB_STACK_NAME)
nocodb-stack-watch-logs: ## Watch logs of the nocodb stack
	$(MAKE) stack-watch-logs STACK_NAME=$(NOCODB_STACK_NAME)
nocodb-debug: ## Debug nocodb swarm stack
	@echo "--- docker stack services ($(NOCODB_STACK_NAME))"
	@$(DOCKER) stack services $(NOCODB_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(NOCODB_STACK_NAME))"
	@$(DOCKER) stack ps $(NOCODB_STACK_NAME) --no-trunc
nocodb-debug-logs: ## Tail recent logs for each nocodb service
	@for s in $(NOCODB_SERVICES_SHORT); do \
		echo "==================== $(NOCODB_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(NOCODB_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
nocodb-compose-upgrade: ## Upgrade the nocodb compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(NOCODB_STACK_NAME)
nocodb-compose-up: .nocodb-setup ## Deploy nocodb (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(NOCODB_STACK_NAME)
nocodb-compose-down: ## Remove nocodb (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(NOCODB_STACK_NAME)
nocodb-compose-restart: ## Restart nocodb (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(NOCODB_STACK_NAME)
nocodb-compose-recreate: nocodb-compose-down nocodb-compose-up ## Recreate nocodb (compose)
nocodb-compose-logs: ## Show nocodb compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(NOCODB_STACK_NAME)
nocodb-compose-watch-logs: ## Watch nocodb compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(NOCODB_STACK_NAME)
