## —— 🐝 AdGuard commands ———————————————————————————————————
ADGUARD_STACK_NAME := adguard
ADGUARD_SERVICES_SHORT := adguard
ADGUARD_ENV := $(ADGUARD_STACK_NAME)/.env
ADGUARD_ENV_EXAMPLE := $(ADGUARD_STACK_NAME)/.env.example
ADGUARD_NOTIFY_VARS := ADGUARD_APP_URL ADGUARD_DOMAIN

adguard-pull-images: ## Pull images for the adguard stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(ADGUARD_STACK_NAME)
adguard-setup: ## Ensure adguard/.env, warn on DOMAIN/APP_URL
	@set -e; \
	envf='$(ADGUARD_ENV)'; \
	exf='$(ADGUARD_ENV_EXAMPLE)'; \
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
			ADGUARD_APP_URL) printf '%s' '$(ADGUARD_APP_URL)' ;; \
			ADGUARD_DOMAIN) printf '%s' '$(ADGUARD_DOMAIN)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(ADGUARD_NOTIFY_VARS); do \
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
	echo "AdGuard env OK ($$envf)."
.adguard-setup: adguard-setup
adguard-stack-up: .adguard-setup ## Deploy the adguard stack
	$(MAKE) stack-deploy STACK_NAME=$(ADGUARD_STACK_NAME)
adguard-stack-down: ## Remove the adguard stack
	$(MAKE) stack-rm STACK_NAME=$(ADGUARD_STACK_NAME)
adguard-stack-recreate: adguard-stack-down adguard-stack-up ## Recreate the adguard stack
adguard-stack-upgrade: ## Upgrade adguard swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(ADGUARD_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(ADGUARD_STACK_NAME)
adguard-stack-logs: ## Show logs of the adguard stack
	$(MAKE) stack-logs STACK_NAME=$(ADGUARD_STACK_NAME)
adguard-stack-watch-logs: ## Watch logs of the adguard stack
	$(MAKE) stack-watch-logs STACK_NAME=$(ADGUARD_STACK_NAME)
adguard-debug: ## Debug adguard swarm stack
	@echo "--- docker stack services ($(ADGUARD_STACK_NAME))"
	@$(DOCKER) stack services $(ADGUARD_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(ADGUARD_STACK_NAME))"
	@$(DOCKER) stack ps $(ADGUARD_STACK_NAME) --no-trunc
adguard-debug-logs: ## Tail recent logs for each adguard service
	@for s in $(ADGUARD_SERVICES_SHORT); do \
		echo "==================== $(ADGUARD_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(ADGUARD_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
adguard-compose-upgrade: ## Upgrade the adguard compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(ADGUARD_STACK_NAME)
adguard-compose-up: .adguard-setup ## Deploy adguard (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(ADGUARD_STACK_NAME)
adguard-compose-down: ## Remove adguard (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(ADGUARD_STACK_NAME)
adguard-compose-restart: ## Restart adguard (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(ADGUARD_STACK_NAME)
adguard-compose-recreate: adguard-compose-down adguard-compose-up ## Recreate adguard (compose)
adguard-compose-logs: ## Show adguard compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(ADGUARD_STACK_NAME)
adguard-compose-watch-logs: ## Watch adguard compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(ADGUARD_STACK_NAME)
