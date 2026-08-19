## —— 🐝 Meilisearch commands ———————————————————————————————————
MEILISEARCH_STACK_NAME := meilisearch
MEILISEARCH_SERVICES_SHORT := meilisearch
MEILISEARCH_ENV := $(MEILISEARCH_STACK_NAME)/.env
MEILISEARCH_ENV_EXAMPLE := $(MEILISEARCH_STACK_NAME)/.env.example
MEILISEARCH_SECRET_VARS := MEILISEARCH_MASTER_KEY
MEILISEARCH_NOTIFY_VARS := MEILISEARCH_DOMAIN MEILISEARCH_APP_URL

meilisearch-pull-images: ## Pull images for the meilisearch stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-setup: ## Ensure meilisearch/.env, generate master key, warn on example.com
	@set -e; \
	envf='$(MEILISEARCH_ENV)'; \
	exf='$(MEILISEARCH_ENV_EXAMPLE)'; \
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
			MEILISEARCH_MASTER_KEY) printf '%s' '$(MEILISEARCH_MASTER_KEY)' ;; \
			MEILISEARCH_DOMAIN) printf '%s' '$(MEILISEARCH_DOMAIN)' ;; \
			MEILISEARCH_APP_URL) printf '%s' '$(MEILISEARCH_APP_URL)' ;; \
		esac; \
	}; \
	for k in $(MEILISEARCH_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -base64 36 | tr -dc 'A-Za-z0-9'); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(MEILISEARCH_NOTIFY_VARS); do \
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
	echo "Meilisearch env OK ($$envf)."
.meilisearch-setup: meilisearch-setup
meilisearch-stack-up: .meilisearch-setup ## Deploy the meilisearch stack
	$(MAKE) stack-deploy STACK_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-stack-down: ## Remove the meilisearch stack
	$(MAKE) stack-rm STACK_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-stack-recreate: meilisearch-stack-down meilisearch-stack-up ## Recreate the meilisearch stack
meilisearch-stack-upgrade: ## Upgrade meilisearch swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(MEILISEARCH_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-stack-logs: ## Show logs of the meilisearch stack
	$(MAKE) stack-logs STACK_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-stack-watch-logs: ## Watch logs of the meilisearch stack
	$(MAKE) stack-watch-logs STACK_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-debug: ## Debug meilisearch swarm stack
	@echo "--- docker stack services ($(MEILISEARCH_STACK_NAME))"
	@$(DOCKER) stack services $(MEILISEARCH_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(MEILISEARCH_STACK_NAME))"
	@$(DOCKER) stack ps $(MEILISEARCH_STACK_NAME) --no-trunc
meilisearch-debug-logs: ## Tail recent logs for each meilisearch service
	@for s in $(MEILISEARCH_SERVICES_SHORT); do \
		echo "==================== $(MEILISEARCH_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(MEILISEARCH_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
meilisearch-compose-upgrade: ## Upgrade the meilisearch compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-compose-up: .meilisearch-setup ## Deploy meilisearch (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-compose-down: ## Remove meilisearch (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-compose-restart: ## Restart meilisearch (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-compose-recreate: meilisearch-compose-down meilisearch-compose-up ## Recreate meilisearch (compose)
meilisearch-compose-logs: ## Show meilisearch compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(MEILISEARCH_STACK_NAME)
meilisearch-compose-watch-logs: ## Watch meilisearch compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(MEILISEARCH_STACK_NAME)
