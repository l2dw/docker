## —— 🐝 Wallos commands ———————————————————————————————————
WALLOS_STACK_NAME := wallos
WALLOS_SERVICES_SHORT := wallos
WALLOS_ENV := $(WALLOS_STACK_NAME)/.env
WALLOS_ENV_EXAMPLE := $(WALLOS_STACK_NAME)/.env.example
WALLOS_NOTIFY_VARS := WALLOS_APP_URL WALLOS_DOMAIN

wallos-pull-images: ## Pull images for the wallos stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(WALLOS_STACK_NAME)
wallos-setup: ## Ensure wallos/.env, warn placeholders, sync network EXTERNAL
	@set -e; \
	envf='$(WALLOS_ENV)'; \
	exf='$(WALLOS_ENV_EXAMPLE)'; \
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
			WALLOS_APP_URL) printf '%s' '$(WALLOS_APP_URL)' ;; \
			WALLOS_DOMAIN) printf '%s' '$(WALLOS_DOMAIN)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(WALLOS_NOTIFY_VARS); do \
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
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	bp_set=0; \
	if grep -q '^WALLOS_BASE_PATH=' "$$envf" 2>/dev/null; then \
		bp=$$(file_get "$$envf" WALLOS_BASE_PATH); bp_set=1; \
	elif [ -n "$$root" ] && grep -q '^WALLOS_BASE_PATH=' "$$root" 2>/dev/null; then \
		bp=$$(file_get "$$root" WALLOS_BASE_PATH); bp_set=1; \
	fi; \
	[ "$$bp_set" -eq 1 ] || bp='/'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" WALLOS_BASE_PATH "/"; \
			upsert "$$envf" WALLOS_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then \
				upsert "$$root" WALLOS_BASE_PATH "/"; \
				upsert "$$root" WALLOS_MIDDLEWARES ""; \
			fi; \
			echo "WALLOS_BASE_PATH=/ (Host-only; subpath unsupported)."; \
			;; \
		*) \
			echo "Warning: WALLOS_BASE_PATH=$$bp — Wallos does not support a URL subpath; prefer / on a dedicated subdomain." >&2; \
			upsert "$$envf" WALLOS_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then upsert "$$root" WALLOS_MIDDLEWARES ""; fi; \
			;; \
	esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='wallos-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "Wallos env OK ($$envf)."
.wallos-setup: wallos-setup
wallos-stack-up: .wallos-setup ## Deploy the wallos stack
	$(MAKE) stack-deploy STACK_NAME=$(WALLOS_STACK_NAME)
wallos-stack-down: ## Remove the wallos stack
	$(MAKE) stack-rm STACK_NAME=$(WALLOS_STACK_NAME)
wallos-stack-recreate: wallos-stack-down wallos-stack-up ## Recreate the wallos stack
wallos-stack-upgrade: ## Upgrade wallos swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(WALLOS_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(WALLOS_STACK_NAME)
wallos-stack-logs: ## Show logs of the wallos stack
	$(MAKE) stack-logs STACK_NAME=$(WALLOS_STACK_NAME)
wallos-stack-watch-logs: ## Watch logs of the wallos stack
	$(MAKE) stack-watch-logs STACK_NAME=$(WALLOS_STACK_NAME)
wallos-debug: ## Debug wallos swarm stack
	@echo "--- docker stack services ($(WALLOS_STACK_NAME))"
	@$(DOCKER) stack services $(WALLOS_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(WALLOS_STACK_NAME))"
	@$(DOCKER) stack ps $(WALLOS_STACK_NAME) --no-trunc
wallos-debug-logs: ## Tail recent logs for each wallos service
	@for s in $(WALLOS_SERVICES_SHORT); do \
		echo "==================== $(WALLOS_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(WALLOS_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
wallos-compose-upgrade: ## Upgrade the wallos compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(WALLOS_STACK_NAME)
wallos-compose-up: .wallos-setup ## Deploy wallos (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(WALLOS_STACK_NAME)
wallos-compose-down: ## Remove wallos (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(WALLOS_STACK_NAME)
wallos-compose-restart: ## Restart wallos (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(WALLOS_STACK_NAME)
wallos-compose-recreate: wallos-compose-down wallos-compose-up ## Recreate wallos (compose)
wallos-compose-logs: ## Show wallos compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(WALLOS_STACK_NAME)
wallos-compose-watch-logs: ## Watch wallos compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(WALLOS_STACK_NAME)
