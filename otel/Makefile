## —— 🐝 OpenTelemetry commands ———————————————————————————————————
OPENTELEMETRY_STACK_NAME := otel
OPENTELEMETRY_SERVICES_SHORT := otel
OPENTELEMETRY_ENV := $(OPENTELEMETRY_STACK_NAME)/.env
OPENTELEMETRY_ENV_EXAMPLE := $(OPENTELEMETRY_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

otel-pull-images: ## Pull images for the otel stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(OPENTELEMETRY_STACK_NAME)
otel-setup: ## Ensure otel/.env and sync DEFAULT_NETWORK_EXTERNAL (true only for dokploy-network)
	@set -e; \
	envf='$(OPENTELEMETRY_ENV)'; exf='$(OPENTELEMETRY_ENV_EXAMPLE)'; root='$(ENV_FILE)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; echo "Created $$envf from .env.example"; fi; \
	upsert() { _f=$$1; _k=$$2; _v=$$3; \
		if [ ! -f "$$_f" ]; then printf '%s=%s\n' "$$_k" "$$_v" > "$$_f"; return; fi; \
		tmp=$$(mktemp); awk -v k="$$_k" -v v="$$_v" 'BEGIN{done=0} index($$0,k"=")==1 {print k"="v; done=1; next} {print} END{if(!done) print k"="v}' "$$_f" > "$$tmp" && mv "$$tmp" "$$_f"; }; \
	file_get() { [ -f "$$1" ] || return 0; sed -n "s/^$$2=//p" "$$1" | head -n 1; }; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net='otel-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	case "$$ext" in true) ;; *) if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then $(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); fi ;; esac; \
	echo "OpenTelemetry env OK ($$envf)."
.otel-setup: otel-setup
otel-stack-up: .otel-setup ## Deploy the otel stack
	$(MAKE) stack-deploy STACK_NAME=$(OPENTELEMETRY_STACK_NAME)
otel-stack-down: ## Remove the otel stack
	$(MAKE) stack-rm STACK_NAME=$(OPENTELEMETRY_STACK_NAME)
otel-stack-recreate: otel-stack-down otel-stack-up ## Recreate the otel stack
otel-stack-upgrade: ## Upgrade otel swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(OPENTELEMETRY_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(OPENTELEMETRY_STACK_NAME)
otel-stack-logs: ## Show logs of the otel stack
	$(MAKE) stack-logs STACK_NAME=$(OPENTELEMETRY_STACK_NAME)
otel-debug: ## Debug otel swarm stack
	@$(DOCKER) stack services $(OPENTELEMETRY_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@$(DOCKER) stack ps $(OPENTELEMETRY_STACK_NAME) --no-trunc
otel-debug-logs: ## Tail recent logs for each otel service
	@for s in $(OPENTELEMETRY_SERVICES_SHORT); do $(DOCKER) service logs "$(OPENTELEMETRY_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || true; done
otel-compose-up: .otel-setup ## Deploy otel (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(OPENTELEMETRY_STACK_NAME)
otel-compose-down: ## Remove otel (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(OPENTELEMETRY_STACK_NAME)
otel-compose-restart: ## Restart otel (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(OPENTELEMETRY_STACK_NAME)
otel-compose-logs: ## Show otel compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(OPENTELEMETRY_STACK_NAME)
