## —— 🐝 CockroachDB commands ———————————————————————————————————
COCKROACH_STACK_NAME := cockroach
COCKROACH_SERVICES_SHORT := cockroach
COCKROACH_ENV := $(COCKROACH_STACK_NAME)/.env
COCKROACH_ENV_EXAMPLE := $(COCKROACH_STACK_NAME)/.env.example
COCKROACH_SECRET_VARS := COCKROACH_PASSWORD
COCKROACH_NOTIFY_VARS := COCKROACH_DOMAIN COCKROACH_APP_URL
NETWORK_DRIVER ?= overlay

cockroach-pull-images: ## Pull images for the cockroach stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(COCKROACH_STACK_NAME)
cockroach-setup: ## Ensure cockroach/.env, generate password, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(COCKROACH_ENV)'; \
	exf='$(COCKROACH_ENV_EXAMPLE)'; \
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
			COCKROACH_PASSWORD) printf '%s' '$(COCKROACH_PASSWORD)' ;; \
			COCKROACH_DOMAIN) printf '%s' '$(COCKROACH_DOMAIN)' ;; \
			COCKROACH_APP_URL) printf '%s' '$(COCKROACH_APP_URL)' ;; \
		esac; \
	}; \
	is_placeholder() { \
		case "$$1" in ""|ChangeMe) return 0 ;; *) return 1 ;; esac; \
	}; \
	for k in $(COCKROACH_SECRET_VARS); do \
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
	for k in $(COCKROACH_NOTIFY_VARS); do \
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
	[ -n "$$net" ] || net='cockroach-network'; \
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
	echo "cockroach env OK ($$envf)."
.cockroach-setup: cockroach-setup
cockroach-stack-up: .cockroach-setup ## Deploy the cockroach stack
	$(MAKE) stack-deploy STACK_NAME=$(COCKROACH_STACK_NAME)
cockroach-stack-down: ## Remove the cockroach stack
	$(MAKE) stack-rm STACK_NAME=$(COCKROACH_STACK_NAME)
cockroach-stack-recreate: cockroach-stack-down cockroach-stack-up ## Recreate the cockroach stack
cockroach-stack-upgrade: ## Upgrade cockroach swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(COCKROACH_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(COCKROACH_STACK_NAME)
cockroach-stack-logs: ## Show logs of the cockroach stack
	$(MAKE) stack-logs STACK_NAME=$(COCKROACH_STACK_NAME)
cockroach-stack-watch-logs: ## Watch logs of the cockroach stack
	$(MAKE) stack-watch-logs STACK_NAME=$(COCKROACH_STACK_NAME)
cockroach-debug: ## Debug cockroach swarm stack
	@echo "--- docker stack services ($(COCKROACH_STACK_NAME))"
	@$(DOCKER) stack services $(COCKROACH_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(COCKROACH_STACK_NAME))"
	@$(DOCKER) stack ps $(COCKROACH_STACK_NAME) --no-trunc
cockroach-debug-logs: ## Tail recent logs for each cockroach service
	@for s in $(COCKROACH_SERVICES_SHORT); do \
		echo "==================== $(COCKROACH_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(COCKROACH_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
cockroach-compose-up: ## Deploy cockroach (compose)
	@$(MAKE) cockroach-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(COCKROACH_STACK_NAME)
cockroach-compose-down: ## Remove cockroach (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(COCKROACH_STACK_NAME)
cockroach-compose-restart: ## Restart cockroach (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(COCKROACH_STACK_NAME)
cockroach-compose-recreate: cockroach-compose-down cockroach-compose-up ## Recreate cockroach (compose)
cockroach-compose-logs: ## Show cockroach compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(COCKROACH_STACK_NAME)
cockroach-compose-watch-logs: ## Watch cockroach compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(COCKROACH_STACK_NAME)
