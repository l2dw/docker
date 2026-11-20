## —— 🐝 Jaeger commands ———————————————————————————————————
JAEGER_STACK_NAME := jaeger
JAEGER_SERVICES_SHORT := jaeger
JAEGER_ENV := $(JAEGER_STACK_NAME)/.env
JAEGER_ENV_EXAMPLE := $(JAEGER_STACK_NAME)/.env.example
JAEGER_NOTIFY_VARS := JAEGER_DOMAIN JAEGER_APP_URL
NETWORK_DRIVER ?= overlay

jaeger-pull-images: ## Pull images for the jaeger stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(JAEGER_STACK_NAME)
jaeger-setup: ## Ensure jaeger/.env, sync base path / network EXTERNAL
	@set -e; \
	envf='$(JAEGER_ENV)'; \
	exf='$(JAEGER_ENV_EXAMPLE)'; \
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
			JAEGER_DOMAIN) printf '%s' '$(JAEGER_DOMAIN)' ;; \
			JAEGER_APP_URL) printf '%s' '$(JAEGER_APP_URL)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(JAEGER_NOTIFY_VARS); do \
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
	bp=$$(file_get "$$envf" JAEGER_BASE_PATH); \
	[ -n "$$bp" ] || bp=$$(file_get "$$root" JAEGER_BASE_PATH); \
	if [ -z "$$bp" ]; then \
		upsert "$$envf" JAEGER_BASE_PATH /; \
		upsert "$$envf" JAEGER_MIDDLEWARES ""; \
		if [ -n "$$root" ]; then upsert "$$root" JAEGER_BASE_PATH /; upsert "$$root" JAEGER_MIDDLEWARES ""; fi; \
		echo "Empty JAEGER_BASE_PATH → / (Host-only) and cleared JAEGER_MIDDLEWARES."; \
	fi; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='jaeger-network'; \
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
	echo "jaeger env OK ($$envf)."
.jaeger-setup: jaeger-setup
jaeger-stack-up: .jaeger-setup ## Deploy the jaeger stack
	$(MAKE) stack-deploy STACK_NAME=$(JAEGER_STACK_NAME)
jaeger-stack-down: ## Remove the jaeger stack
	$(MAKE) stack-rm STACK_NAME=$(JAEGER_STACK_NAME)
jaeger-stack-recreate: jaeger-stack-down jaeger-stack-up ## Recreate the jaeger stack
jaeger-stack-upgrade: ## Upgrade jaeger swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(JAEGER_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(JAEGER_STACK_NAME)
jaeger-stack-logs: ## Show logs of the jaeger stack
	$(MAKE) stack-logs STACK_NAME=$(JAEGER_STACK_NAME)
jaeger-stack-watch-logs: ## Watch logs of the jaeger stack
	$(MAKE) stack-watch-logs STACK_NAME=$(JAEGER_STACK_NAME)
jaeger-debug: ## Debug jaeger swarm stack
	@echo "--- docker stack services ($(JAEGER_STACK_NAME))"
	@$(DOCKER) stack services $(JAEGER_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(JAEGER_STACK_NAME))"
	@$(DOCKER) stack ps $(JAEGER_STACK_NAME) --no-trunc
jaeger-debug-logs: ## Tail recent logs for each jaeger service
	@for s in $(JAEGER_SERVICES_SHORT); do \
		echo "==================== $(JAEGER_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(JAEGER_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
jaeger-compose-up: ## Deploy jaeger (compose)
	@$(MAKE) jaeger-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(JAEGER_STACK_NAME)
jaeger-compose-down: ## Remove jaeger (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(JAEGER_STACK_NAME)
jaeger-compose-restart: ## Restart jaeger (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(JAEGER_STACK_NAME)
jaeger-compose-recreate: jaeger-compose-down jaeger-compose-up ## Recreate jaeger (compose)
jaeger-compose-logs: ## Show jaeger compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(JAEGER_STACK_NAME)
jaeger-compose-watch-logs: ## Watch jaeger compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(JAEGER_STACK_NAME)
