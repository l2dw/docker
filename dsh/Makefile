## —— 🐝 DeepSeek Harness (dsh) commands ———————————————————————————————————
DSH_STACK_NAME := dsh
DSH_SERVICES_SHORT := dsh
DSH_ENV := $(DSH_STACK_NAME)/.env
DSH_ENV_EXAMPLE := $(DSH_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

dsh-pull-images: ## Pull images for the dsh stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(DSH_STACK_NAME)
dsh-setup: ## Ensure dsh/.env, warn placeholders, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(DSH_ENV)'; \
	exf='$(DSH_ENV_EXAMPLE)'; \
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
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='dsh-network'; \
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
	key=$$(file_get "$$envf" DSH_DEEPSEEK_API_KEY); \
	case "$$key" in \
		''|ChangeMe|sk-configure-me*|changeme) echo "WARN: set DSH_DEEPSEEK_API_KEY in $$envf (placeholder detected)." >&2 ;; \
	esac; \
	dom=$$(file_get "$$envf" DSH_DOMAIN); \
	case "$$dom" in \
		''|*.example.com|example.com) echo "WARN: set DSH_DOMAIN / DSH_TRUSTED_HOSTS / DSH_PUBLIC_URL for your host." >&2 ;; \
	esac; \
	echo "dsh env OK ($$envf)."
.dsh-setup: dsh-setup
dsh-stack-up: .dsh-setup ## Deploy the dsh stack
	$(MAKE) stack-deploy STACK_NAME=$(DSH_STACK_NAME)
dsh-stack-down: ## Remove the dsh stack
	$(MAKE) stack-rm STACK_NAME=$(DSH_STACK_NAME)
dsh-stack-recreate: dsh-stack-down dsh-stack-up ## Recreate the dsh stack
dsh-stack-upgrade: ## Upgrade dsh swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(DSH_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(DSH_STACK_NAME)
dsh-stack-logs: ## Show logs of the dsh stack
	$(MAKE) stack-logs STACK_NAME=$(DSH_STACK_NAME)
dsh-stack-watch-logs: ## Watch logs of the dsh stack
	$(MAKE) stack-watch-logs STACK_NAME=$(DSH_STACK_NAME)
dsh-debug: ## Debug dsh swarm stack
	@echo "--- docker stack services ($(DSH_STACK_NAME))"
	@$(DOCKER) stack services $(DSH_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(DSH_STACK_NAME))"
	@$(DOCKER) stack ps $(DSH_STACK_NAME) --no-trunc
dsh-debug-logs: ## Tail recent logs for each dsh service
	@for s in $(DSH_SERVICES_SHORT); do \
		echo "==================== $(DSH_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(DSH_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
dsh-compose-upgrade: ## Upgrade the dsh compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(DSH_STACK_NAME)
dsh-compose-up: .dsh-setup ## Deploy dsh (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(DSH_STACK_NAME)
dsh-compose-down: ## Remove dsh (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(DSH_STACK_NAME)
dsh-compose-restart: ## Restart dsh (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(DSH_STACK_NAME)
dsh-compose-recreate: dsh-compose-down dsh-compose-up ## Recreate dsh (compose)
dsh-compose-logs: ## Show dsh compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(DSH_STACK_NAME)
dsh-compose-watch-logs: ## Watch dsh compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(DSH_STACK_NAME)
