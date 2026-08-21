## —— 🐝 Nextcloud commands ———————————————————————————————————
NEXTCLOUD_STACK_NAME := nextcloud
NEXTCLOUD_SERVICES_SHORT := nextcloud
NEXTCLOUD_ENV := $(NEXTCLOUD_STACK_NAME)/.env
NEXTCLOUD_ENV_EXAMPLE := $(NEXTCLOUD_STACK_NAME)/.env.example
NEXTCLOUD_SECRET_VARS := NEXTCLOUD_ADMIN_PASSWORD NEXTCLOUD_DB_PASSWORD
NEXTCLOUD_NOTIFY_VARS := NEXTCLOUD_APP_URL NEXTCLOUD_DOMAIN

nextcloud-pull-images: ## Pull images for the nextcloud stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-setup: ## Ensure nextcloud/.env, generate admin/db passwords, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(NEXTCLOUD_ENV)'; \
	exf='$(NEXTCLOUD_ENV_EXAMPLE)'; \
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
			NEXTCLOUD_ADMIN_PASSWORD) printf '%s' '$(NEXTCLOUD_ADMIN_PASSWORD)' ;; \
			NEXTCLOUD_DB_PASSWORD) printf '%s' '$(NEXTCLOUD_DB_PASSWORD)' ;; \
			NEXTCLOUD_APP_URL) printf '%s' '$(NEXTCLOUD_APP_URL)' ;; \
			NEXTCLOUD_DOMAIN) printf '%s' '$(NEXTCLOUD_DOMAIN)' ;; \
		esac; \
	}; \
	for k in $(NEXTCLOUD_SECRET_VARS); do \
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
	for k in $(NEXTCLOUD_NOTIFY_VARS); do \
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
	app=$$(file_get "$$envf" APP_NAME); \
	[ -n "$$app" ] || app=$$(file_get "$$root" APP_NAME); \
	[ -n "$$app" ] || app='nextcloud'; \
	bp=$$(file_get "$$envf" NEXTCLOUD_BASE_PATH); \
	[ -n "$$bp" ] || bp=$$(file_get "$$root" NEXTCLOUD_BASE_PATH); \
	[ -n "$$bp" ] || bp='/nextcloud'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" NEXTCLOUD_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then upsert "$$root" NEXTCLOUD_MIDDLEWARES ""; fi; \
			echo "NEXTCLOUD_BASE_PATH=/ → cleared NEXTCLOUD_MIDDLEWARES (Host-only)."; \
			;; \
		*) \
			mw="$$app-strip"; \
			upsert "$$envf" NEXTCLOUD_MIDDLEWARES "$$mw"; \
			if [ -n "$$root" ]; then upsert "$$root" NEXTCLOUD_MIDDLEWARES "$$mw"; fi; \
			echo "NEXTCLOUD_MIDDLEWARES=$$mw (aligned with APP_NAME=$$app)."; \
			;; \
	esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='nextcloud-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "Nextcloud env OK ($$envf)."
.nextcloud-setup: nextcloud-setup
nextcloud-stack-up: .nextcloud-setup ## Deploy the nextcloud stack
	$(MAKE) stack-deploy STACK_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-stack-down: ## Remove the nextcloud stack
	$(MAKE) stack-rm STACK_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-stack-recreate: nextcloud-stack-down nextcloud-stack-up ## Recreate the nextcloud stack
nextcloud-stack-upgrade: ## Upgrade nextcloud swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(NEXTCLOUD_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-stack-logs: ## Show logs of the nextcloud stack
	$(MAKE) stack-logs STACK_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-stack-watch-logs: ## Watch logs of the nextcloud stack
	$(MAKE) stack-watch-logs STACK_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-debug: ## Debug nextcloud swarm stack
	@echo "--- docker stack services ($(NEXTCLOUD_STACK_NAME))"
	@$(DOCKER) stack services $(NEXTCLOUD_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(NEXTCLOUD_STACK_NAME))"
	@$(DOCKER) stack ps $(NEXTCLOUD_STACK_NAME) --no-trunc
nextcloud-debug-logs: ## Tail recent logs for each nextcloud service
	@for s in $(NEXTCLOUD_SERVICES_SHORT); do \
		echo "==================== $(NEXTCLOUD_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(NEXTCLOUD_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
nextcloud-compose-upgrade: ## Upgrade the nextcloud compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-compose-up: .nextcloud-setup ## Deploy nextcloud (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-compose-down: ## Remove nextcloud (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-compose-restart: ## Restart nextcloud (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-compose-recreate: nextcloud-compose-down nextcloud-compose-up ## Recreate nextcloud (compose)
nextcloud-compose-logs: ## Show nextcloud compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(NEXTCLOUD_STACK_NAME)
nextcloud-compose-watch-logs: ## Watch nextcloud compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(NEXTCLOUD_STACK_NAME)
