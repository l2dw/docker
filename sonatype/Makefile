## —— 🐝 Sonatype commands ———————————————————————————————————
SONATYPE_STACK_NAME := sonatype
SONATYPE_SERVICES_SHORT := sonatype
SONATYPE_ENV := $(SONATYPE_STACK_NAME)/.env
SONATYPE_ENV_EXAMPLE := $(SONATYPE_STACK_NAME)/.env.example
SONATYPE_NOTIFY_VARS := SONATYPE_APP_URL SONATYPE_DOMAIN

sonatype-pull-images: ## Pull images for the sonatype stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(SONATYPE_STACK_NAME)
sonatype-setup: ## Ensure sonatype/.env, warn on DOMAIN/APP_URL
	@set -e; \
	envf='$(SONATYPE_ENV)'; \
	exf='$(SONATYPE_ENV_EXAMPLE)'; \
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
			SONATYPE_APP_URL) printf '%s' '$(SONATYPE_APP_URL)' ;; \
			SONATYPE_DOMAIN) printf '%s' '$(SONATYPE_DOMAIN)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(SONATYPE_NOTIFY_VARS); do \
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
	echo "Sonatype env OK ($$envf)."
.sonatype-setup: sonatype-setup
sonatype-stack-up: .sonatype-setup ## Deploy the sonatype stack
	$(MAKE) stack-deploy STACK_NAME=$(SONATYPE_STACK_NAME)
sonatype-stack-down: ## Remove the sonatype stack
	$(MAKE) stack-rm STACK_NAME=$(SONATYPE_STACK_NAME)
sonatype-stack-recreate: sonatype-stack-down sonatype-stack-up ## Recreate the sonatype stack
sonatype-stack-upgrade: ## Upgrade sonatype swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(SONATYPE_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(SONATYPE_STACK_NAME)
sonatype-stack-logs: ## Show logs of the sonatype stack
	$(MAKE) stack-logs STACK_NAME=$(SONATYPE_STACK_NAME)
sonatype-stack-watch-logs: ## Watch logs of the sonatype stack
	$(MAKE) stack-watch-logs STACK_NAME=$(SONATYPE_STACK_NAME)
sonatype-debug: ## Debug sonatype swarm stack
	@echo "--- docker stack services ($(SONATYPE_STACK_NAME))"
	@$(DOCKER) stack services $(SONATYPE_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(SONATYPE_STACK_NAME))"
	@$(DOCKER) stack ps $(SONATYPE_STACK_NAME) --no-trunc
sonatype-debug-logs: ## Tail recent logs for each sonatype service
	@for s in $(SONATYPE_SERVICES_SHORT); do \
		echo "==================== $(SONATYPE_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(SONATYPE_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
sonatype-compose-upgrade: ## Upgrade the sonatype compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(SONATYPE_STACK_NAME)
sonatype-compose-up: .sonatype-setup ## Deploy sonatype (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(SONATYPE_STACK_NAME)
sonatype-compose-down: ## Remove sonatype (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(SONATYPE_STACK_NAME)
sonatype-compose-restart: ## Restart sonatype (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(SONATYPE_STACK_NAME)
sonatype-compose-recreate: sonatype-compose-down sonatype-compose-up ## Recreate sonatype (compose)
sonatype-compose-logs: ## Show sonatype compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(SONATYPE_STACK_NAME)
sonatype-compose-watch-logs: ## Watch sonatype compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(SONATYPE_STACK_NAME)
