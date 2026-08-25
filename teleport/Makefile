## —— 🐝 Teleport commands ———————————————————————————————————
TELEPORT_STACK_NAME := teleport
TELEPORT_SERVICES_SHORT := teleport
TELEPORT_ENV := $(TELEPORT_STACK_NAME)/.env
TELEPORT_ENV_EXAMPLE := $(TELEPORT_STACK_NAME)/.env.example
TELEPORT_CFG_EXAMPLE := $(TELEPORT_STACK_NAME)/config/teleport.yaml.example
TELEPORT_CFG := $(TELEPORT_STACK_NAME)/config/teleport.yaml
TELEPORT_NOTIFY_VARS := TELEPORT_APP_URL TELEPORT_DOMAIN

teleport-pull-images: ## Pull images for the teleport stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(TELEPORT_STACK_NAME)
teleport-setup: ## Ensure teleport/.env, render teleport.yaml, sync network
	@set -e; \
	envf='$(TELEPORT_ENV)'; \
	exf='$(TELEPORT_ENV_EXAMPLE)'; \
	root='$(ENV_FILE)'; \
	cfgex='$(TELEPORT_CFG_EXAMPLE)'; \
	cfg='$(TELEPORT_CFG)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$cfgex" ]; then echo "Error: missing $$cfgex" >&2; exit 1; fi; \
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
			TELEPORT_APP_URL) printf '%s' '$(TELEPORT_APP_URL)' ;; \
			TELEPORT_DOMAIN) printf '%s' '$(TELEPORT_DOMAIN)' ;; \
			TELEPORT_CLUSTER_NAME) printf '%s' '$(TELEPORT_CLUSTER_NAME)' ;; \
			TELEPORT_PUBLIC_ADDR) printf '%s' '$(TELEPORT_PUBLIC_ADDR)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(TELEPORT_NOTIFY_VARS); do \
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
	domain=$$(file_get "$$envf" TELEPORT_DOMAIN); \
	[ -n "$$domain" ] || domain=$$(file_get "$$root" TELEPORT_DOMAIN); \
	appurl=$$(file_get "$$envf" TELEPORT_APP_URL); \
	[ -n "$$appurl" ] || appurl=$$(file_get "$$root" TELEPORT_APP_URL); \
	apphost=$$(printf '%s' "$$appurl" | sed -E 's|^[a-zA-Z][a-zA-Z0-9+.-]*://||; s|/.*||; s|:.*||'); \
	case "$$domain" in \
		*example.com*) \
			if [ -n "$$apphost" ] && [ "$$apphost" != "$$domain" ]; then \
				echo "TELEPORT_DOMAIN=$$domain still example.com — syncing from APP_URL host $$apphost."; \
				domain="$$apphost"; \
				upsert "$$envf" TELEPORT_DOMAIN "$$domain"; \
				if [ -n "$$root" ]; then upsert "$$root" TELEPORT_DOMAIN "$$domain"; fi; \
			fi; \
			;; \
	esac; \
	if [ -n "$$apphost" ] && [ -n "$$domain" ] && [ "$$apphost" != "$$domain" ]; then \
		echo "Warning: TELEPORT_DOMAIN=$$domain differs from APP_URL host $$apphost — Traefik Host() uses DOMAIN." >&2; \
	fi; \
	cluster=$$(make_get TELEPORT_CLUSTER_NAME); \
	[ -n "$$cluster" ] || cluster=$$(file_get "$$envf" TELEPORT_CLUSTER_NAME); \
	[ -n "$$cluster" ] || cluster=$$(file_get "$$root" TELEPORT_CLUSTER_NAME); \
	[ -n "$$cluster" ] || cluster="$$domain"; \
	paddr=$$(make_get TELEPORT_PUBLIC_ADDR); \
	[ -n "$$paddr" ] || paddr=$$(file_get "$$envf" TELEPORT_PUBLIC_ADDR); \
	[ -n "$$paddr" ] || paddr=$$(file_get "$$root" TELEPORT_PUBLIC_ADDR); \
	[ -n "$$paddr" ] || paddr="$$domain:443"; \
	upsert "$$envf" TELEPORT_CLUSTER_NAME "$$cluster"; \
	upsert "$$envf" TELEPORT_PUBLIC_ADDR "$$paddr"; \
	if [ -n "$$root" ]; then \
		upsert "$$root" TELEPORT_CLUSTER_NAME "$$cluster"; \
		upsert "$$root" TELEPORT_PUBLIC_ADDR "$$paddr"; \
	fi; \
	python3 teleport/render-config.py "$$cfgex" "$$cfg" "$$cluster" "$$paddr"; \
	upsert "$$envf" TELEPORT_CONFIG_FILE "./config/teleport.yaml"; \
	if [ -n "$$root" ]; then upsert "$$root" TELEPORT_CONFIG_FILE "./config/teleport.yaml"; fi; \
	echo "Wrote $$cfg (cluster_name=$$cluster public_addr=$$paddr)."; \
	bp_set=0; \
	if grep -q '^TELEPORT_BASE_PATH=' "$$envf" 2>/dev/null; then \
		bp=$$(file_get "$$envf" TELEPORT_BASE_PATH); bp_set=1; \
	elif [ -n "$$root" ] && grep -q '^TELEPORT_BASE_PATH=' "$$root" 2>/dev/null; then \
		bp=$$(file_get "$$root" TELEPORT_BASE_PATH); bp_set=1; \
	fi; \
	[ "$$bp_set" -eq 1 ] || bp='/'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" TELEPORT_BASE_PATH "/"; \
			upsert "$$envf" TELEPORT_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then \
				upsert "$$root" TELEPORT_BASE_PATH "/"; \
				upsert "$$root" TELEPORT_MIDDLEWARES ""; \
			fi; \
			echo "TELEPORT_BASE_PATH=/ (Host-only; subpath unsupported)."; \
			;; \
		*) \
			echo "Warning: TELEPORT_BASE_PATH=$$bp — Teleport subpath deploy is unsupported; prefer / on a dedicated subdomain." >&2; \
			upsert "$$envf" TELEPORT_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then upsert "$$root" TELEPORT_MIDDLEWARES ""; fi; \
			;; \
	esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='teleport-network'; \
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
	echo "Teleport env OK ($$envf)."
