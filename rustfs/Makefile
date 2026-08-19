## —— 🐝 RustFS commands ———————————————————————————————————
RUSTFS_STACK_NAME := rustfs
RUSTFS_SERVICES_SHORT := rustfs
RUSTFS_ENV := $(RUSTFS_STACK_NAME)/.env
RUSTFS_ENV_EXAMPLE := $(RUSTFS_STACK_NAME)/.env.example
RUSTFS_SECRET_VARS := RUSTFS_ACCESS_KEY RUSTFS_SECRET_KEY
RUSTFS_NOTIFY_VARS := RUSTFS_S3_DOMAIN RUSTFS_CONSOLE_DOMAIN RUSTFS_S3_URL RUSTFS_CONSOLE_URL

rustfs-pull-images: ## Pull images for the rustfs stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(RUSTFS_STACK_NAME)
rustfs-setup: ## Ensure rustfs/.env, generate access keys, warn on example.com domains
	@set -e; \
	envf='$(RUSTFS_ENV)'; \
	exf='$(RUSTFS_ENV_EXAMPLE)'; \
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
			RUSTFS_ACCESS_KEY) printf '%s' '$(RUSTFS_ACCESS_KEY)' ;; \
			RUSTFS_SECRET_KEY) printf '%s' '$(RUSTFS_SECRET_KEY)' ;; \
			RUSTFS_S3_DOMAIN) printf '%s' '$(RUSTFS_S3_DOMAIN)' ;; \
			RUSTFS_CONSOLE_DOMAIN) printf '%s' '$(RUSTFS_CONSOLE_DOMAIN)' ;; \
			RUSTFS_S3_URL) printf '%s' '$(RUSTFS_S3_URL)' ;; \
			RUSTFS_CONSOLE_URL) printf '%s' '$(RUSTFS_CONSOLE_URL)' ;; \
		esac; \
	}; \
	for k in $(RUSTFS_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 20); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
		case "$$v" in \
			rustfsadmin) echo "Warning: $$k=rustfsadmin is the well-known default — rotate it in $$envf" >&2 ;; \
		esac; \
	done; \
	missing=0; \
	for k in $(RUSTFS_NOTIFY_VARS); do \
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
	[ -n "$$net" ] || net='dokploy-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "RustFS env OK ($$envf)."
.rustfs-setup: rustfs-setup
rustfs-stack-up: .rustfs-setup ## Deploy the rustfs stack
	$(MAKE) stack-deploy STACK_NAME=$(RUSTFS_STACK_NAME)
rustfs-stack-down: ## Remove the rustfs stack
	$(MAKE) stack-rm STACK_NAME=$(RUSTFS_STACK_NAME)
rustfs-stack-recreate: rustfs-stack-down rustfs-stack-up ## Recreate the rustfs stack
rustfs-stack-upgrade: ## Upgrade rustfs swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(RUSTFS_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(RUSTFS_STACK_NAME)
rustfs-stack-logs: ## Show logs of the rustfs stack
	$(MAKE) stack-logs STACK_NAME=$(RUSTFS_STACK_NAME)
rustfs-stack-watch-logs: ## Watch logs of the rustfs stack
	$(MAKE) stack-watch-logs STACK_NAME=$(RUSTFS_STACK_NAME)
rustfs-debug: ## Debug rustfs swarm stack
	@echo "--- docker stack services ($(RUSTFS_STACK_NAME))"
	@$(DOCKER) stack services $(RUSTFS_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(RUSTFS_STACK_NAME))"
	@$(DOCKER) stack ps $(RUSTFS_STACK_NAME) --no-trunc
rustfs-debug-logs: ## Tail recent logs for each rustfs service
	@for s in $(RUSTFS_SERVICES_SHORT); do \
		echo "==================== $(RUSTFS_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(RUSTFS_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
rustfs-compose-upgrade: ## Upgrade the rustfs compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(RUSTFS_STACK_NAME)
rustfs-compose-up: .rustfs-setup ## Deploy rustfs (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(RUSTFS_STACK_NAME)
rustfs-compose-down: ## Remove rustfs (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(RUSTFS_STACK_NAME)
rustfs-compose-restart: ## Restart rustfs (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(RUSTFS_STACK_NAME)
rustfs-compose-recreate: rustfs-compose-down rustfs-compose-up ## Recreate rustfs (compose)
rustfs-compose-logs: ## Show rustfs compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(RUSTFS_STACK_NAME)
rustfs-compose-watch-logs: ## Watch rustfs compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(RUSTFS_STACK_NAME)
