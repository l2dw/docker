## —— 🐝 Kibana commands ———————————————————————————————————
KIBANA_STACK_NAME := kibana
KIBANA_SERVICES_SHORT := kibana
KIBANA_ENV := $(KIBANA_STACK_NAME)/.env
KIBANA_ENV_EXAMPLE := $(KIBANA_STACK_NAME)/.env.example
KIBANA_NOTIFY_VARS := KIBANA_DOMAIN KIBANA_APP_URL
NETWORK_DRIVER ?= overlay

kibana-pull-images: ## Pull images for the kibana stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(KIBANA_STACK_NAME)
kibana-setup: ## Ensure kibana/.env, sync base path / network EXTERNAL
	@set -e; \
	envf='$(KIBANA_ENV)'; \
	exf='$(KIBANA_ENV_EXAMPLE)'; \
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
			KIBANA_DOMAIN) printf '%s' '$(KIBANA_DOMAIN)' ;; \
			KIBANA_APP_URL) printf '%s' '$(KIBANA_APP_URL)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(KIBANA_NOTIFY_VARS); do \
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
	bp=$$(file_get "$$envf" KIBANA_BASE_PATH); \
	[ -n "$$bp" ] || bp=$$(file_get "$$root" KIBANA_BASE_PATH); \
	if [ -z "$$bp" ]; then \
		upsert "$$envf" KIBANA_BASE_PATH /; \
		upsert "$$envf" KIBANA_MIDDLEWARES ""; \
		if [ -n "$$root" ]; then upsert "$$root" KIBANA_BASE_PATH /; upsert "$$root" KIBANA_MIDDLEWARES ""; fi; \
		echo "Empty KIBANA_BASE_PATH → / (Host-only) and cleared KIBANA_MIDDLEWARES."; \
	fi; \
	for k in KIBANA_XPACK_SECURITY_ENCRYPTION_KEY KIBANA_XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTION_KEY KIBANA_XPACK_REPORTING_ENCRYPTION_KEY; do \
		v=$$(file_get "$$envf" "$$k"); \
		case "$$v" in ""|ChangeMe*) upsert "$$envf" "$$k" "$$(openssl rand -hex 32)"; echo "Generated $$k in $$envf (not displayed)." ;; esac; \
	done; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='kibana-network'; \
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
	echo "kibana env OK ($$envf)."
.kibana-setup: kibana-setup
kibana-stack-up: .kibana-setup ## Deploy the kibana stack
	$(MAKE) stack-deploy STACK_NAME=$(KIBANA_STACK_NAME)
kibana-stack-down: ## Remove the kibana stack
	$(MAKE) stack-rm STACK_NAME=$(KIBANA_STACK_NAME)
kibana-stack-recreate: kibana-stack-down kibana-stack-up ## Recreate the kibana stack
kibana-stack-upgrade: ## Upgrade kibana swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(KIBANA_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(KIBANA_STACK_NAME)
kibana-stack-logs: ## Show logs of the kibana stack
	$(MAKE) stack-logs STACK_NAME=$(KIBANA_STACK_NAME)
kibana-stack-watch-logs: ## Watch logs of the kibana stack
	$(MAKE) stack-watch-logs STACK_NAME=$(KIBANA_STACK_NAME)
kibana-debug: ## Debug kibana swarm stack
	@echo "--- docker stack services ($(KIBANA_STACK_NAME))"
	@$(DOCKER) stack services $(KIBANA_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(KIBANA_STACK_NAME))"
	@$(DOCKER) stack ps $(KIBANA_STACK_NAME) --no-trunc
kibana-debug-logs: ## Tail recent logs for each kibana service
	@for s in $(KIBANA_SERVICES_SHORT); do \
		echo "==================== $(KIBANA_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(KIBANA_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
kibana-compose-up: ## Deploy kibana (compose)
	@$(MAKE) kibana-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(KIBANA_STACK_NAME)
kibana-compose-down: ## Remove kibana (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(KIBANA_STACK_NAME)
kibana-compose-restart: ## Restart kibana (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(KIBANA_STACK_NAME)
kibana-compose-recreate: kibana-compose-down kibana-compose-up ## Recreate kibana (compose)
kibana-compose-logs: ## Show kibana compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(KIBANA_STACK_NAME)
kibana-compose-watch-logs: ## Watch kibana compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(KIBANA_STACK_NAME)
