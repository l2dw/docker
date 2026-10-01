## —— 🐝 RabbitMQ commands ———————————————————————————————————
RABBITMQ_STACK_NAME := rabbitmq
RABBITMQ_SERVICES_SHORT := rabbitmq
RABBITMQ_ENV := $(RABBITMQ_STACK_NAME)/.env
RABBITMQ_ENV_EXAMPLE := $(RABBITMQ_STACK_NAME)/.env.example
RABBITMQ_SECRET_VARS := RABBITMQ_DEFAULT_PASS
RABBITMQ_NOTIFY_VARS := RABBITMQ_DOMAIN RABBITMQ_APP_URL
NETWORK_DRIVER ?= overlay

rabbitmq-pull-images: ## Pull images for the rabbitmq stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-setup: ## Ensure rabbitmq/.env, generate DEFAULT_PASS, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(RABBITMQ_ENV)'; \
	exf='$(RABBITMQ_ENV_EXAMPLE)'; \
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
			RABBITMQ_DEFAULT_PASS) printf '%s' '$(RABBITMQ_DEFAULT_PASS)' ;; \
			RABBITMQ_DOMAIN) printf '%s' '$(RABBITMQ_DOMAIN)' ;; \
			RABBITMQ_APP_URL) printf '%s' '$(RABBITMQ_APP_URL)' ;; \
		esac; \
	}; \
	is_placeholder() { \
		case "$$1" in ""|ChangeMe|guest) return 0 ;; *) return 1 ;; esac; \
	}; \
	for k in $(RABBITMQ_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if is_placeholder "$$v"; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k needs a value and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 24); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(RABBITMQ_NOTIFY_VARS); do \
		from_make=$$(make_get "$$k"); \
		v=$$from_make; \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			echo "Missing required $$k — set it in $$envf or pass $$k=... on the make command line." >&2; \
			missing=1; \
			continue; \
		fi; \
		if [ -n "$$from_make" ]; then \
			upsert "$$envf" "$$k" "$$from_make"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$from_make"; fi; \
			echo "Saved $$k → $$envf (and $$root)."; \
		fi; \
		case "$$v" in \
			*example.com*) echo "Warning: $$k=$$v still uses example.com — set the real value in $$envf" >&2 ;; \
		esac; \
	done; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='rabbitmq-network'; \
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
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "rabbitmq env OK ($$envf)."
.rabbitmq-setup: rabbitmq-setup
rabbitmq-stack-up: .rabbitmq-setup ## Deploy the rabbitmq stack
	$(MAKE) stack-deploy STACK_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-stack-down: ## Remove the rabbitmq stack
	$(MAKE) stack-rm STACK_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-stack-recreate: rabbitmq-stack-down rabbitmq-stack-up ## Recreate the rabbitmq stack
rabbitmq-stack-upgrade: ## Upgrade rabbitmq swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(RABBITMQ_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-stack-logs: ## Show logs of the rabbitmq stack
	$(MAKE) stack-logs STACK_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-stack-watch-logs: ## Watch logs of the rabbitmq stack
	$(MAKE) stack-watch-logs STACK_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-debug: ## Debug rabbitmq swarm stack
	@echo "--- docker stack services ($(RABBITMQ_STACK_NAME))"
	@$(DOCKER) stack services $(RABBITMQ_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(RABBITMQ_STACK_NAME))"
	@$(DOCKER) stack ps $(RABBITMQ_STACK_NAME) --no-trunc
rabbitmq-debug-logs: ## Tail recent logs for each rabbitmq service
	@for s in $(RABBITMQ_SERVICES_SHORT); do \
		echo "==================== $(RABBITMQ_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(RABBITMQ_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
rabbitmq-compose-up: ## Deploy rabbitmq (compose)
	@$(MAKE) rabbitmq-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-compose-down: ## Remove rabbitmq (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-compose-restart: ## Restart rabbitmq (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-compose-recreate: rabbitmq-compose-down rabbitmq-compose-up ## Recreate rabbitmq (compose)
rabbitmq-compose-logs: ## Show rabbitmq compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(RABBITMQ_STACK_NAME)
rabbitmq-compose-watch-logs: ## Watch rabbitmq compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(RABBITMQ_STACK_NAME)