.teleport-setup: teleport-setup
teleport-stack-up: .teleport-setup ## Deploy the teleport stack
	$(MAKE) stack-deploy STACK_NAME=$(TELEPORT_STACK_NAME)
teleport-stack-down: ## Remove the teleport stack
	$(MAKE) stack-rm STACK_NAME=$(TELEPORT_STACK_NAME)
teleport-stack-recreate: teleport-stack-down teleport-stack-up ## Recreate the teleport stack
teleport-stack-upgrade: ## Upgrade teleport swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(TELEPORT_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(TELEPORT_STACK_NAME)
teleport-stack-logs: ## Show logs of the teleport stack
	$(MAKE) stack-logs STACK_NAME=$(TELEPORT_STACK_NAME)
teleport-stack-watch-logs: ## Watch logs of the teleport stack
	$(MAKE) stack-watch-logs STACK_NAME=$(TELEPORT_STACK_NAME)
teleport-debug: ## Debug teleport swarm stack
	@echo "--- docker stack services ($(TELEPORT_STACK_NAME))"
	@$(DOCKER) stack services $(TELEPORT_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(TELEPORT_STACK_NAME))"
	@$(DOCKER) stack ps $(TELEPORT_STACK_NAME) --no-trunc
teleport-debug-logs: ## Tail recent logs for each teleport service
	@for s in $(TELEPORT_SERVICES_SHORT); do \
		echo "==================== $(TELEPORT_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(TELEPORT_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
teleport-compose-upgrade: ## Upgrade the teleport compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(TELEPORT_STACK_NAME)
teleport-compose-up: .teleport-setup ## Deploy teleport (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(TELEPORT_STACK_NAME)
teleport-compose-down: ## Remove teleport (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(TELEPORT_STACK_NAME)
teleport-compose-restart: ## Restart teleport (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(TELEPORT_STACK_NAME)
teleport-compose-recreate: teleport-compose-down teleport-compose-up ## Recreate teleport (compose)
teleport-compose-logs: ## Show teleport compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(TELEPORT_STACK_NAME)
teleport-compose-watch-logs: ## Watch teleport compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(TELEPORT_STACK_NAME)
