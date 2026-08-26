## —— 🐝 Dokploy commands ———————————————————————————————————
DOKPLOY_STACK_NAME := dokploy
DOKPLOY_SERVICES_SHORT := dokploy postgresql redis traefik waf waf-dummy certs-dumper
DOKPLOY_ENV := $(INFRA_DIR)/dokploy/.env
DOKPLOY_ENV_EXAMPLE := $(INFRA_DIR)/dokploy/.env.example
NETWORK_DRIVER ?= overlay
DEFAULT_NETWORK_NAME ?= dokploy-network

dokploy-setup: ## Ensure dokploy/.env, sync DEFAULT_NETWORK_EXTERNAL, create network/volumes/dirs
	@set -e; \
	envf='$(DOKPLOY_ENV)'; \
	exf='$(DOKPLOY_ENV_EXAMPLE)'; \
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
	net="$$(file_get "$$envf" DEFAULT_NETWORK_NAME)"; \
	[ -n "$$net" ] || net="$(DEFAULT_NETWORK_NAME)"; \
	[ -n "$$net" ] || net='dokploy-network'; \
	if [ "$$net" = "dokploy-network" ]; then ext=true; else ext=false; fi; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ] && [ -f "$$root" ]; then \
		upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; \
		upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"
	@# Create network if it doesn't exist (name matches compose DEFAULT_NETWORK_NAME)
	@if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$(DEFAULT_NETWORK_NAME)"; then \
		$(DOCKER) network create "$(DEFAULT_NETWORK_NAME)" --driver $(NETWORK_DRIVER); \
	fi
	@# Create folder if it doesn't exist
	@if [ -n "$(DOKPLOY_POSTGRES_DATA_DIR)" ]; then mkdir -p "$(DOKPLOY_POSTGRES_DATA_DIR)"; fi
	@if [ -n "$(DOKPLOY_POSTGRES_LOGS_DIR)" ]; then mkdir -p "$(DOKPLOY_POSTGRES_LOGS_DIR)"; fi
	@if [ -n "$(DOKPLOY_REDIS_DATA_DIR)" ]; then mkdir -p "$(DOKPLOY_REDIS_DATA_DIR)"; fi
	@if [ -n "$(DOKPLOY_REDIS_LOGS_DIR)" ]; then mkdir -p "$(DOKPLOY_REDIS_LOGS_DIR)"; fi
	@if [ -n "$(DOKPLOY_DATA_DIR)" ]; then mkdir -p "$(DOKPLOY_DATA_DIR)"; fi
	@if [ -n "$(DOKPLOY_LOGS_DIR)" ]; then mkdir -p "$(DOKPLOY_LOGS_DIR)"; fi
	@if [ -n "$(DOKPLOY_TRAEFIK_CERTIFICATES_DIR)" ]; then mkdir -p "$(DOKPLOY_TRAEFIK_CERTIFICATES_DIR)"; fi
	@if [ -n "$(DOKPLOY_TRAEFIK_CONFIG_DIR)" ]; then mkdir -p "$(DOKPLOY_TRAEFIK_CONFIG_DIR)"; fi
	@if [ -n "$(DOKPLOY_TRAEFIK_RULES_DIR)" ]; then mkdir -p "$(DOKPLOY_TRAEFIK_RULES_DIR)"; fi
	@if [ -n "$(DOKPLOY_TRAEFIK_LOGS_DIR)" ]; then mkdir -p "$(DOKPLOY_TRAEFIK_LOGS_DIR)"; fi
	@if [ -n "$(DOKPLOY_WAF_LOGS_DIR)" ]; then mkdir -p "$(DOKPLOY_WAF_LOGS_DIR)"; fi
	@# Create volume if it doesn't exist
	@if [ "$(DOKPLOY_POSTGRES_DATA_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_POSTGRES_DATA_VOLUME_NAME:-dokploy-postgresql_data}"; then \
		$(DOCKER) volume create "${DOKPLOY_POSTGRES_DATA_VOLUME_NAME:-dokploy-postgresql_data}"; \
	fi
	@if [ "$(DOKPLOY_POSTGRES_LOGS_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_POSTGRES_LOGS_VOLUME_NAME:-dokploy-postgresql_logs}"; then \
		$(DOCKER) volume create "${DOKPLOY_POSTGRES_LOGS_VOLUME_NAME:-dokploy-postgresql_logs}"; \
	fi
	@if [ "$(DOKPLOY_REDIS_DATA_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_REDIS_DATA_VOLUME_NAME:-dokploy-redis_data}"; then \
		$(DOCKER) volume create "${DOKPLOY_REDIS_DATA_VOLUME_NAME:-dokploy-redis_data}"; \
	fi
	@if [ "$(DOKPLOY_REDIS_LOGS_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_REDIS_LOGS_VOLUME_NAME:-dokploy-redis_logs}"; then \
		$(DOCKER) volume create "${DOKPLOY_REDIS_LOGS_VOLUME_NAME:-dokploy-redis_logs}"; \
	fi
	@if [ "$(DOKPLOY_DATA_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_DATA_VOLUME_NAME:-dokploy-data}"; then \
		$(DOCKER) volume create "${DOKPLOY_DATA_VOLUME_NAME:-dokploy-data}"; \
	fi
	@if [ "$(DOKPLOY_LOGS_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_LOGS_VOLUME_NAME:-dokploy-logs}"; then \
		$(DOCKER) volume create "${DOKPLOY_LOGS_VOLUME_NAME:-dokploy-logs}"; \
	fi
	@if [ "$(DOKPLOY_TRAEFIK_CONFIG_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_TRAEFIK_CONFIG_VOLUME_NAME:-dokploy-traefik_config}"; then \
		$(DOCKER) volume create "${DOKPLOY_TRAEFIK_CONFIG_VOLUME_NAME:-dokploy-traefik_config}"; \
	fi
	@if [ "$(DOKPLOY_TRAEFIK_RULES_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_TRAEFIK_RULES_VOLUME_NAME:-dokploy-traefik_rules}"; then \
		$(DOCKER) volume create "${DOKPLOY_TRAEFIK_RULES_VOLUME_NAME:-dokploy-traefik_rules}"; \
	fi
	@if [ "$(DOKPLOY_TRAEFIK_LOGS_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_TRAEFIK_LOGS_VOLUME_NAME:-dokploy-traefik_logs}"; then \
		$(DOCKER) volume create "${DOKPLOY_TRAEFIK_LOGS_VOLUME_NAME:-dokploy-traefik_logs}"; \
	fi
	@if [ "$(DOKPLOY_TRAEFIK_CERTIFICATES_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_TRAEFIK_CERTIFICATES_VOLUME_NAME:-dokploy-traefik_certificates}"; then \
		$(DOCKER) volume create "${DOKPLOY_TRAEFIK_CERTIFICATES_VOLUME_NAME:-dokploy-traefik_certificates}"; \
	fi
	@if [ "$(DOKPLOY_WAF_LOGS_VOLUME_EXTERNAL)" = "true" ] && ! $(DOCKER) volume ls | grep -q "${DOKPLOY_WAF_LOGS_VOLUME_NAME:-dokploy-waf_logs}"; then \
		$(DOCKER) volume create "${DOKPLOY_WAF_LOGS_VOLUME_NAME:-dokploy-waf_logs}"; \
	fi
	@echo "Dokploy env OK ($(DOKPLOY_ENV))."

dokploy-show-setup: ## Show the dokploy setup
	@echo "================================================"
	@echo "POSTGRES"
	@echo "================================================"
	@echo "DOKPLOY_POSTGRES_DATA_VOLUME_NAME=$(DOKPLOY_POSTGRES_DATA_VOLUME_NAME)"
	@echo "DOKPLOY_POSTGRES_DATA_VOLUME_EXTERNAL=$(DOKPLOY_POSTGRES_DATA_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_POSTGRES_DATA_DIR=$(DOKPLOY_POSTGRES_DATA_DIR)"
	@echo "DOKPLOY_POSTGRES_LOGS_VOLUME_NAME=$(DOKPLOY_POSTGRES_LOGS_VOLUME_NAME)"
	@echo "DOKPLOY_POSTGRES_LOGS_VOLUME_EXTERNAL=$(DOKPLOY_POSTGRES_LOGS_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_POSTGRES_LOGS_DIR=$(DOKPLOY_POSTGRES_LOGS_DIR)"
	@echo "================================================"
	@echo "REDIS"
	@echo "================================================"
	@echo "DOKPLOY_REDIS_DATA_VOLUME_NAME=$(DOKPLOY_REDIS_DATA_VOLUME_NAME)"
	@echo "DOKPLOY_REDIS_DATA_VOLUME_EXTERNAL=$(DOKPLOY_REDIS_DATA_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_REDIS_DATA_DIR=$(DOKPLOY_REDIS_DATA_DIR)"
	@echo "DOKPLOY_REDIS_LOGS_VOLUME_NAME=$(DOKPLOY_REDIS_LOGS_VOLUME_NAME)"
	@echo "DOKPLOY_REDIS_LOGS_VOLUME_EXTERNAL=$(DOKPLOY_REDIS_LOGS_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_REDIS_LOGS_DIR=$(DOKPLOY_REDIS_LOGS_DIR)"
	@echo "================================================"
	@echo "DOKPLOY"
	@echo "================================================"
	@echo "DOKPLOY_DATA_VOLUME_NAME=$(DOKPLOY_DATA_VOLUME_NAME)"
	@echo "DOKPLOY_DATA_VOLUME_EXTERNAL=$(DOKPLOY_DATA_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_DATA_DIR=$(DOKPLOY_DATA_DIR)"
	@echo "DOKPLOY_LOGS_VOLUME_NAME=$(DOKPLOY_LOGS_VOLUME_NAME)"
	@echo "DOKPLOY_LOGS_VOLUME_EXTERNAL=$(DOKPLOY_LOGS_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_LOGS_DIR=$(DOKPLOY_LOGS_DIR)"
	@echo "================================================"
	@echo "TRAEFIK"
	@echo "================================================"
	@echo "DOKPLOY_TRAEFIK_CERTIFICATES_VOLUME_NAME=$(DOKPLOY_TRAEFIK_CERTIFICATES_VOLUME_NAME)"
	@echo "DOKPLOY_TRAEFIK_CERTIFICATES_VOLUME_EXTERNAL=$(DOKPLOY_TRAEFIK_CERTIFICATES_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_TRAEFIK_CERTIFICATES_DIR=$(DOKPLOY_TRAEFIK_CERTIFICATES_DIR)"
	@echo "DOKPLOY_TRAEFIK_CONFIG_VOLUME_NAME=$(DOKPLOY_TRAEFIK_CONFIG_VOLUME_NAME)"
	@echo "DOKPLOY_TRAEFIK_CONFIG_VOLUME_EXTERNAL=$(DOKPLOY_TRAEFIK_CONFIG_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_TRAEFIK_CONFIG_DIR=$(DOKPLOY_TRAEFIK_CONFIG_DIR)"
	@echo "DOKPLOY_TRAEFIK_RULES_VOLUME_NAME=$(DOKPLOY_TRAEFIK_RULES_VOLUME_NAME)"
	@echo "DOKPLOY_TRAEFIK_RULES_VOLUME_EXTERNAL=$(DOKPLOY_TRAEFIK_RULES_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_TRAEFIK_RULES_DIR=$(DOKPLOY_TRAEFIK_RULES_DIR)"
	@echo "DOKPLOY_TRAEFIK_LOGS_VOLUME_NAME=$(DOKPLOY_TRAEFIK_LOGS_VOLUME_NAME)"
	@echo "DOKPLOY_TRAEFIK_LOGS_VOLUME_EXTERNAL=$(DOKPLOY_TRAEFIK_LOGS_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_TRAEFIK_LOGS_DIR=$(DOKPLOY_TRAEFIK_LOGS_DIR)"
	@echo "================================================"
	@echo "WAF"
	@echo "================================================"
	@echo "DOKPLOY_WAF_LOGS_VOLUME_NAME=$(DOKPLOY_WAF_LOGS_VOLUME_NAME)"
	@echo "DOKPLOY_WAF_LOGS_VOLUME_EXTERNAL=$(DOKPLOY_WAF_LOGS_VOLUME_EXTERNAL)"
	@echo "DOKPLOY_WAF_LOGS_DIR=$(DOKPLOY_WAF_LOGS_DIR)"
	@echo "================================================"

.dokploy-setup: ## dokploy-setup (overlay) + Swarm control-plane check
	@$(MAKE) dokploy-setup NETWORK_DRIVER=overlay
	@# Swarm stack deploy needs a manager control plane (ControlAvailable).
	@swarm_ctrl="$$($(DOCKER) info -f '{{.Swarm.ControlAvailable}}' 2>/dev/null)"; \
	swarm_state="$$($(DOCKER) info -f '{{.Swarm.LocalNodeState}}' 2>/dev/null)"; \
	if [ "$$swarm_ctrl" = "true" ]; then \
		exit 0; \
	elif [ "$$swarm_state" = "active" ]; then \
		exit 0; \
	else \
		echo "Swarm stack commands not available here (ControlAvailable=$$swarm_ctrl LocalNodeState=$$swarm_state)."; \
		echo "If another node shows Down / Unknown, fix or remove it: docker node ls && docker node rm"; \
		echo "Otherwise join/init: make swarm-init"; \
		exit 1; \
	fi

dokploy-pull-images: ## Pull images for the dokploy stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(DOKPLOY_STACK_NAME)

dokploy-stack-up: .dokploy-setup ## Deploy the dokploy stack
	$(MAKE) stack-deploy STACK_NAME=$(DOKPLOY_STACK_NAME)

dokploy-stack-down: ## Remove the dokploy stack
	$(MAKE) stack-rm STACK_NAME=$(DOKPLOY_STACK_NAME)

dokploy-stack-recreate: dokploy-stack-down dokploy-stack-up ## Recreate the dokploy stack

dokploy-stack-upgrade: ## Upgrade dokploy swarm images
	$(MAKE) docker-pull-images PROJECT_NAME=$(DOKPLOY_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(DOKPLOY_STACK_NAME)

dokploy-stack-logs: ## Show logs of the dokploy stack
	$(MAKE) stack-logs STACK_NAME=$(DOKPLOY_STACK_NAME)

dokploy-stack-watch-logs: ## Watch logs of the dokploy stack
	$(MAKE) stack-watch-logs STACK_NAME=$(DOKPLOY_STACK_NAME)

dokploy-debug: ## Debug dokploy swarm stack: services, tasks (states/errors), traefik ports
	@echo "--- docker stack services ($(DOKPLOY_STACK_NAME))"
	@$(DOCKER) stack services $(DOKPLOY_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker service ls ($(DOKPLOY_STACK_NAME)_*) ---"
	@$(DOCKER) service ls --filter label=com.docker.stack.namespace=$(DOKPLOY_STACK_NAME) 2>/dev/null \
		|| $(DOCKER) service ls | grep '$(DOKPLOY_STACK_NAME)_' \
		|| echo "(could not filter services)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(DOKPLOY_STACK_NAME))"
	@$(DOCKER) stack ps $(DOKPLOY_STACK_NAME) --no-trunc
	@echo
	@echo "--- traefik published ports ---"
	@$(DOCKER) service inspect $(DOKPLOY_STACK_NAME)_traefik --format '{{json .Endpoint.Ports}}' 2>/dev/null || echo "(no traefik service or inspect failed)"

dokploy-debug-logs: ## Tail recent logs for each dokploy service (e.g. services at 0/1)
	@for s in $(DOKPLOY_SERVICES_SHORT); do \
		echo "==================== $(DOKPLOY_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(DOKPLOY_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done

dokploy-compose-upgrade: ## Upgrade the dokploy compose project
	@$(MAKE) docker-project-upgrade PROJECT_NAME=$(DOKPLOY_STACK_NAME)

dokploy-compose-up: ## Deploy the dokploy stack (compose; bridge network)
	@$(MAKE) dokploy-setup NETWORK_DRIVER=bridge
	@$(MAKE) docker-project-up PROJECT_NAME=$(DOKPLOY_STACK_NAME)

dokploy-compose-down: ## Remove the dokploy stack
	@$(MAKE) docker-project-down PROJECT_NAME=$(DOKPLOY_STACK_NAME)

dokploy-compose-restart: ## Restart the dokploy stack
	@$(MAKE) docker-project-restart PROJECT_NAME=$(DOKPLOY_STACK_NAME)

dokploy-compose-recreate: dokploy-compose-down dokploy-compose-up ## Recreate the dokploy stack

dokploy-compose-logs: ## Show logs of the dokploy stack
	@$(MAKE) docker-project-logs PROJECT_NAME=$(DOKPLOY_STACK_NAME)

dokploy-compose-watch-logs: ## Watch logs of the dokploy stack
	@$(MAKE) docker-project-watch PROJECT_NAME=$(DOKPLOY_STACK_NAME)

dokploy-compose-status: ## Healthcheck the dokploy stack
	@$(BIN_DIR)/dokploy-compose-healthcheck.sh
