## —— 🐝 Portainer commands ———————————————————————————————————
PORTAINER_STACK_NAME := portainer
PORTAINER_SERVICES_SHORT := portainer
PORTAINER_ENV := $(PORTAINER_STACK_NAME)/.env
PORTAINER_ENV_EXAMPLE := $(PORTAINER_STACK_NAME)/.env.example
PORTAINER_NOTIFY_VARS := PORTAINER_APP_URL PORTAINER_DOMAIN

portainer-pull-images: ## Pull images for the portainer stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(PORTAINER_STACK_NAME)

portainer-setup: ## Ensure portainer/.env, sync strip middleware / network pairing
	@set -e; \
	envf='$(PORTAINER_ENV)'; \
	exf='$(PORTAINER_ENV_EXAMPLE)'; \
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
			PORTAINER_APP_URL) printf '%s' '$(PORTAINER_APP_URL)' ;; \
			PORTAINER_DOMAIN) printf '%s' '$(PORTAINER_DOMAIN)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(PORTAINER_NOTIFY_VARS); do \
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
	domain=$$(file_get "$$envf" PORTAINER_DOMAIN); \
	[ -n "$$domain" ] || domain=$$(file_get "$$root" PORTAINER_DOMAIN); \
	origins=$$(file_get "$$envf" PORTAINER_TRUSTED_ORIGINS); \
	[ -n "$$origins" ] || origins="$$domain"; \
	upsert "$$envf" PORTAINER_TRUSTED_ORIGINS "$$origins"; \
	if [ -n "$$root" ]; then upsert "$$root" PORTAINER_TRUSTED_ORIGINS "$$origins"; fi; \
	bp=$$(file_get "$$envf" PORTAINER_BASE_PATH); \
	[ -n "$$bp" ] || bp=$$(file_get "$$root" PORTAINER_BASE_PATH); \
	[ -n "$$bp" ] || bp='/portainer'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" PORTAINER_BASE_PATH "/"; \
			upsert "$$envf" PORTAINER_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then \
				upsert "$$root" PORTAINER_BASE_PATH "/"; \
				upsert "$$root" PORTAINER_MIDDLEWARES ""; \
			fi; \
			echo "PORTAINER_BASE_PATH=/ (Host-only; no stripPrefix)."; \
			;; \
		*) \
			mw=$$(file_get "$$envf" PORTAINER_MIDDLEWARES); \
			[ -n "$$mw" ] || mw='portainer-strip'; \
			upsert "$$envf" PORTAINER_BASE_PATH "$$bp"; \
			upsert "$$envf" PORTAINER_MIDDLEWARES "$$mw"; \
			if [ -n "$$root" ]; then \
				upsert "$$root" PORTAINER_BASE_PATH "$$bp"; \
				upsert "$$root" PORTAINER_MIDDLEWARES "$$mw"; \
			fi; \
			echo "PORTAINER_BASE_PATH=$$bp → PORTAINER_MIDDLEWARES=$$mw (Traefik must stripPrefix; --base-url set)."; \
			echo "If Dokploy sets APP_NAME, set PORTAINER_MIDDLEWARES=<APP_NAME>-strip to match."; \
			;; \
	esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='portainer-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext (project .env only)"; \
	echo "Portainer env OK ($$envf)."
.portainer-setup: portainer-setup

portainer-stack-up: .portainer-setup ## Deploy the portainer stack
	$(MAKE) stack-deploy STACK_NAME=$(PORTAINER_STACK_NAME)
portainer-stack-down: ## Remove the portainer stack
	$(MAKE) stack-rm STACK_NAME=$(PORTAINER_STACK_NAME)
portainer-stack-recreate: portainer-stack-down portainer-stack-up ## Recreate the portainer stack
portainer-stack-upgrade: ## Upgrade portainer swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(PORTAINER_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(PORTAINER_STACK_NAME)
portainer-stack-logs: ## Show logs of the portainer stack
	$(MAKE) stack-logs STACK_NAME=$(PORTAINER_STACK_NAME)
portainer-stack-watch-logs: ## Watch logs of the portainer stack
	$(MAKE) stack-watch-logs STACK_NAME=$(PORTAINER_STACK_NAME)

portainer-debug: ## Debug portainer swarm stack
	@echo "--- docker stack services ($(PORTAINER_STACK_NAME))"
	@$(DOCKER) stack services $(PORTAINER_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(PORTAINER_STACK_NAME))"
	@$(DOCKER) stack ps $(PORTAINER_STACK_NAME) --no-trunc
portainer-debug-logs: ## Tail recent logs for each portainer service
	@for s in $(PORTAINER_SERVICES_SHORT); do \
		echo "==================== $(PORTAINER_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(PORTAINER_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done

portainer-compose-up: .portainer-setup ## Deploy the portainer stack (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(PORTAINER_STACK_NAME)
portainer-compose-down: ## Remove the portainer compose project
	$(MAKE) docker-project-down PROJECT_NAME=$(PORTAINER_STACK_NAME)
portainer-compose-restart: ## Restart the portainer compose project
	$(MAKE) docker-project-restart PROJECT_NAME=$(PORTAINER_STACK_NAME)
portainer-compose-recreate: portainer-compose-down portainer-compose-up ## Recreate the portainer compose project
portainer-compose-logs: ## Show logs of the portainer compose project
	$(MAKE) docker-project-logs PROJECT_NAME=$(PORTAINER_STACK_NAME)
portainer-compose-watch-logs: ## Watch logs of the portainer compose project
	$(MAKE) docker-project-watch PROJECT_NAME=$(PORTAINER_STACK_NAME)
portainer-compose-upgrade: ## Upgrade the portainer compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(PORTAINER_STACK_NAME)
