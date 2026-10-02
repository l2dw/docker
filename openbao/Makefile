## —— 🐝 OpenBao commands ———————————————————————————————————
OPENBAO_STACK_NAME := openbao
OPENBAO_SERVICES_SHORT := openbao
OPENBAO_ENV := $(OPENBAO_STACK_NAME)/.env
OPENBAO_ENV_EXAMPLE := $(OPENBAO_STACK_NAME)/.env.example
OPENBAO_NOTIFY_VARS := OPENBAO_DOMAIN OPENBAO_APP_URL OPENBAO_API_ADDR
NETWORK_DRIVER ?= overlay

openbao-pull-images: ## Pull images for the openbao stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(OPENBAO_STACK_NAME)
openbao-setup: ## Ensure openbao/.env, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(OPENBAO_ENV)'; \
	exf='$(OPENBAO_ENV_EXAMPLE)'; \
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
			OPENBAO_DOMAIN) printf '%s' '$(OPENBAO_DOMAIN)' ;; \
			OPENBAO_APP_URL) printf '%s' '$(OPENBAO_APP_URL)' ;; \
			OPENBAO_API_ADDR) printf '%s' '$(OPENBAO_API_ADDR)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(OPENBAO_NOTIFY_VARS); do \
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
	[ -n "$$net" ] || net='openbao-network'; \
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
	echo "openbao env OK ($$envf)."
.openbao-setup: openbao-setup
openbao-stack-up: .openbao-setup ## Deploy the openbao stack
	$(MAKE) stack-deploy STACK_NAME=$(OPENBAO_STACK_NAME)
openbao-stack-down: ## Remove the openbao stack
	$(MAKE) stack-rm STACK_NAME=$(OPENBAO_STACK_NAME)
openbao-stack-recreate: openbao-stack-down openbao-stack-up ## Recreate the openbao stack
openbao-stack-upgrade: ## Upgrade openbao swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(OPENBAO_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(OPENBAO_STACK_NAME)
openbao-stack-logs: ## Show logs of the openbao stack
	$(MAKE) stack-logs STACK_NAME=$(OPENBAO_STACK_NAME)
openbao-stack-watch-logs: ## Watch logs of the openbao stack
	$(MAKE) stack-watch-logs STACK_NAME=$(OPENBAO_STACK_NAME)
openbao-debug: ## Debug openbao swarm stack
	@echo "--- docker stack services ($(OPENBAO_STACK_NAME))"
	@$(DOCKER) stack services $(OPENBAO_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(OPENBAO_STACK_NAME))"
	@$(DOCKER) stack ps $(OPENBAO_STACK_NAME) --no-trunc
openbao-debug-logs: ## Tail recent logs for each openbao service
	@for s in $(OPENBAO_SERVICES_SHORT); do \
		echo "==================== $(OPENBAO_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(OPENBAO_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
openbao-compose-up: ## Deploy openbao (compose)
	@$(MAKE) openbao-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(OPENBAO_STACK_NAME)
openbao-compose-down: ## Remove openbao (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(OPENBAO_STACK_NAME)
openbao-compose-restart: ## Restart openbao (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(OPENBAO_STACK_NAME)
openbao-compose-recreate: openbao-compose-down openbao-compose-up ## Recreate openbao (compose)
openbao-compose-logs: ## Show openbao compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(OPENBAO_STACK_NAME)
openbao-compose-watch-logs: ## Watch openbao compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(OPENBAO_STACK_NAME)
