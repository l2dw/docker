## —— 🐝 mysql commands ———————————————————————————————————
MYSQL_STACK_NAME := mysql
MYSQL_SERVICES_SHORT := mysql
MYSQL_ENV := $(MYSQL_STACK_NAME)/.env
MYSQL_ENV_EXAMPLE := $(MYSQL_STACK_NAME)/.env.example
MYSQL_SECRET_VARS := MYSQL_ROOT_PASSWORD MYSQL_PASSWORD

mysql-pull-images: ## Pull images for the mysql stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(MYSQL_STACK_NAME)
mysql-setup: ## Ensure mysql/.env, generate DB passwords if empty, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(MYSQL_ENV)'; \
	exf='$(MYSQL_ENV_EXAMPLE)'; \
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
			MYSQL_ROOT_PASSWORD) printf '%s' '$(MYSQL_ROOT_PASSWORD)' ;; \
			MYSQL_PASSWORD) printf '%s' '$(MYSQL_PASSWORD)' ;; \
		esac; \
	}; \
	for k in $(MYSQL_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ] || [ "$$v" = ChangeMe ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 32); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='dokploy-network'; \
	case "$$net" in \
		''|dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "mysql env OK ($$envf)."
.mysql-setup: mysql-setup
mysql-stack-up: .mysql-setup ## Deploy the mysql stack
	$(MAKE) stack-deploy STACK_NAME=$(MYSQL_STACK_NAME)
mysql-stack-down: ## Remove the mysql stack
	$(MAKE) stack-rm STACK_NAME=$(MYSQL_STACK_NAME)
mysql-stack-recreate: mysql-stack-down mysql-stack-up ## Recreate the mysql stack
mysql-stack-upgrade: ## Upgrade mysql swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(MYSQL_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(MYSQL_STACK_NAME)
mysql-stack-logs: ## Show logs of the mysql stack
	$(MAKE) stack-logs STACK_NAME=$(MYSQL_STACK_NAME)
mysql-stack-watch-logs: ## Watch logs of the mysql stack
	$(MAKE) stack-watch-logs STACK_NAME=$(MYSQL_STACK_NAME)
mysql-debug: ## Debug mysql swarm stack
	@echo "--- docker stack services ($(MYSQL_STACK_NAME))"
	@$(DOCKER) stack services $(MYSQL_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(MYSQL_STACK_NAME))"
	@$(DOCKER) stack ps $(MYSQL_STACK_NAME) --no-trunc
mysql-debug-logs: ## Tail recent logs for each mysql service
	@for s in $(MYSQL_SERVICES_SHORT); do \
		echo "==================== $(MYSQL_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(MYSQL_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
mysql-compose-upgrade: ## Upgrade the mysql compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(MYSQL_STACK_NAME)
mysql-compose-up: .mysql-setup ## Deploy mysql (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(MYSQL_STACK_NAME)
mysql-compose-down: ## Remove mysql (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(MYSQL_STACK_NAME)
mysql-compose-restart: ## Restart mysql (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(MYSQL_STACK_NAME)
mysql-compose-recreate: mysql-compose-down mysql-compose-up ## Recreate mysql (compose)
mysql-compose-logs: ## Show mysql compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(MYSQL_STACK_NAME)
mysql-compose-watch-logs: ## Watch mysql compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(MYSQL_STACK_NAME)
