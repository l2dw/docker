## —— 🐝 HedgeDoc commands ———————————————————————————————————
HEDGEDOC_STACK_NAME := hedgedoc
HEDGEDOC_SERVICES_SHORT := hedgedoc
HEDGEDOC_ENV := $(HEDGEDOC_STACK_NAME)/.env
HEDGEDOC_ENV_EXAMPLE := $(HEDGEDOC_STACK_NAME)/.env.example
HEDGEDOC_NOTIFY_VARS := HEDGEDOC_DOMAIN HEDGEDOC_DB_URL

hedgedoc-pull-images: ## Pull images for the hedgedoc stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-setup: ## Ensure hedgedoc/.env, generate SESSION_SECRET, warn on example.com / ChangeMe
	@set -e; \
	envf='$(HEDGEDOC_ENV)'; \
	exf='$(HEDGEDOC_ENV_EXAMPLE)'; \
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
			HEDGEDOC_DOMAIN) printf '%s' '$(HEDGEDOC_DOMAIN)' ;; \
			HEDGEDOC_DB_URL) printf '%s' '$(HEDGEDOC_DB_URL)' ;; \
			HEDGEDOC_SESSION_SECRET) printf '%s' '$(HEDGEDOC_SESSION_SECRET)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(HEDGEDOC_NOTIFY_VARS); do \
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
	from_make=$$(make_get HEDGEDOC_SESSION_SECRET); \
	sk=$$from_make; \
	[ -n "$$sk" ] || sk=$$(file_get "$$envf" HEDGEDOC_SESSION_SECRET); \
	[ -n "$$sk" ] || sk=$$(file_get "$$root" HEDGEDOC_SESSION_SECRET); \
	if [ -z "$$sk" ] || [ "$$sk" = ChangeMe ]; then \
		sk=$$(openssl rand -hex 32); \
		upsert "$$envf" HEDGEDOC_SESSION_SECRET "$$sk"; \
		if [ -n "$$root" ]; then upsert "$$root" HEDGEDOC_SESSION_SECRET "$$sk"; fi; \
		echo "Generated HEDGEDOC_SESSION_SECRET → $$envf"; \
	elif [ -n "$$from_make" ]; then \
		upsert "$$envf" HEDGEDOC_SESSION_SECRET "$$from_make"; \
		if [ -n "$$root" ]; then upsert "$$root" HEDGEDOC_SESSION_SECRET "$$from_make"; fi; \
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
	echo "HedgeDoc env OK ($$envf)."
.hedgedoc-setup: hedgedoc-setup
hedgedoc-stack-up: .hedgedoc-setup ## Deploy the hedgedoc stack
	$(MAKE) stack-deploy STACK_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-stack-down: ## Remove the hedgedoc stack
	$(MAKE) stack-rm STACK_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-stack-recreate: hedgedoc-stack-down hedgedoc-stack-up ## Recreate the hedgedoc stack
hedgedoc-stack-upgrade: ## Upgrade hedgedoc swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(HEDGEDOC_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-stack-logs: ## Show logs of the hedgedoc stack
	$(MAKE) stack-logs STACK_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-stack-watch-logs: ## Watch logs of the hedgedoc stack
	$(MAKE) stack-watch-logs STACK_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-debug: ## Debug hedgedoc swarm stack
	@echo "--- docker stack services ($(HEDGEDOC_STACK_NAME))"
	@$(DOCKER) stack services $(HEDGEDOC_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(HEDGEDOC_STACK_NAME))"
	@$(DOCKER) stack ps $(HEDGEDOC_STACK_NAME) --no-trunc
hedgedoc-debug-logs: ## Tail recent logs for each hedgedoc service
	@for s in $(HEDGEDOC_SERVICES_SHORT); do \
		echo "==================== $(HEDGEDOC_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(HEDGEDOC_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
hedgedoc-compose-upgrade: ## Upgrade the hedgedoc compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-compose-up: .hedgedoc-setup ## Deploy hedgedoc (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-compose-down: ## Remove hedgedoc (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-compose-restart: ## Restart hedgedoc (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-compose-recreate: hedgedoc-compose-down hedgedoc-compose-up ## Recreate hedgedoc (compose)
hedgedoc-compose-logs: ## Show hedgedoc compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(HEDGEDOC_STACK_NAME)
hedgedoc-compose-watch-logs: ## Watch hedgedoc compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(HEDGEDOC_STACK_NAME)
