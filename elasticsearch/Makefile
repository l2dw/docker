## —— 🐝 elasticsearch commands ———————————————————————————————————
ELASTICSEARCH_STACK_NAME := elasticsearch
ELASTICSEARCH_SERVICES_SHORT := elasticsearch
ELASTICSEARCH_ENV := $(ELASTICSEARCH_STACK_NAME)/.env
ELASTICSEARCH_ENV_EXAMPLE := $(ELASTICSEARCH_STACK_NAME)/.env.example
ELASTICSEARCH_NOTIFY_VARS := ELASTICSEARCH_DOMAIN

elasticsearch-pull-images: ## Pull images for the elasticsearch stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-setup: ## Ensure elasticsearch/.env, warn on example.com, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(ELASTICSEARCH_ENV)'; \
	exf='$(ELASTICSEARCH_ENV_EXAMPLE)'; \
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
			ELASTICSEARCH_DOMAIN) printf '%s' '$(ELASTICSEARCH_DOMAIN)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(ELASTICSEARCH_NOTIFY_VARS); do \
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
	bp=$$(file_get "$$envf" ELASTICSEARCH_BASE_PATH); \
	[ -n "$$bp" ] || bp=$$(file_get "$$root" ELASTICSEARCH_BASE_PATH); \
	if [ -z "$$bp" ]; then \
		upsert "$$envf" ELASTICSEARCH_BASE_PATH /; \
		upsert "$$envf" ELASTICSEARCH_MIDDLEWARES ""; \
		if [ -n "$$root" ]; then upsert "$$root" ELASTICSEARCH_BASE_PATH /; upsert "$$root" ELASTICSEARCH_MIDDLEWARES ""; fi; \
		echo "Empty ELASTICSEARCH_BASE_PATH → / (Host-only) and cleared ELASTICSEARCH_MIDDLEWARES."; \
	fi; \
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
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "elasticsearch env OK ($$envf)."
.elasticsearch-setup: elasticsearch-setup
elasticsearch-stack-up: .elasticsearch-setup ## Deploy the elasticsearch stack
	$(MAKE) stack-deploy STACK_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-stack-down: ## Remove the elasticsearch stack
	$(MAKE) stack-rm STACK_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-stack-recreate: elasticsearch-stack-down elasticsearch-stack-up ## Recreate the elasticsearch stack
elasticsearch-stack-upgrade: ## Upgrade elasticsearch swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(ELASTICSEARCH_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-stack-logs: ## Show logs of the elasticsearch stack
	$(MAKE) stack-logs STACK_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-stack-watch-logs: ## Watch logs of the elasticsearch stack
	$(MAKE) stack-watch-logs STACK_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-debug: ## Debug elasticsearch swarm stack
	@echo "--- docker stack services ($(ELASTICSEARCH_STACK_NAME))"
	@$(DOCKER) stack services $(ELASTICSEARCH_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(ELASTICSEARCH_STACK_NAME))"
	@$(DOCKER) stack ps $(ELASTICSEARCH_STACK_NAME) --no-trunc
elasticsearch-debug-logs: ## Tail recent logs for each elasticsearch service
	@for s in $(ELASTICSEARCH_SERVICES_SHORT); do \
		echo "==================== $(ELASTICSEARCH_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(ELASTICSEARCH_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
elasticsearch-compose-upgrade: ## Upgrade the elasticsearch compose project
	$(MAKE) docker-pull-images PROJECT_NAME=$(ELASTICSEARCH_STACK_NAME)
	$(MAKE) docker-project-up PROJECT_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-compose-up: .elasticsearch-setup ## Deploy elasticsearch (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-compose-down: ## Remove elasticsearch (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-compose-restart: ## Restart elasticsearch (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-compose-recreate: elasticsearch-compose-down elasticsearch-compose-up ## Recreate elasticsearch (compose)
elasticsearch-compose-logs: ## Show elasticsearch compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(ELASTICSEARCH_STACK_NAME)
elasticsearch-compose-watch-logs: ## Watch elasticsearch compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(ELASTICSEARCH_STACK_NAME)
