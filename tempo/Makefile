## —— 🐝 Tempo commands ———————————————————————————————————
TEMPO_STACK_NAME := tempo
TEMPO_SERVICES_SHORT := tempo
TEMPO_ENV := $(TEMPO_STACK_NAME)/.env
TEMPO_ENV_EXAMPLE := $(TEMPO_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

tempo-pull-images: ## Pull images for the tempo stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(TEMPO_STACK_NAME)
tempo-setup: ## Ensure tempo/.env and sync DEFAULT_NETWORK_EXTERNAL (true only for dokploy-network)
	@set -e; \
	envf='$(TEMPO_ENV)'; exf='$(TEMPO_ENV_EXAMPLE)'; root='$(ENV_FILE)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; echo "Created $$envf from .env.example"; fi; \
	upsert() { _f=$$1; _k=$$2; _v=$$3; \
		if [ ! -f "$$_f" ]; then printf '%s=%s\n' "$$_k" "$$_v" > "$$_f"; return; fi; \
		tmp=$$(mktemp); awk -v k="$$_k" -v v="$$_v" 'BEGIN{done=0} index($$0,k"=")==1 {print k"="v; done=1; next} {print} END{if(!done) print k"="v}' "$$_f" > "$$tmp" && mv "$$tmp" "$$_f"; }; \
	file_get() { [ -f "$$1" ] || return 0; sed -n "s/^$$2=//p" "$$1" | head -n 1; }; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net='tempo-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	case "$$ext" in true) ;; *) if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then $(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); fi ;; esac; \
	echo "Tempo env OK ($$envf)."
.tempo-setup: tempo-setup
tempo-stack-up: .tempo-setup ## Deploy the tempo stack
	$(MAKE) stack-deploy STACK_NAME=$(TEMPO_STACK_NAME)
tempo-stack-down: ## Remove the tempo stack
	$(MAKE) stack-rm STACK_NAME=$(TEMPO_STACK_NAME)
tempo-stack-recreate: tempo-stack-down tempo-stack-up ## Recreate the tempo stack
tempo-stack-upgrade: ## Upgrade tempo swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(TEMPO_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(TEMPO_STACK_NAME)
tempo-stack-logs: ## Show logs of the tempo stack
	$(MAKE) stack-logs STACK_NAME=$(TEMPO_STACK_NAME)
tempo-debug: ## Debug tempo swarm stack
	@$(DOCKER) stack services $(TEMPO_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@$(DOCKER) stack ps $(TEMPO_STACK_NAME) --no-trunc
tempo-debug-logs: ## Tail recent logs for each tempo service
	@for s in $(TEMPO_SERVICES_SHORT); do $(DOCKER) service logs "$(TEMPO_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || true; done
tempo-compose-up: .tempo-setup ## Deploy tempo (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(TEMPO_STACK_NAME)
tempo-compose-down: ## Remove tempo (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(TEMPO_STACK_NAME)
tempo-compose-restart: ## Restart tempo (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(TEMPO_STACK_NAME)
tempo-compose-logs: ## Show tempo compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(TEMPO_STACK_NAME)
