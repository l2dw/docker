## —— 🐝 Fleet Server commands ———————————————————————————————————
FLEET_SERVER_STACK_NAME := fleet-server
FLEET_SERVER_SERVICES_SHORT := fleet-server
FLEET_SERVER_ENV := $(FLEET_SERVER_STACK_NAME)/.env
FLEET_SERVER_ENV_EXAMPLE := $(FLEET_SERVER_STACK_NAME)/.env.example
FLEET_SERVER_NOTIFY_VARS := FLEET_SERVER_DOMAIN FLEET_SERVER_APP_URL
NETWORK_DRIVER ?= overlay

fleet-server-pull-images: ## Pull images for the fleet-server stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-setup: ## Ensure fleet-server/.env, sync base path / network EXTERNAL
	@set -e; \
	envf='$(FLEET_SERVER_ENV)'; \
	exf='$(FLEET_SERVER_ENV_EXAMPLE)'; \
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
			FLEET_SERVER_DOMAIN) printf '%s' '$(FLEET_SERVER_DOMAIN)' ;; \
			FLEET_SERVER_APP_URL) printf '%s' '$(FLEET_SERVER_APP_URL)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(FLEET_SERVER_NOTIFY_VARS); do \
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
	bp=$$(file_get "$$envf" FLEET_SERVER_BASE_PATH); \
	[ -n "$$bp" ] || bp=$$(file_get "$$root" FLEET_SERVER_BASE_PATH); \
	if [ -z "$$bp" ]; then \
		upsert "$$envf" FLEET_SERVER_BASE_PATH /; \
		upsert "$$envf" FLEET_SERVER_MIDDLEWARES ""; \
		if [ -n "$$root" ]; then upsert "$$root" FLEET_SERVER_BASE_PATH /; upsert "$$root" FLEET_SERVER_MIDDLEWARES ""; fi; \
		echo "Empty FLEET_SERVER_BASE_PATH → / (Host-only) and cleared FLEET_SERVER_MIDDLEWARES."; \
	fi; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='fleet-server-network'; \
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
	echo "fleet-server env OK ($$envf)."
.fleet-server-setup: fleet-server-setup
fleet-server-stack-up: .fleet-server-setup ## Deploy the fleet-server stack
	$(MAKE) stack-deploy STACK_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-stack-down: ## Remove the fleet-server stack
	$(MAKE) stack-rm STACK_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-stack-recreate: fleet-server-stack-down fleet-server-stack-up ## Recreate the fleet-server stack
fleet-server-stack-upgrade: ## Upgrade fleet-server swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(FLEET_SERVER_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-stack-logs: ## Show logs of the fleet-server stack
	$(MAKE) stack-logs STACK_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-stack-watch-logs: ## Watch logs of the fleet-server stack
	$(MAKE) stack-watch-logs STACK_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-debug: ## Debug fleet-server swarm stack
	@echo "--- docker stack services ($(FLEET_SERVER_STACK_NAME))"
	@$(DOCKER) stack services $(FLEET_SERVER_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(FLEET_SERVER_STACK_NAME))"
	@$(DOCKER) stack ps $(FLEET_SERVER_STACK_NAME) --no-trunc
fleet-server-debug-logs: ## Tail recent logs for each fleet-server service
	@for s in $(FLEET_SERVER_SERVICES_SHORT); do \
		echo "==================== $(FLEET_SERVER_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(FLEET_SERVER_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
fleet-server-compose-up: ## Deploy fleet-server (compose)
	@$(MAKE) fleet-server-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-compose-down: ## Remove fleet-server (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-compose-restart: ## Restart fleet-server (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-compose-recreate: fleet-server-compose-down fleet-server-compose-up ## Recreate fleet-server (compose)
fleet-server-compose-logs: ## Show fleet-server compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(FLEET_SERVER_STACK_NAME)
fleet-server-compose-watch-logs: ## Watch fleet-server compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(FLEET_SERVER_STACK_NAME)
