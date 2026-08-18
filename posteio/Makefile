## —— 🐝 posteio commands ———————————————————————————————————
POSTEIO_STACK_NAME := posteio
POSTEIO_SERVICES_SHORT := posteio
POSTEIO_ENV := $(POSTEIO_STACK_NAME)/.env
POSTEIO_ENV_EXAMPLE := $(POSTEIO_STACK_NAME)/.env.example
POSTEIO_NOTIFY_VARS := POSTEIO_HOSTNAME POSTEIO_DOMAIN POSTEIO_APP_URL

posteio-pull-images: ## Pull images for the posteio stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(POSTEIO_STACK_NAME)
posteio-setup: ## Ensure posteio/.env, warn on HOSTNAME/DOMAIN/APP_URL
	@set -e; \
	envf='$(POSTEIO_ENV)'; \
	exf='$(POSTEIO_ENV_EXAMPLE)'; \
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
			POSTEIO_HOSTNAME) printf '%s' '$(POSTEIO_HOSTNAME)' ;; \
			POSTEIO_DOMAIN) printf '%s' '$(POSTEIO_DOMAIN)' ;; \
			POSTEIO_APP_URL) printf '%s' '$(POSTEIO_APP_URL)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(POSTEIO_NOTIFY_VARS); do \
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
	echo "poste.io env OK ($$envf)."
.posteio-setup: posteio-setup
posteio-stack-up: .posteio-setup ## Deploy the posteio stack
	$(MAKE) stack-deploy STACK_NAME=$(POSTEIO_STACK_NAME)
posteio-stack-down: ## Remove the posteio stack
	$(MAKE) stack-rm STACK_NAME=$(POSTEIO_STACK_NAME)
posteio-stack-recreate: posteio-stack-down posteio-stack-up ## Recreate the posteio stack
posteio-stack-upgrade: ## Upgrade posteio swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(POSTEIO_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(POSTEIO_STACK_NAME)
posteio-stack-logs: ## Show logs of the posteio stack
	$(MAKE) stack-logs STACK_NAME=$(POSTEIO_STACK_NAME)
posteio-stack-watch-logs: ## Watch logs of the posteio stack
	$(MAKE) stack-watch-logs STACK_NAME=$(POSTEIO_STACK_NAME)
posteio-debug: ## Debug posteio swarm stack
	@echo "--- docker stack services ($(POSTEIO_STACK_NAME))"
	@$(DOCKER) stack services $(POSTEIO_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(POSTEIO_STACK_NAME))"
	@$(DOCKER) stack ps $(POSTEIO_STACK_NAME) --no-trunc
posteio-debug-logs: ## Tail recent logs for each posteio service
	@for s in $(POSTEIO_SERVICES_SHORT); do \
		echo "==================== $(POSTEIO_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(POSTEIO_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
posteio-compose-upgrade: ## Upgrade the posteio compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(POSTEIO_STACK_NAME)
posteio-compose-up: .posteio-setup ## Deploy posteio (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(POSTEIO_STACK_NAME)
posteio-compose-down: ## Remove posteio (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(POSTEIO_STACK_NAME)
posteio-compose-restart: ## Restart posteio (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(POSTEIO_STACK_NAME)
posteio-compose-recreate: posteio-compose-down posteio-compose-up ## Recreate posteio (compose)
posteio-compose-logs: ## Show posteio compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(POSTEIO_STACK_NAME)
posteio-compose-watch-logs: ## Watch posteio compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(POSTEIO_STACK_NAME)
