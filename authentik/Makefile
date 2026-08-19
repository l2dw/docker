## —— 🐝 Authentik commands ———————————————————————————————————
AUTHENTIK_STACK_NAME := authentik
AUTHENTIK_SERVICES_SHORT := authentik-server authentik-worker
AUTHENTIK_ENV := $(AUTHENTIK_STACK_NAME)/.env
AUTHENTIK_ENV_EXAMPLE := $(AUTHENTIK_STACK_NAME)/.env.example
AUTHENTIK_NOTIFY_VARS := AUTHENTIK_DOMAIN AUTHENTIK_POSTGRESQL__HOST AUTHENTIK_POSTGRESQL__USER AUTHENTIK_POSTGRESQL__NAME AUTHENTIK_POSTGRESQL__PASSWORD

authentik-pull-images: ## Pull images for the authentik stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(AUTHENTIK_STACK_NAME)
authentik-setup: ## Ensure authentik/.env, generate SECRET_KEY, warn on example.com / ChangeMe
	@set -e; \
	envf='$(AUTHENTIK_ENV)'; \
	exf='$(AUTHENTIK_ENV_EXAMPLE)'; \
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
			AUTHENTIK_DOMAIN) printf '%s' '$(AUTHENTIK_DOMAIN)' ;; \
			AUTHENTIK_POSTGRESQL__HOST) printf '%s' '$(AUTHENTIK_POSTGRESQL__HOST)' ;; \
			AUTHENTIK_POSTGRESQL__USER) printf '%s' '$(AUTHENTIK_POSTGRESQL__USER)' ;; \
			AUTHENTIK_POSTGRESQL__NAME) printf '%s' '$(AUTHENTIK_POSTGRESQL__NAME)' ;; \
			AUTHENTIK_POSTGRESQL__PASSWORD) printf '%s' '$(AUTHENTIK_POSTGRESQL__PASSWORD)' ;; \
			AUTHENTIK_SECRET_KEY) printf '%s' '$(AUTHENTIK_SECRET_KEY)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(AUTHENTIK_NOTIFY_VARS); do \
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
			*ChangeMe*) echo "Warning: $$k still contains ChangeMe — set a real value in $$envf" >&2 ;; \
		esac; \
	done; \
	from_make=$$(make_get AUTHENTIK_SECRET_KEY); \
	sk=$$from_make; \
	[ -n "$$sk" ] || sk=$$(file_get "$$envf" AUTHENTIK_SECRET_KEY); \
	[ -n "$$sk" ] || sk=$$(file_get "$$root" AUTHENTIK_SECRET_KEY); \
	if [ -z "$$sk" ] || [ "$$sk" = ChangeMe ]; then \
		sk=$$(openssl rand -base64 60 | tr -d '\n'); \
		upsert "$$envf" AUTHENTIK_SECRET_KEY "$$sk"; \
		if [ -n "$$root" ]; then upsert "$$root" AUTHENTIK_SECRET_KEY "$$sk"; fi; \
		echo "Generated AUTHENTIK_SECRET_KEY → $$envf"; \
	elif [ -n "$$from_make" ]; then \
		upsert "$$envf" AUTHENTIK_SECRET_KEY "$$from_make"; \
		if [ -n "$$root" ]; then upsert "$$root" AUTHENTIK_SECRET_KEY "$$from_make"; fi; \
	fi; \
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
	echo "Authentik env OK ($$envf)."
.authentik-setup: authentik-setup
authentik-stack-up: .authentik-setup ## Deploy the authentik stack
	$(MAKE) stack-deploy STACK_NAME=$(AUTHENTIK_STACK_NAME)
authentik-stack-down: ## Remove the authentik stack
	$(MAKE) stack-rm STACK_NAME=$(AUTHENTIK_STACK_NAME)
authentik-stack-recreate: authentik-stack-down authentik-stack-up ## Recreate the authentik stack
authentik-stack-upgrade: ## Upgrade authentik swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(AUTHENTIK_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(AUTHENTIK_STACK_NAME)
authentik-stack-logs: ## Show logs of the authentik stack
	$(MAKE) stack-logs STACK_NAME=$(AUTHENTIK_STACK_NAME)
authentik-stack-watch-logs: ## Watch logs of the authentik stack
	$(MAKE) stack-watch-logs STACK_NAME=$(AUTHENTIK_STACK_NAME)
authentik-debug: ## Debug authentik swarm stack
	@echo "--- docker stack services ($(AUTHENTIK_STACK_NAME))"
	@$(DOCKER) stack services $(AUTHENTIK_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(AUTHENTIK_STACK_NAME))"
	@$(DOCKER) stack ps $(AUTHENTIK_STACK_NAME) --no-trunc
authentik-debug-logs: ## Tail recent logs for each authentik service
	@for s in $(AUTHENTIK_SERVICES_SHORT); do \
		echo "==================== $(AUTHENTIK_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(AUTHENTIK_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
authentik-compose-upgrade: ## Upgrade the authentik compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(AUTHENTIK_STACK_NAME)
authentik-compose-up: .authentik-setup ## Deploy authentik (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(AUTHENTIK_STACK_NAME)
authentik-compose-down: ## Remove authentik (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(AUTHENTIK_STACK_NAME)
authentik-compose-restart: ## Restart authentik (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(AUTHENTIK_STACK_NAME)
authentik-compose-recreate: authentik-compose-down authentik-compose-up ## Recreate authentik (compose)
authentik-compose-logs: ## Show authentik compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(AUTHENTIK_STACK_NAME)
authentik-compose-watch-logs: ## Watch authentik compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(AUTHENTIK_STACK_NAME)
