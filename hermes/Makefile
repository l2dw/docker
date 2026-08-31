## —— 🐝 Hermes commands ———————————————————————————————————
HERMES_STACK_NAME := hermes
HERMES_SERVICES_SHORT := agent dashboard webui
HERMES_ENV := $(HERMES_STACK_NAME)/.env
HERMES_ENV_EXAMPLE := $(HERMES_STACK_NAME)/.env.example
HERMES_NOTIFY_VARS := HERMES_APP_URL HERMES_DOMAIN HERMES_DASHBOARD_APP_URL HERMES_DASHBOARD_DOMAIN

hermes-pull-images: ## Pull images for the hermes stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(HERMES_STACK_NAME)
hermes-setup: ## Ensure hermes/.env, API key, network sync
	@set -e; \
	envf='$(HERMES_ENV)'; \
	exf='$(HERMES_ENV_EXAMPLE)'; \
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
			HERMES_APP_URL) printf '%s' '$(HERMES_APP_URL)' ;; \
			HERMES_DOMAIN) printf '%s' '$(HERMES_DOMAIN)' ;; \
			HERMES_DASHBOARD_APP_URL) printf '%s' '$(HERMES_DASHBOARD_APP_URL)' ;; \
			HERMES_DASHBOARD_DOMAIN) printf '%s' '$(HERMES_DASHBOARD_DOMAIN)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(HERMES_NOTIFY_VARS); do \
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
	key=$$(file_get "$$envf" HERMES_API_SERVER_KEY); \
	[ -n "$$key" ] || key=$$(file_get "$$root" HERMES_API_SERVER_KEY); \
	if [ -z "$$key" ] || [ $${#key} -lt 16 ]; then \
		key=$$(openssl rand -hex 16); \
		upsert "$$envf" HERMES_API_SERVER_KEY "$$key"; \
		if [ -n "$$root" ]; then upsert "$$root" HERMES_API_SERVER_KEY "$$key"; fi; \
		echo "Generated HERMES_API_SERVER_KEY (gateway API on agent:8642)."; \
	fi; \
	pw=$$(file_get "$$envf" HERMES_WEBUI_PASSWORD); \
	[ -n "$$pw" ] || pw=$$(file_get "$$root" HERMES_WEBUI_PASSWORD); \
	case "$$pw" in \
		''|ChangeMe) echo "Warning: set HERMES_WEBUI_PASSWORD before exposing the Web UI via Traefik." >&2 ;; \
	esac; \
	dash_pw=$$(file_get "$$envf" HERMES_DASHBOARD_BASIC_AUTH_PASSWORD); \
	[ -n "$$dash_pw" ] || dash_pw=$$(file_get "$$root" HERMES_DASHBOARD_BASIC_AUTH_PASSWORD); \
	case "$$dash_pw" in \
		''|ChangeMe) echo "Warning: set HERMES_DASHBOARD_BASIC_AUTH_PASSWORD before exposing the dashboard via Traefik." >&2 ;; \
	esac; \
	dash_secret=$$(file_get "$$envf" HERMES_DASHBOARD_BASIC_AUTH_SECRET); \
	[ -n "$$dash_secret" ] || dash_secret=$$(file_get "$$root" HERMES_DASHBOARD_BASIC_AUTH_SECRET); \
	if [ -z "$$dash_secret" ]; then \
		dash_secret=$$(openssl rand -base64 32); \
		upsert "$$envf" HERMES_DASHBOARD_BASIC_AUTH_SECRET "$$dash_secret"; \
		if [ -n "$$root" ]; then upsert "$$root" HERMES_DASHBOARD_BASIC_AUTH_SECRET "$$dash_secret"; fi; \
		echo "Generated HERMES_DASHBOARD_BASIC_AUTH_SECRET (dashboard session signing)."; \
	fi; \
	uid=$$(file_get "$$envf" HERMES_UID); \
	[ -n "$$uid" ] || uid=$$(id -u 2>/dev/null || echo 1000); \
	gid=$$(file_get "$$envf" HERMES_GID); \
	[ -n "$$gid" ] || gid=$$(id -g 2>/dev/null || echo 1000); \
	upsert "$$envf" HERMES_UID "$$uid"; \
	upsert "$$envf" HERMES_GID "$$gid"; \
	if [ -n "$$root" ]; then \
		upsert "$$root" HERMES_UID "$$uid"; \
		upsert "$$root" HERMES_GID "$$gid"; \
	fi; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='hermes-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then \
		upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; \
		upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "Hermes env OK ($$envf)."
.hermes-setup: hermes-setup
hermes-stack-up: .hermes-setup ## Deploy the hermes stack
	$(MAKE) stack-deploy STACK_NAME=$(HERMES_STACK_NAME)
hermes-stack-down: ## Remove the hermes stack
	$(MAKE) stack-rm STACK_NAME=$(HERMES_STACK_NAME)
hermes-stack-recreate: hermes-stack-down hermes-stack-up ## Recreate the hermes stack
hermes-stack-upgrade: ## Upgrade hermes swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(HERMES_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(HERMES_STACK_NAME)
hermes-stack-logs: ## Show logs of the hermes stack
	$(MAKE) stack-logs STACK_NAME=$(HERMES_STACK_NAME)
hermes-stack-watch-logs: ## Watch logs of the hermes stack
	$(MAKE) stack-watch-logs STACK_NAME=$(HERMES_STACK_NAME)
hermes-debug: ## Debug hermes swarm stack
	@echo "--- docker stack services ($(HERMES_STACK_NAME))"
	@$(DOCKER) stack services $(HERMES_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(HERMES_STACK_NAME))"
	@$(DOCKER) stack ps $(HERMES_STACK_NAME) --no-trunc
hermes-debug-logs: ## Tail recent logs for each hermes service
	@for s in $(HERMES_SERVICES_SHORT); do \
		echo "==================== $(HERMES_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(HERMES_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
hermes-compose-upgrade: ## Upgrade the hermes compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(HERMES_STACK_NAME)
hermes-compose-up: .hermes-setup ## Deploy hermes (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(HERMES_STACK_NAME)
hermes-compose-down: ## Remove hermes (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(HERMES_STACK_NAME)
hermes-compose-restart: ## Restart hermes (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(HERMES_STACK_NAME)
hermes-compose-recreate: hermes-compose-down hermes-compose-up ## Recreate hermes (compose)
hermes-compose-logs: ## Show hermes compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(HERMES_STACK_NAME)
hermes-compose-watch-logs: ## Watch hermes compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(HERMES_STACK_NAME)
