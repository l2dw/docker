## —— 🐝 Karakeep commands ———————————————————————————————————
KARAKEEP_STACK_NAME := karakeep
KARAKEEP_SERVICES_SHORT := karakeep-web karakeep-chrome
KARAKEEP_ENV := $(KARAKEEP_STACK_NAME)/.env
KARAKEEP_ENV_EXAMPLE := $(KARAKEEP_STACK_NAME)/.env.example
KARAKEEP_SECRET_VARS := KARAKEEP_NEXTAUTH_SECRET
KARAKEEP_NOTIFY_VARS := KARAKEEP_DOMAIN KARAKEEP_APP_URL KARAKEEP_NEXTAUTH_URL

karakeep-pull-images: ## Pull images for the karakeep stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(KARAKEEP_STACK_NAME)
karakeep-setup: ## Ensure karakeep/.env, generate secrets, warn on example.com / empty OpenAI
	@set -e; \
	envf='$(KARAKEEP_ENV)'; \
	exf='$(KARAKEEP_ENV_EXAMPLE)'; \
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
			KARAKEEP_NEXTAUTH_SECRET) printf '%s' '$(KARAKEEP_NEXTAUTH_SECRET)' ;; \
			KARAKEEP_DOMAIN) printf '%s' '$(KARAKEEP_DOMAIN)' ;; \
			KARAKEEP_APP_URL) printf '%s' '$(KARAKEEP_APP_URL)' ;; \
			KARAKEEP_NEXTAUTH_URL) printf '%s' '$(KARAKEEP_NEXTAUTH_URL)' ;; \
		esac; \
	}; \
	for k in $(KARAKEEP_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -base64 36 | tr -d '\n'); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(KARAKEEP_NOTIFY_VARS); do \
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
	oa=$$(file_get "$$envf" KARAKEEP_OPENAI_API_KEY); \
	[ -n "$$oa" ] || oa=$$(file_get "$$root" KARAKEEP_OPENAI_API_KEY); \
	if [ -z "$$oa" ]; then \
		echo "Warning: KARAKEEP_OPENAI_API_KEY is empty — automatic tagging is disabled until you set an OpenAI-compatible key." >&2; \
	fi; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "Karakeep env OK ($$envf)."
.karakeep-setup: karakeep-setup
karakeep-stack-up: .karakeep-setup ## Deploy the karakeep stack
	$(MAKE) stack-deploy STACK_NAME=$(KARAKEEP_STACK_NAME)
karakeep-stack-down: ## Remove the karakeep stack
	$(MAKE) stack-rm STACK_NAME=$(KARAKEEP_STACK_NAME)
karakeep-stack-recreate: karakeep-stack-down karakeep-stack-up ## Recreate the karakeep stack
karakeep-stack-upgrade: ## Upgrade karakeep swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(KARAKEEP_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(KARAKEEP_STACK_NAME)
karakeep-stack-logs: ## Show logs of the karakeep stack
	$(MAKE) stack-logs STACK_NAME=$(KARAKEEP_STACK_NAME)
karakeep-stack-watch-logs: ## Watch logs of the karakeep stack
	$(MAKE) stack-watch-logs STACK_NAME=$(KARAKEEP_STACK_NAME)
karakeep-debug: ## Debug karakeep swarm stack
	@echo "--- docker stack services ($(KARAKEEP_STACK_NAME))"
	@$(DOCKER) stack services $(KARAKEEP_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(KARAKEEP_STACK_NAME))"
	@$(DOCKER) stack ps $(KARAKEEP_STACK_NAME) --no-trunc
karakeep-debug-logs: ## Tail recent logs for each karakeep service
	@for s in $(KARAKEEP_SERVICES_SHORT); do \
		echo "==================== $(KARAKEEP_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(KARAKEEP_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
karakeep-compose-upgrade: ## Upgrade the karakeep compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(KARAKEEP_STACK_NAME)
karakeep-compose-up: .karakeep-setup ## Deploy karakeep (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(KARAKEEP_STACK_NAME)
karakeep-compose-down: ## Remove karakeep (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(KARAKEEP_STACK_NAME)
karakeep-compose-restart: ## Restart karakeep (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(KARAKEEP_STACK_NAME)
karakeep-compose-recreate: karakeep-compose-down karakeep-compose-up ## Recreate karakeep (compose)
karakeep-compose-logs: ## Show karakeep compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(KARAKEEP_STACK_NAME)
karakeep-compose-watch-logs: ## Watch karakeep compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(KARAKEEP_STACK_NAME)
