## —— 🐝 Registry commands ———————————————————————————————————
REGISTRY_STACK_NAME := registry
REGISTRY_SERVICES_SHORT := registry
REGISTRY_ENV := $(REGISTRY_STACK_NAME)/.env
REGISTRY_ENV_EXAMPLE := $(REGISTRY_STACK_NAME)/.env.example
REGISTRY_SECRET_VARS := REGISTRY_HTTP_SECRET
REGISTRY_NOTIFY_VARS := REGISTRY_DOMAIN REGISTRY_APP_URL
REGISTRY_CRED_VARS := REGISTRY_USER_NAME REGISTRY_USER_PASS

registry-pull-images: ## Pull images for the registry stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(REGISTRY_STACK_NAME)

registry-setup: ## Ensure registry/.env, HTTP secret, warn on default password, sync network
	@set -e; \
	envf='$(REGISTRY_ENV)'; \
	exf='$(REGISTRY_ENV_EXAMPLE)'; \
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
			REGISTRY_HTTP_SECRET) printf '%s' '$(REGISTRY_HTTP_SECRET)' ;; \
			REGISTRY_DOMAIN) printf '%s' '$(REGISTRY_DOMAIN)' ;; \
			REGISTRY_APP_URL) printf '%s' '$(REGISTRY_APP_URL)' ;; \
			REGISTRY_USER_NAME) printf '%s' '$(REGISTRY_USER_NAME)' ;; \
			REGISTRY_USER_PASS) printf '%s' '$(REGISTRY_USER_PASS)' ;; \
		esac; \
	}; \
	for k in $(REGISTRY_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -base64 32 | tr -d '\n'); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	for k in $(REGISTRY_CRED_VARS); do \
		from_make=$$(make_get "$$k"); \
		v=$$from_make; \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			case $$k in \
				REGISTRY_USER_NAME) v=dockeradm ;; \
				REGISTRY_USER_PASS) v=ChangeMe ;; \
			esac; \
		fi; \
		if [ -n "$$from_make" ] || [ -z "$$(file_get "$$envf" "$$k")" ]; then \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
		fi; \
		if [ "$$k" = REGISTRY_USER_PASS ] && [ "$$v" = ChangeMe ]; then \
			echo "Warning: REGISTRY_USER_PASS=ChangeMe — set a real password in $$envf (htpasswd is built at container start)." >&2; \
		fi; \
	done; \
	missing=0; \
	for k in $(REGISTRY_NOTIFY_VARS); do \
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
	[ -n "$$net" ] || net='registry-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext (project .env only)"; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "Registry env OK ($$envf). Auth: REGISTRY_USER_* → htpasswd at container start (no host file)."

.registry-setup: registry-setup

registry-stack-up: .registry-setup ## Deploy the registry stack
	$(MAKE) stack-deploy STACK_NAME=$(REGISTRY_STACK_NAME)
registry-stack-down: ## Remove the registry stack
	$(MAKE) stack-rm STACK_NAME=$(REGISTRY_STACK_NAME)
registry-stack-recreate: registry-stack-down registry-stack-up ## Recreate the registry stack
registry-stack-upgrade: ## Upgrade registry swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(REGISTRY_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(REGISTRY_STACK_NAME)
registry-stack-logs: ## Show logs of the registry stack
	$(MAKE) stack-logs STACK_NAME=$(REGISTRY_STACK_NAME)
registry-stack-watch-logs: ## Watch logs of the registry stack
	$(MAKE) stack-watch-logs STACK_NAME=$(REGISTRY_STACK_NAME)
registry-debug: ## Debug registry swarm stack
	@echo "--- docker stack services ($(REGISTRY_STACK_NAME))"
	@$(DOCKER) stack services $(REGISTRY_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(REGISTRY_STACK_NAME))"
	@$(DOCKER) stack ps $(REGISTRY_STACK_NAME) --no-trunc
registry-debug-logs: ## Tail recent logs for each registry service
	@for s in $(REGISTRY_SERVICES_SHORT); do \
		echo "==================== $(REGISTRY_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(REGISTRY_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
registry-compose-upgrade: ## Upgrade the registry compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(REGISTRY_STACK_NAME)
registry-compose-up: .registry-setup ## Deploy registry (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(REGISTRY_STACK_NAME)
registry-compose-down: ## Remove registry (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(REGISTRY_STACK_NAME)
registry-compose-restart: ## Restart registry (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(REGISTRY_STACK_NAME)
registry-compose-recreate: registry-compose-down registry-compose-up ## Recreate registry (compose)
registry-compose-logs: ## Show logs of the registry compose project
	$(MAKE) docker-project-logs PROJECT_NAME=$(REGISTRY_STACK_NAME)
registry-compose-watch-logs: ## Watch logs of the registry compose project
	$(MAKE) docker-project-watch PROJECT_NAME=$(REGISTRY_STACK_NAME)
