## —— 🐝 Prometheus Agent commands ———————————————————————————————————
PROMETHEUS_AGENT_STACK_NAME := prometheus-agent
PROMETHEUS_AGENT_SERVICES_SHORT := prometheus-agent
PROMETHEUS_AGENT_ENV := $(PROMETHEUS_AGENT_STACK_NAME)/.env
PROMETHEUS_AGENT_ENV_EXAMPLE := $(PROMETHEUS_AGENT_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

prometheus-agent-pull-images: ## Pull images for the prometheus-agent stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-setup: ## Ensure prometheus-agent/.env, sync network EXTERNAL
	@set -e; \
	envf='$(PROMETHEUS_AGENT_ENV)'; \
	exf='$(PROMETHEUS_AGENT_ENV_EXAMPLE)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; echo "Created $$envf from .env.example"; fi; \
	file_get() { sed -n "s/^$${2}=//p" "$$1" | head -n 1; }; \
	upsert() { \
		tmp=$$(mktemp); \
		awk -v k="$$2" -v v="$$3" 'BEGIN{d=0} index($$0,k"=")==1 {print k"="v; d=1; next} {print} END{if(!d) print k"="v}' "$$1" > "$$tmp" && mv "$$tmp" "$$1"; \
	}; \
	url=$$(file_get "$$envf" PROMETHEUS_AGENT_REMOTE_WRITE_URL); \
	case "$$url" in ""|*example.com*) echo "Warning: set PROMETHEUS_AGENT_REMOTE_WRITE_URL in $$envf" >&2 ;; esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net='prometheus-agent-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	case "$$ext" in \
		true) ;; \
		*) if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then \
			$(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); echo "Created network $$net."; fi ;; \
	esac; \
	echo "prometheus-agent env OK ($$envf)."
.prometheus-agent-setup: prometheus-agent-setup
prometheus-agent-stack-up: .prometheus-agent-setup ## Deploy the prometheus-agent stack
	$(MAKE) stack-deploy STACK_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-stack-down: ## Remove the prometheus-agent stack
	$(MAKE) stack-rm STACK_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-stack-recreate: prometheus-agent-stack-down prometheus-agent-stack-up ## Recreate the prometheus-agent stack
prometheus-agent-stack-upgrade: ## Upgrade prometheus-agent swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-stack-logs: ## Show logs of the prometheus-agent stack
	$(MAKE) stack-logs STACK_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-stack-watch-logs: ## Watch logs of the prometheus-agent stack
	$(MAKE) stack-watch-logs STACK_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-debug: ## Debug prometheus-agent swarm stack
	@echo "--- docker stack services ($(PROMETHEUS_AGENT_STACK_NAME))"
	@$(DOCKER) stack services $(PROMETHEUS_AGENT_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(PROMETHEUS_AGENT_STACK_NAME))"
	@$(DOCKER) stack ps $(PROMETHEUS_AGENT_STACK_NAME) --no-trunc
prometheus-agent-debug-logs: ## Tail recent logs for each prometheus-agent service
	@for s in $(PROMETHEUS_AGENT_SERVICES_SHORT); do \
		echo "==================== $(PROMETHEUS_AGENT_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(PROMETHEUS_AGENT_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
prometheus-agent-compose-up: ## Deploy prometheus-agent (compose)
	@$(MAKE) prometheus-agent-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-compose-down: ## Remove prometheus-agent (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-compose-restart: ## Restart prometheus-agent (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-compose-recreate: prometheus-agent-compose-down prometheus-agent-compose-up ## Recreate prometheus-agent (compose)
prometheus-agent-compose-logs: ## Show prometheus-agent compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
prometheus-agent-compose-watch-logs: ## Watch prometheus-agent compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(PROMETHEUS_AGENT_STACK_NAME)
