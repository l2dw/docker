## —— 🐝 Bugsink commands ———————————————————————————————————
BUGSINK_STACK_NAME := bugsink
BUGSINK_SERVICES_SHORT := bugsink
BUGSINK_ENV := $(BUGSINK_STACK_NAME)/.env
BUGSINK_ENV_EXAMPLE := $(BUGSINK_STACK_NAME)/.env.example
BUGSINK_SECRET_VARS := BUGSINK_SECRET_KEY
BUGSINK_NOTIFY_VARS := BUGSINK_DOMAIN BUGSINK_BASE_URL
NETWORK_DRIVER ?= overlay

bugsink-pull-images: ## Pull images for the bugsink stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(BUGSINK_STACK_NAME)
bugsink-setup: ## Ensure bugsink/.env, generate SECRET_KEY, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(BUGSINK_ENV)'; \
	exf='$(BUGSINK_ENV_EXAMPLE)'; \
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
			BUGSINK_SECRET_KEY) printf '%s' '$(BUGSINK_SECRET_KEY)' ;; \
			BUGSINK_DOMAIN) printf '%s' '$(BUGSINK_DOMAIN)' ;; \
			BUGSINK_BASE_URL) printf '%s' '$(BUGSINK_BASE_URL)' ;; \
		esac; \
	}; \
	for k in $(BUGSINK_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -base64 50); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(BUGSINK_NOTIFY_VARS); do \
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
	[ -n "$$net" ] || net='bugsink-network'; \
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
	case "$$ext" in \
		true) ;; \
		*) \
			if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then \
				$(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); \
				echo "Created network $$net (driver=$(NETWORK_DRIVER))."; \
			fi ;; \
	esac; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "Bugsink env OK ($$envf)."
.bugsink-setup: bugsink-setup
bugsink-stack-up: .bugsink-setup ## Deploy the bugsink stack
	$(MAKE) stack-deploy STACK_NAME=$(BUGSINK_STACK_NAME)
bugsink-stack-down: ## Remove the bugsink stack
	$(MAKE) stack-rm STACK_NAME=$(BUGSINK_STACK_NAME)
bugsink-stack-recreate: bugsink-stack-down bugsink-stack-up ## Recreate the bugsink stack
bugsink-stack-upgrade: ## Upgrade bugsink swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(BUGSINK_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(BUGSINK_STACK_NAME)
bugsink-stack-logs: ## Show logs of the bugsink stack
	$(MAKE) stack-logs STACK_NAME=$(BUGSINK_STACK_NAME)
bugsink-stack-watch-logs: ## Watch logs of the bugsink stack
	$(MAKE) stack-watch-logs STACK_NAME=$(BUGSINK_STACK_NAME)
bugsink-debug: ## Debug bugsink swarm stack
	@echo "--- docker stack services ($(BUGSINK_STACK_NAME))"
	@$(DOCKER) stack services $(BUGSINK_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(BUGSINK_STACK_NAME))"
	@$(DOCKER) stack ps $(BUGSINK_STACK_NAME) --no-trunc
bugsink-debug-logs: ## Tail recent logs for each bugsink service
	@for s in $(BUGSINK_SERVICES_SHORT); do \
		echo "==================== $(BUGSINK_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(BUGSINK_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
bugsink-compose-upgrade: ## Upgrade the bugsink compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(BUGSINK_STACK_NAME)
bugsink-compose-up: .bugsink-setup ## Deploy bugsink (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(BUGSINK_STACK_NAME)
bugsink-compose-down: ## Remove bugsink (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(BUGSINK_STACK_NAME)
bugsink-compose-restart: ## Restart bugsink (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(BUGSINK_STACK_NAME)
bugsink-compose-recreate: bugsink-compose-down bugsink-compose-up ## Recreate bugsink (compose)
bugsink-compose-logs: ## Show bugsink compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(BUGSINK_STACK_NAME)
bugsink-compose-watch-logs: ## Watch bugsink compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(BUGSINK_STACK_NAME)
