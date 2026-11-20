## —— 🐝 Elastic Agent commands ———————————————————————————————————
ELASTIC_AGENT_STACK_NAME := elastic-agent
ELASTIC_AGENT_SERVICES_SHORT := elastic-agent
ELASTIC_AGENT_ENV := $(ELASTIC_AGENT_STACK_NAME)/.env
ELASTIC_AGENT_ENV_EXAMPLE := $(ELASTIC_AGENT_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

elastic-agent-pull-images: ## Pull images for the elastic-agent stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-setup: ## Ensure elastic-agent/.env, sync network EXTERNAL
	@set -e; \
	envf='$(ELASTIC_AGENT_ENV)'; \
	exf='$(ELASTIC_AGENT_ENV_EXAMPLE)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; echo "Created $$envf from .env.example"; fi; \
	file_get() { sed -n "s/^$${2}=//p" "$$1" | head -n 1; }; \
	upsert() { \
		tmp=$$(mktemp); \
		awk -v k="$$2" -v v="$$3" 'BEGIN{d=0} index($$0,k"=")==1 {print k"="v; d=1; next} {print} END{if(!d) print k"="v}' "$$1" > "$$tmp" && mv "$$tmp" "$$1"; \
	}; \
	url=$$(file_get "$$envf" ELASTIC_AGENT_FLEET_URL); \
	case "$$url" in ""|*example.com*) echo "Warning: set ELASTIC_AGENT_FLEET_URL in $$envf" >&2 ;; esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net='elastic-agent-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	case "$$ext" in \
		true) ;; \
		*) if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then \
			$(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); echo "Created network $$net."; fi ;; \
	esac; \
	echo "elastic-agent env OK ($$envf)."
.elastic-agent-setup: elastic-agent-setup
elastic-agent-stack-up: .elastic-agent-setup ## Deploy the elastic-agent stack
	$(MAKE) stack-deploy STACK_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-stack-down: ## Remove the elastic-agent stack
	$(MAKE) stack-rm STACK_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-stack-recreate: elastic-agent-stack-down elastic-agent-stack-up ## Recreate the elastic-agent stack
elastic-agent-stack-upgrade: ## Upgrade elastic-agent swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(ELASTIC_AGENT_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-stack-logs: ## Show logs of the elastic-agent stack
	$(MAKE) stack-logs STACK_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-stack-watch-logs: ## Watch logs of the elastic-agent stack
	$(MAKE) stack-watch-logs STACK_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-debug: ## Debug elastic-agent swarm stack
	@echo "--- docker stack services ($(ELASTIC_AGENT_STACK_NAME))"
	@$(DOCKER) stack services $(ELASTIC_AGENT_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(ELASTIC_AGENT_STACK_NAME))"
	@$(DOCKER) stack ps $(ELASTIC_AGENT_STACK_NAME) --no-trunc
elastic-agent-debug-logs: ## Tail recent logs for each elastic-agent service
	@for s in $(ELASTIC_AGENT_SERVICES_SHORT); do \
		echo "==================== $(ELASTIC_AGENT_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(ELASTIC_AGENT_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
elastic-agent-compose-up: ## Deploy elastic-agent (compose)
	@$(MAKE) elastic-agent-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-compose-down: ## Remove elastic-agent (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-compose-restart: ## Restart elastic-agent (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-compose-recreate: elastic-agent-compose-down elastic-agent-compose-up ## Recreate elastic-agent (compose)
elastic-agent-compose-logs: ## Show elastic-agent compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(ELASTIC_AGENT_STACK_NAME)
elastic-agent-compose-watch-logs: ## Watch elastic-agent compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(ELASTIC_AGENT_STACK_NAME)
