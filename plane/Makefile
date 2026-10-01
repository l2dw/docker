## —— 🐝 Plane commands ———————————————————————————————————
PLANE_STACK_NAME := plane
PLANE_SERVICES_SHORT := web space admin live api worker beat-worker migrator
PLANE_ENV := $(PLANE_STACK_NAME)/.env
PLANE_ENV_EXAMPLE := $(PLANE_STACK_NAME)/.env.example
PLANE_SECRET_VARS := PLANE_SECRET_KEY PLANE_LIVE_SERVER_SECRET_KEY PLANE_AWS_SECRET_ACCESS_KEY
PLANE_NOTIFY_VARS := PLANE_DOMAIN PLANE_APP_URL PLANE_CORS_ALLOWED_ORIGINS PLANE_DATABASE_URL PLANE_REDIS_URL PLANE_AMQP_URL PLANE_S3_ENDPOINT_URL
NETWORK_DRIVER ?= overlay

plane-pull-images: ## Pull images for the plane stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(PLANE_STACK_NAME)
plane-setup: ## Ensure plane/.env, generate secrets, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(PLANE_ENV)'; \
	exf='$(PLANE_ENV_EXAMPLE)'; \
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
			PLANE_SECRET_KEY) printf '%s' '$(PLANE_SECRET_KEY)' ;; \
			PLANE_LIVE_SERVER_SECRET_KEY) printf '%s' '$(PLANE_LIVE_SERVER_SECRET_KEY)' ;; \
			PLANE_AWS_SECRET_ACCESS_KEY) printf '%s' '$(PLANE_AWS_SECRET_ACCESS_KEY)' ;; \
			PLANE_DOMAIN) printf '%s' '$(PLANE_DOMAIN)' ;; \
			PLANE_APP_URL) printf '%s' '$(PLANE_APP_URL)' ;; \
			PLANE_CORS_ALLOWED_ORIGINS) printf '%s' '$(PLANE_CORS_ALLOWED_ORIGINS)' ;; \
			PLANE_DATABASE_URL) printf '%s' '$(PLANE_DATABASE_URL)' ;; \
			PLANE_REDIS_URL) printf '%s' '$(PLANE_REDIS_URL)' ;; \
			PLANE_AMQP_URL) printf '%s' '$(PLANE_AMQP_URL)' ;; \
			PLANE_S3_ENDPOINT_URL) printf '%s' '$(PLANE_S3_ENDPOINT_URL)' ;; \
		esac; \
	}; \
	is_placeholder() { \
		case "$$1" in ""|ChangeMe|change-this-key-on-deployment|access-key) return 0 ;; *) return 1 ;; esac; \
	}; \
	for k in $(PLANE_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if is_placeholder "$$v"; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k needs a value and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 32); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(PLANE_NOTIFY_VARS); do \
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
			*example.com*|*ChangeMe*|*@postgres:*|*@redis:*|*@rabbitmq:*|*://minio:*) \
				echo "Warning: $$k=$$v still uses a placeholder — set the real external value in $$envf" >&2 ;; \
		esac; \
	done; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='plane-network'; \
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
	echo "plane env OK ($$envf)."
.plane-setup: plane-setup
plane-stack-up: .plane-setup ## Deploy the plane stack
	$(MAKE) stack-deploy STACK_NAME=$(PLANE_STACK_NAME)
plane-stack-down: ## Remove the plane stack
	$(MAKE) stack-rm STACK_NAME=$(PLANE_STACK_NAME)
plane-stack-recreate: plane-stack-down plane-stack-up ## Recreate the plane stack
plane-stack-upgrade: ## Upgrade plane swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(PLANE_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(PLANE_STACK_NAME)
plane-stack-logs: ## Show logs of the plane stack
	$(MAKE) stack-logs STACK_NAME=$(PLANE_STACK_NAME)
plane-stack-watch-logs: ## Watch logs of the plane stack
	$(MAKE) stack-watch-logs STACK_NAME=$(PLANE_STACK_NAME)
plane-debug: ## Debug plane swarm stack
	@echo "--- docker stack services ($(PLANE_STACK_NAME))"
	@$(DOCKER) stack services $(PLANE_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(PLANE_STACK_NAME))"
	@$(DOCKER) stack ps $(PLANE_STACK_NAME) --no-trunc
plane-debug-logs: ## Tail recent logs for each plane service
	@for s in $(PLANE_SERVICES_SHORT); do \
		echo "==================== $(PLANE_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(PLANE_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
plane-compose-up: ## Deploy plane (compose)
	@$(MAKE) plane-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(PLANE_STACK_NAME)
plane-compose-down: ## Remove plane (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(PLANE_STACK_NAME)
plane-compose-restart: ## Restart plane (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(PLANE_STACK_NAME)
plane-compose-recreate: plane-compose-down plane-compose-up ## Recreate plane (compose)
plane-compose-logs: ## Show plane compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(PLANE_STACK_NAME)
plane-compose-watch-logs: ## Watch plane compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(PLANE_STACK_NAME)
