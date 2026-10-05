## —— 🐝 Huly commands ———————————————————————————————————
HULY_STACK_NAME := huly
HULY_SERVICES_SHORT := front account transactor collaborator workspace fulltext stats rekoni kvs stream datalake media
HULY_ENV := $(HULY_STACK_NAME)/.env
HULY_ENV_EXAMPLE := $(HULY_STACK_NAME)/.env.example
HULY_SECRET_VARS := HULY_SECRET
HULY_NOTIFY_VARS := HULY_DOMAIN HULY_PUBLIC_URL HULY_CR_DB_URL HULY_STORAGE_CONFIG HULY_QUEUE_CONFIG HULY_ELASTIC_URL HULY_FULLTEXT_DB_URL
NETWORK_DRIVER ?= overlay

huly-pull-images: ## Pull images for the huly stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(HULY_STACK_NAME)
huly-setup: ## Ensure huly/.env, generate secrets, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(HULY_ENV)'; \
	exf='$(HULY_ENV_EXAMPLE)'; \
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
			HULY_SECRET) printf '%s' '$(HULY_SECRET)' ;; \
			HULY_DOMAIN) printf '%s' '$(HULY_DOMAIN)' ;; \
			HULY_PUBLIC_URL) printf '%s' '$(HULY_PUBLIC_URL)' ;; \
			HULY_CR_DB_URL) printf '%s' '$(HULY_CR_DB_URL)' ;; \
			HULY_STORAGE_CONFIG) printf '%s' '$(HULY_STORAGE_CONFIG)' ;; \
			HULY_QUEUE_CONFIG) printf '%s' '$(HULY_QUEUE_CONFIG)' ;; \
			HULY_ELASTIC_URL) printf '%s' '$(HULY_ELASTIC_URL)' ;; \
			HULY_FULLTEXT_DB_URL) printf '%s' '$(HULY_FULLTEXT_DB_URL)' ;; \
		esac; \
	}; \
	is_placeholder() { \
		case "$$1" in ""|ChangeMe|change-this-key-on-deployment|minioadmin) return 0 ;; *) return 1 ;; esac; \
	}; \
	for k in $(HULY_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if is_placeholder "$$v"; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k needs a value and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 32); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(HULY_NOTIFY_VARS); do \
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
			*example.com*|*ChangeMe*) \
				echo "Warning: $$k=$$v still uses a placeholder — set the real value in $$envf" >&2 ;; \
		esac; \
	done; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='huly-network'; \
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
	echo "huly env OK ($$envf)."
.huly-setup: huly-setup
huly-stack-up: .huly-setup ## Deploy the huly stack
	$(MAKE) stack-deploy STACK_NAME=$(HULY_STACK_NAME)
huly-stack-down: ## Remove the huly stack
	$(MAKE) stack-rm STACK_NAME=$(HULY_STACK_NAME)
huly-stack-recreate: huly-stack-down huly-stack-up ## Recreate the huly stack
huly-stack-upgrade: ## Upgrade huly swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(HULY_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(HULY_STACK_NAME)
huly-stack-logs: ## Show logs of the huly stack
	$(MAKE) stack-logs STACK_NAME=$(HULY_STACK_NAME)
huly-stack-watch-logs: ## Watch logs of the huly stack
	$(MAKE) stack-watch-logs STACK_NAME=$(HULY_STACK_NAME)
huly-debug: ## Debug huly swarm stack
	@echo "--- docker stack services ($(HULY_STACK_NAME))"
	@$(DOCKER) stack services $(HULY_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(HULY_STACK_NAME))"
	@$(DOCKER) stack ps $(HULY_STACK_NAME) --no-trunc
huly-debug-logs: ## Tail recent logs for each huly service
	@for s in $(HULY_SERVICES_SHORT); do \
		echo "==================== $(HULY_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(HULY_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
huly-compose-up: ## Deploy huly (compose)
	@$(MAKE) huly-setup NETWORK_DRIVER=bridge
	$(MAKE) docker-project-up PROJECT_NAME=$(HULY_STACK_NAME)
huly-compose-down: ## Remove huly (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(HULY_STACK_NAME)
huly-compose-restart: ## Restart huly (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(HULY_STACK_NAME)
huly-compose-recreate: huly-compose-down huly-compose-up ## Recreate huly (compose)
huly-compose-logs: ## Show huly compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(HULY_STACK_NAME)
huly-compose-watch-logs: ## Watch huly compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(HULY_STACK_NAME)
