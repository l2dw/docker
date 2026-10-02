## —— 🐝 SIEM commands ———————————————————————————————————
SIEM_STACK_NAME := siem
SIEM_SERVICES_SHORT := cert-utils elasticsearch kibana
SIEM_ENV := $(SIEM_STACK_NAME)/.env
SIEM_ENV_EXAMPLE := $(SIEM_STACK_NAME)/.env.example
SIEM_SECRET_VARS := SIEM_ELASTIC_PASSWORD SIEM_KB_ELASTICSEARCH_PASSWORD SIEM_KB_ENCRYPTED_SAVED_OBJECTS_ENCRYPTION_KEY SIEM_KB_REPORTING_ENCRYPTION_KEY
NETWORK_DRIVER ?= overlay

siem-pull-images: ## Pull images for the siem stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(SIEM_STACK_NAME)
siem-setup: ## Ensure siem/.env, generate secrets, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(SIEM_ENV)'; \
	exf='$(SIEM_ENV_EXAMPLE)'; \
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
			SIEM_ELASTIC_PASSWORD) printf '%s' '$(SIEM_ELASTIC_PASSWORD)' ;; \
			SIEM_KB_ELASTICSEARCH_PASSWORD) printf '%s' '$(SIEM_KB_ELASTICSEARCH_PASSWORD)' ;; \
			SIEM_KB_ENCRYPTED_SAVED_OBJECTS_ENCRYPTION_KEY) printf '%s' '$(SIEM_KB_ENCRYPTED_SAVED_OBJECTS_ENCRYPTION_KEY)' ;; \
			SIEM_KB_REPORTING_ENCRYPTION_KEY) printf '%s' '$(SIEM_KB_REPORTING_ENCRYPTION_KEY)' ;; \
		esac; \
	}; \
	for k in $(SIEM_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
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
	[ -n "$$net" ] || net='siem-network'; \
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
	echo "siem env OK ($$envf)."
.siem-setup: siem-setup
siem-stack-up: .siem-setup ## Deploy the siem stack
	$(MAKE) stack-deploy STACK_NAME=$(SIEM_STACK_NAME)
siem-stack-down: ## Remove the siem stack
	$(MAKE) stack-rm STACK_NAME=$(SIEM_STACK_NAME)
siem-stack-recreate: siem-stack-down siem-stack-up ## Recreate the siem stack
siem-stack-upgrade: ## Upgrade siem swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(SIEM_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(SIEM_STACK_NAME)
siem-stack-logs: ## Show logs of the siem stack
	$(MAKE) stack-logs STACK_NAME=$(SIEM_STACK_NAME)
siem-stack-watch-logs: ## Watch logs of the siem stack
	$(MAKE) stack-watch-logs STACK_NAME=$(SIEM_STACK_NAME)
siem-debug: ## Debug siem swarm stack
	@echo "--- docker stack services ($(SIEM_STACK_NAME))"
	@$(DOCKER) stack services $(SIEM_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(SIEM_STACK_NAME))"
	@$(DOCKER) stack ps $(SIEM_STACK_NAME) --no-trunc
siem-debug-logs: ## Tail recent logs for each siem service
	@for s in $(SIEM_SERVICES_SHORT); do \
		echo "==================== $(SIEM_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(SIEM_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
siem-compose-upgrade: ## Upgrade the siem compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(SIEM_STACK_NAME)
siem-compose-up: ## Deploy siem (compose)
	@$(MAKE) siem-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(SIEM_STACK_NAME)
siem-compose-down: ## Remove siem (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(SIEM_STACK_NAME)
siem-compose-restart: ## Restart siem (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(SIEM_STACK_NAME)
siem-compose-recreate: siem-compose-down siem-compose-up ## Recreate siem (compose)
siem-compose-logs: ## Show siem compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(SIEM_STACK_NAME)
siem-compose-watch-logs: ## Watch siem compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(SIEM_STACK_NAME)
