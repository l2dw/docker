## —— 🐝 homepage commands ———————————————————————————————————
HOMEPAGE_STACK_NAME := homepage
HOMEPAGE_SERVICES_SHORT := homepage
HOMEPAGE_ENV := $(HOMEPAGE_STACK_NAME)/.env
HOMEPAGE_ENV_EXAMPLE := $(HOMEPAGE_STACK_NAME)/.env.example
HOMEPAGE_NOTIFY_VARS := HOMEPAGE_DOMAIN HOMEPAGE_ALLOWED_HOSTS HOMEPAGE_APP_URL
NETWORK_DRIVER ?= overlay

homepage-pull-images: ## Pull images for the homepage stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(HOMEPAGE_STACK_NAME)
homepage-setup: ## Ensure homepage/.env, warn on domains, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(HOMEPAGE_ENV)'; \
	exf='$(HOMEPAGE_ENV_EXAMPLE)'; \
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
			HOMEPAGE_DOMAIN) printf '%s' '$(HOMEPAGE_DOMAIN)' ;; \
			HOMEPAGE_ALLOWED_HOSTS) printf '%s' '$(HOMEPAGE_ALLOWED_HOSTS)' ;; \
			HOMEPAGE_APP_URL) printf '%s' '$(HOMEPAGE_APP_URL)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(HOMEPAGE_NOTIFY_VARS); do \
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
	[ -n "$$net" ] || net='homepage-network'; \
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
	echo "homepage env OK ($$envf)."
.homepage-setup: homepage-setup
homepage-stack-up: .homepage-setup ## Deploy the homepage stack
	$(MAKE) stack-deploy STACK_NAME=$(HOMEPAGE_STACK_NAME)
homepage-stack-down: ## Remove the homepage stack
	$(MAKE) stack-rm STACK_NAME=$(HOMEPAGE_STACK_NAME)
homepage-stack-recreate: homepage-stack-down homepage-stack-up ## Recreate the homepage stack
homepage-stack-upgrade: ## Upgrade homepage swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(HOMEPAGE_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(HOMEPAGE_STACK_NAME)
homepage-stack-logs: ## Show logs of the homepage stack
	$(MAKE) stack-logs STACK_NAME=$(HOMEPAGE_STACK_NAME)
homepage-stack-watch-logs: ## Watch logs of the homepage stack
	$(MAKE) stack-watch-logs STACK_NAME=$(HOMEPAGE_STACK_NAME)
homepage-debug: ## Debug homepage swarm stack
	@echo "--- docker stack services ($(HOMEPAGE_STACK_NAME))"
	@$(DOCKER) stack services $(HOMEPAGE_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(HOMEPAGE_STACK_NAME))"
	@$(DOCKER) stack ps $(HOMEPAGE_STACK_NAME) --no-trunc
homepage-debug-logs: ## Tail recent logs for each homepage service
	@for s in $(HOMEPAGE_SERVICES_SHORT); do \
		echo "==================== $(HOMEPAGE_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(HOMEPAGE_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
homepage-compose-upgrade: ## Upgrade the homepage compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(HOMEPAGE_STACK_NAME)
homepage-compose-up: ## Deploy homepage (compose)
	@$(MAKE) homepage-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(HOMEPAGE_STACK_NAME)
homepage-compose-down: ## Remove homepage (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(HOMEPAGE_STACK_NAME)
homepage-compose-restart: ## Restart homepage (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(HOMEPAGE_STACK_NAME)
homepage-compose-recreate: homepage-compose-down homepage-compose-up ## Recreate homepage (compose)
homepage-compose-logs: ## Show homepage compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(HOMEPAGE_STACK_NAME)
homepage-compose-watch-logs: ## Watch homepage compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(HOMEPAGE_STACK_NAME)
# Alias kept for older muscle memory
homepage-stack-debug: homepage-debug
