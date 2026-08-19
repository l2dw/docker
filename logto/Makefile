## —— 🐝 Logto commands ———————————————————————————————————
LOGTO_STACK_NAME := logto
LOGTO_SERVICES_SHORT := logto
LOGTO_ENV := $(LOGTO_STACK_NAME)/.env
LOGTO_ENV_EXAMPLE := $(LOGTO_STACK_NAME)/.env.example
LOGTO_NOTIFY_VARS := LOGTO_DOMAIN LOGTO_ADMIN_DOMAIN LOGTO_ENDPOINT LOGTO_ADMIN_ENDPOINT LOGTO_DB_URL

logto-pull-images: ## Pull images for the logto stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(LOGTO_STACK_NAME)
logto-setup: ## Ensure logto/.env, warn on example.com / ChangeMe DB URL
	@set -e; \
	envf='$(LOGTO_ENV)'; \
	exf='$(LOGTO_ENV_EXAMPLE)'; \
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
			LOGTO_DOMAIN) printf '%s' '$(LOGTO_DOMAIN)' ;; \
			LOGTO_ADMIN_DOMAIN) printf '%s' '$(LOGTO_ADMIN_DOMAIN)' ;; \
			LOGTO_ENDPOINT) printf '%s' '$(LOGTO_ENDPOINT)' ;; \
			LOGTO_ADMIN_ENDPOINT) printf '%s' '$(LOGTO_ADMIN_ENDPOINT)' ;; \
			LOGTO_DB_URL) printf '%s' '$(LOGTO_DB_URL)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(LOGTO_NOTIFY_VARS); do \
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
			*ChangeMe*) echo "Warning: $$k still contains ChangeMe — set a real Postgres DSN in $$envf" >&2 ;; \
		esac; \
	done; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='dokploy-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "Logto env OK ($$envf)."
.logto-setup: logto-setup
logto-stack-up: .logto-setup ## Deploy the logto stack
	$(MAKE) stack-deploy STACK_NAME=$(LOGTO_STACK_NAME)
logto-stack-down: ## Remove the logto stack
	$(MAKE) stack-rm STACK_NAME=$(LOGTO_STACK_NAME)
logto-stack-recreate: logto-stack-down logto-stack-up ## Recreate the logto stack
logto-stack-upgrade: ## Upgrade logto swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(LOGTO_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(LOGTO_STACK_NAME)
logto-stack-logs: ## Show logs of the logto stack
	$(MAKE) stack-logs STACK_NAME=$(LOGTO_STACK_NAME)
logto-stack-watch-logs: ## Watch logs of the logto stack
	$(MAKE) stack-watch-logs STACK_NAME=$(LOGTO_STACK_NAME)
logto-debug: ## Debug logto swarm stack
	@echo "--- docker stack services ($(LOGTO_STACK_NAME))"
	@$(DOCKER) stack services $(LOGTO_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(LOGTO_STACK_NAME))"
	@$(DOCKER) stack ps $(LOGTO_STACK_NAME) --no-trunc
logto-debug-logs: ## Tail recent logs for each logto service
	@for s in $(LOGTO_SERVICES_SHORT); do \
		echo "==================== $(LOGTO_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(LOGTO_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
logto-compose-upgrade: ## Upgrade the logto compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(LOGTO_STACK_NAME)
logto-compose-up: .logto-setup ## Deploy logto (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(LOGTO_STACK_NAME)
logto-compose-down: ## Remove logto (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(LOGTO_STACK_NAME)
logto-compose-restart: ## Restart logto (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(LOGTO_STACK_NAME)
logto-compose-recreate: logto-compose-down logto-compose-up ## Recreate logto (compose)
logto-compose-logs: ## Show logto compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(LOGTO_STACK_NAME)
logto-compose-watch-logs: ## Watch logto compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(LOGTO_STACK_NAME)
