## —— 🐝 Loki commands ———————————————————————————————————
LOKI_STACK_NAME := loki
LOKI_SERVICES_SHORT := loki
LOKI_ENV := $(LOKI_STACK_NAME)/.env
LOKI_ENV_EXAMPLE := $(LOKI_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

loki-pull-images: ## Pull images for the loki stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(LOKI_STACK_NAME)
loki-setup: ## Ensure loki/.env and sync DEFAULT_NETWORK_EXTERNAL (true only for dokploy-network)
	@set -e; \
	envf='$(LOKI_ENV)'; exf='$(LOKI_ENV_EXAMPLE)'; root='$(ENV_FILE)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; echo "Created $$envf from .env.example"; fi; \
	upsert() { _f=$$1; _k=$$2; _v=$$3; \
		if [ ! -f "$$_f" ]; then printf '%s=%s\n' "$$_k" "$$_v" > "$$_f"; return; fi; \
		tmp=$$(mktemp); awk -v k="$$_k" -v v="$$_v" 'BEGIN{done=0} index($$0,k"=")==1 {print k"="v; done=1; next} {print} END{if(!done) print k"="v}' "$$_f" > "$$tmp" && mv "$$tmp" "$$_f"; }; \
	file_get() { [ -f "$$1" ] || return 0; sed -n "s/^$$2=//p" "$$1" | head -n 1; }; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net='loki-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	case "$$ext" in true) ;; *) if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then $(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); fi ;; esac; \
	echo "Loki env OK ($$envf)."
.loki-setup: loki-setup
loki-stack-up: .loki-setup ## Deploy the loki stack
	$(MAKE) stack-deploy STACK_NAME=$(LOKI_STACK_NAME)
loki-stack-down: ## Remove the loki stack
	$(MAKE) stack-rm STACK_NAME=$(LOKI_STACK_NAME)
loki-stack-recreate: loki-stack-down loki-stack-up ## Recreate the loki stack
loki-stack-upgrade: ## Upgrade loki swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(LOKI_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(LOKI_STACK_NAME)
loki-stack-logs: ## Show logs of the loki stack
	$(MAKE) stack-logs STACK_NAME=$(LOKI_STACK_NAME)
loki-debug: ## Debug loki swarm stack
	@$(DOCKER) stack services $(LOKI_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@$(DOCKER) stack ps $(LOKI_STACK_NAME) --no-trunc
loki-debug-logs: ## Tail recent logs for each loki service
	@for s in $(LOKI_SERVICES_SHORT); do $(DOCKER) service logs "$(LOKI_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || true; done
loki-compose-up: .loki-setup ## Deploy loki (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(LOKI_STACK_NAME)
loki-compose-down: ## Remove loki (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(LOKI_STACK_NAME)
loki-compose-restart: ## Restart loki (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(LOKI_STACK_NAME)
loki-compose-logs: ## Show loki compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(LOKI_STACK_NAME)
