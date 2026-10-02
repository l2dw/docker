## —— 🐝 Redpanda commands ———————————————————————————————————
REDPANDA_STACK_NAME := redpanda
REDPANDA_SERVICES_SHORT := redpanda console
REDPANDA_ENV := $(REDPANDA_STACK_NAME)/.env
REDPANDA_ENV_EXAMPLE := $(REDPANDA_STACK_NAME)/.env.example
REDPANDA_SECRET_VARS := REDPANDA_ADMIN_PASSWORD
REDPANDA_NOTIFY_VARS := REDPANDA_DOMAIN REDPANDA_APP_URL
NETWORK_DRIVER ?= overlay

redpanda-pull-images: ## Pull images for the redpanda stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(REDPANDA_STACK_NAME)
redpanda-setup: ## Ensure redpanda/.env, generate admin password, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(REDPANDA_ENV)'; \
	exf='$(REDPANDA_ENV_EXAMPLE)'; \
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
			REDPANDA_ADMIN_PASSWORD) printf '%s' '$(REDPANDA_ADMIN_PASSWORD)' ;; \
			REDPANDA_DOMAIN) printf '%s' '$(REDPANDA_DOMAIN)' ;; \
			REDPANDA_APP_URL) printf '%s' '$(REDPANDA_APP_URL)' ;; \
		esac; \
	}; \
	is_placeholder() { \
		case "$$1" in ""|ChangeMe) return 0 ;; *) return 1 ;; esac; \
	}; \
	for k in $(REDPANDA_SECRET_VARS); do \
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
	for k in $(REDPANDA_NOTIFY_VARS); do \
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
	[ -n "$$net" ] || net='redpanda-network'; \
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
	echo "redpanda env OK ($$envf)."
.redpanda-setup: redpanda-setup
redpanda-stack-up: .redpanda-setup ## Deploy the redpanda stack
	$(MAKE) stack-deploy STACK_NAME=$(REDPANDA_STACK_NAME)
redpanda-stack-down: ## Remove the redpanda stack
	$(MAKE) stack-rm STACK_NAME=$(REDPANDA_STACK_NAME)
redpanda-stack-recreate: redpanda-stack-down redpanda-stack-up ## Recreate the redpanda stack
redpanda-stack-upgrade: ## Upgrade redpanda swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(REDPANDA_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(REDPANDA_STACK_NAME)
redpanda-stack-logs: ## Show logs of the redpanda stack
	$(MAKE) stack-logs STACK_NAME=$(REDPANDA_STACK_NAME)
redpanda-stack-watch-logs: ## Watch logs of the redpanda stack
	$(MAKE) stack-watch-logs STACK_NAME=$(REDPANDA_STACK_NAME)
redpanda-debug: ## Debug redpanda swarm stack
	@echo "--- docker stack services ($(REDPANDA_STACK_NAME))"
	@$(DOCKER) stack services $(REDPANDA_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(REDPANDA_STACK_NAME))"
	@$(DOCKER) stack ps $(REDPANDA_STACK_NAME) --no-trunc
redpanda-debug-logs: ## Tail recent logs for each redpanda service
	@for s in $(REDPANDA_SERVICES_SHORT); do \
		echo "==================== $(REDPANDA_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(REDPANDA_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
redpanda-compose-up: ## Deploy redpanda (compose)
	@$(MAKE) redpanda-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(REDPANDA_STACK_NAME)
redpanda-compose-down: ## Remove redpanda (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(REDPANDA_STACK_NAME)
redpanda-compose-restart: ## Restart redpanda (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(REDPANDA_STACK_NAME)
redpanda-compose-recreate: redpanda-compose-down redpanda-compose-up ## Recreate redpanda (compose)
redpanda-compose-logs: ## Show redpanda compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(REDPANDA_STACK_NAME)
redpanda-compose-watch-logs: ## Watch redpanda compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(REDPANDA_STACK_NAME)
