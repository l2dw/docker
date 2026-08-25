## —— 🐝 NetBox commands ———————————————————————————————————
NETBOX_STACK_NAME := netbox
NETBOX_SERVICES_SHORT := netbox netbox-worker
NETBOX_ENV := $(NETBOX_STACK_NAME)/.env
NETBOX_ENV_EXAMPLE := $(NETBOX_STACK_NAME)/.env.example
NETBOX_SECRET_VARS := NETBOX_SECRET_KEY
NETBOX_NOTIFY_VARS := NETBOX_APP_URL NETBOX_DOMAIN NETBOX_DB_HOST NETBOX_REDIS_HOST
NETBOX_PASSWORD_VARS := NETBOX_DB_PASSWORD NETBOX_REDIS_PASSWORD

netbox-pull-images: ## Pull images for the netbox stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(NETBOX_STACK_NAME)
netbox-setup: ## Ensure netbox/.env, generate secrets, sync ALLOWED_HOSTS / network
	@set -e; \
	envf='$(NETBOX_ENV)'; \
	exf='$(NETBOX_ENV_EXAMPLE)'; \
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
			NETBOX_SECRET_KEY) printf '%s' '$(NETBOX_SECRET_KEY)' ;; \
			NETBOX_APP_URL) printf '%s' '$(NETBOX_APP_URL)' ;; \
			NETBOX_DOMAIN) printf '%s' '$(NETBOX_DOMAIN)' ;; \
			NETBOX_DB_HOST) printf '%s' '$(NETBOX_DB_HOST)' ;; \
			NETBOX_REDIS_HOST) printf '%s' '$(NETBOX_REDIS_HOST)' ;; \
			NETBOX_DB_PASSWORD) printf '%s' '$(NETBOX_DB_PASSWORD)' ;; \
			NETBOX_REDIS_PASSWORD) printf '%s' '$(NETBOX_REDIS_PASSWORD)' ;; \
		esac; \
	}; \
	for k in $(NETBOX_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 50); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	for k in $(NETBOX_PASSWORD_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 24); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (create matching credential on external Postgres/Redis)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(NETBOX_NOTIFY_VARS); do \
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
	domain=$$(file_get "$$envf" NETBOX_DOMAIN); \
	[ -n "$$domain" ] || domain=$$(file_get "$$root" NETBOX_DOMAIN); \
	if [ -n "$$domain" ]; then \
		upsert "$$envf" NETBOX_ALLOWED_HOSTS "$$domain"; \
		if [ -n "$$root" ]; then upsert "$$root" NETBOX_ALLOWED_HOSTS "$$domain"; fi; \
	fi; \
	rp=$$(file_get "$$envf" NETBOX_REDIS_PASSWORD); \
	[ -n "$$rp" ] || rp=$$(file_get "$$root" NETBOX_REDIS_PASSWORD); \
	cpw=$$(file_get "$$envf" NETBOX_REDIS_CACHE_PASSWORD); \
	[ -n "$$cpw" ] || cpw=$$(file_get "$$root" NETBOX_REDIS_CACHE_PASSWORD); \
	if [ -z "$$cpw" ] && [ -n "$$rp" ]; then \
		upsert "$$envf" NETBOX_REDIS_CACHE_PASSWORD "$$rp"; \
		if [ -n "$$root" ]; then upsert "$$root" NETBOX_REDIS_CACHE_PASSWORD "$$rp"; fi; \
		echo "NETBOX_REDIS_CACHE_PASSWORD ← NETBOX_REDIS_PASSWORD."; \
	fi; \
	ch=$$(file_get "$$envf" NETBOX_REDIS_CACHE_HOST); \
	[ -n "$$ch" ] || ch=$$(file_get "$$root" NETBOX_REDIS_CACHE_HOST); \
	rh=$$(file_get "$$envf" NETBOX_REDIS_HOST); \
	[ -n "$$rh" ] || rh=$$(file_get "$$root" NETBOX_REDIS_HOST); \
	if [ -z "$$ch" ] && [ -n "$$rh" ]; then \
		upsert "$$envf" NETBOX_REDIS_CACHE_HOST "$$rh"; \
		if [ -n "$$root" ]; then upsert "$$root" NETBOX_REDIS_CACHE_HOST "$$rh"; fi; \
	fi; \
	bp_set=0; \
	if grep -q '^NETBOX_BASE_PATH=' "$$envf" 2>/dev/null; then \
		bp=$$(file_get "$$envf" NETBOX_BASE_PATH); bp_set=1; \
	elif [ -n "$$root" ] && grep -q '^NETBOX_BASE_PATH=' "$$root" 2>/dev/null; then \
		bp=$$(file_get "$$root" NETBOX_BASE_PATH); bp_set=1; \
	fi; \
	[ "$$bp_set" -eq 1 ] || bp='/'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" NETBOX_BASE_PATH "/"; \
			upsert "$$envf" NETBOX_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then \
				upsert "$$root" NETBOX_BASE_PATH "/"; \
				upsert "$$root" NETBOX_MIDDLEWARES ""; \
			fi; \
			echo "NETBOX_BASE_PATH=/ (Host-only; subpath unsupported)."; \
			;; \
		*) \
			echo "Warning: NETBOX_BASE_PATH=$$bp — NetBox subpath deploy is unsupported/fragile; prefer / on a dedicated subdomain." >&2; \
			upsert "$$envf" NETBOX_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then upsert "$$root" NETBOX_MIDDLEWARES ""; fi; \
			;; \
	esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='netbox-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "NetBox env OK ($$envf)."
.netbox-setup: netbox-setup
netbox-stack-up: .netbox-setup ## Deploy the netbox stack
	$(MAKE) stack-deploy STACK_NAME=$(NETBOX_STACK_NAME)
netbox-stack-down: ## Remove the netbox stack
	$(MAKE) stack-rm STACK_NAME=$(NETBOX_STACK_NAME)
netbox-stack-recreate: netbox-stack-down netbox-stack-up ## Recreate the netbox stack
netbox-stack-upgrade: ## Upgrade netbox swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(NETBOX_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(NETBOX_STACK_NAME)
netbox-stack-logs: ## Show logs of the netbox stack
	$(MAKE) stack-logs STACK_NAME=$(NETBOX_STACK_NAME)
netbox-stack-watch-logs: ## Watch logs of the netbox stack
	$(MAKE) stack-watch-logs STACK_NAME=$(NETBOX_STACK_NAME)
netbox-debug: ## Debug netbox swarm stack
	@echo "--- docker stack services ($(NETBOX_STACK_NAME))"
	@$(DOCKER) stack services $(NETBOX_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(NETBOX_STACK_NAME))"
	@$(DOCKER) stack ps $(NETBOX_STACK_NAME) --no-trunc
netbox-debug-logs: ## Tail recent logs for each netbox service
	@for s in $(NETBOX_SERVICES_SHORT); do \
		echo "==================== $(NETBOX_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(NETBOX_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
netbox-compose-upgrade: ## Upgrade the netbox compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(NETBOX_STACK_NAME)
netbox-compose-up: .netbox-setup ## Deploy netbox (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(NETBOX_STACK_NAME)
netbox-compose-down: ## Remove netbox (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(NETBOX_STACK_NAME)
netbox-compose-restart: ## Restart netbox (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(NETBOX_STACK_NAME)
netbox-compose-recreate: netbox-compose-down netbox-compose-up ## Recreate netbox (compose)
netbox-compose-logs: ## Show netbox compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(NETBOX_STACK_NAME)
netbox-compose-watch-logs: ## Watch netbox compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(NETBOX_STACK_NAME)
