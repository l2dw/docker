## —— 🐝 Grafana commands ———————————————————————————————————
GRAFANA_STACK_NAME := grafana
GRAFANA_SERVICES_SHORT := grafana
GRAFANA_ENV := $(GRAFANA_STACK_NAME)/.env
GRAFANA_ENV_EXAMPLE := $(GRAFANA_STACK_NAME)/.env.example
GRAFANA_SECRET_VARS := GRAFANA_ADMIN_PASSWORD GRAFANA_SECRET_KEY
GRAFANA_NOTIFY_VARS := GRAFANA_DOMAIN GRAFANA_ROOT_URL
NETWORK_DRIVER ?= overlay

grafana-pull-images: ## Pull images for the grafana stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(GRAFANA_STACK_NAME)
grafana-setup: ## Ensure grafana/.env, generate missing admin password / secret key, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(GRAFANA_ENV)'; \
	exf='$(GRAFANA_ENV_EXAMPLE)'; \
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
	get() { _v=$$(file_get "$$envf" "$$1"); [ -n "$$_v" ] || _v=$$(file_get "$$root" "$$1"); printf '%s' "$$_v"; }; \
	net=$$(get DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='grafana-network'; \
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
	for k in $(GRAFANA_SECRET_VARS); do \
		v=$$(get "$$k"); \
		if [ -z "$$v" ]; then \
			command -v openssl >/dev/null 2>&1 || { echo "Error: $$k is empty and openssl is not available." >&2; exit 1; }; \
			case "$$k" in \
				GRAFANA_SECRET_KEY) v=$$(openssl rand -hex 32) ;; \
				*) v=$$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32) ;; \
			esac; \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	for k in $(GRAFANA_NOTIFY_VARS); do \
		v=$$(get "$$k"); \
		case "$$v" in \
			*example.com*) echo "Warning: $$k=$$v still uses example.com — set the real value in $$envf" >&2 ;; \
		esac; \
	done; \
	if [ "$$(get GRAFANA_DB_TYPE)" != sqlite3 ] && [ -z "$$(get GRAFANA_DB_PASSWORD)" ]; then \
		echo "Warning: GRAFANA_DB_TYPE=$$(get GRAFANA_DB_TYPE) but GRAFANA_DB_PASSWORD is empty." >&2; \
	fi; \
	echo "Grafana env OK ($$envf)."
.grafana-setup: grafana-setup
grafana-stack-up: .grafana-setup ## Deploy the grafana stack
	$(MAKE) stack-deploy STACK_NAME=$(GRAFANA_STACK_NAME)
grafana-stack-down: ## Remove the grafana stack
	$(MAKE) stack-rm STACK_NAME=$(GRAFANA_STACK_NAME)
grafana-stack-recreate: grafana-stack-down grafana-stack-up ## Recreate the grafana stack
grafana-stack-upgrade: ## Upgrade grafana swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(GRAFANA_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(GRAFANA_STACK_NAME)
grafana-stack-logs: ## Show logs of the grafana stack
	$(MAKE) stack-logs STACK_NAME=$(GRAFANA_STACK_NAME)
grafana-stack-watch-logs: ## Watch logs of the grafana stack
	$(MAKE) stack-watch-logs STACK_NAME=$(GRAFANA_STACK_NAME)
grafana-debug: ## Debug grafana swarm stack
	@echo "--- docker stack services ($(GRAFANA_STACK_NAME))"
	@$(DOCKER) stack services $(GRAFANA_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(GRAFANA_STACK_NAME))"
	@$(DOCKER) stack ps $(GRAFANA_STACK_NAME) --no-trunc
grafana-debug-logs: ## Tail recent logs for each grafana service
	@for s in $(GRAFANA_SERVICES_SHORT); do \
		echo "==================== $(GRAFANA_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(GRAFANA_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
grafana-compose-upgrade: ## Upgrade the grafana compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(GRAFANA_STACK_NAME)
grafana-compose-up: .grafana-setup ## Deploy grafana (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(GRAFANA_STACK_NAME)
grafana-compose-down: ## Remove grafana (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(GRAFANA_STACK_NAME)
grafana-compose-restart: ## Restart grafana (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(GRAFANA_STACK_NAME)
grafana-compose-recreate: grafana-compose-down grafana-compose-up ## Recreate grafana (compose)
grafana-compose-logs: ## Show grafana compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(GRAFANA_STACK_NAME)
grafana-compose-watch-logs: ## Watch grafana compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(GRAFANA_STACK_NAME)
