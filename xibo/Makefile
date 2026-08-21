## —— 🐝 Xibo commands ———————————————————————————————————
XIBO_STACK_NAME := xibo
XIBO_SERVICES_SHORT := xibo xibo-xmr xibo-quickchart
XIBO_ENV := $(XIBO_STACK_NAME)/.env
XIBO_ENV_EXAMPLE := $(XIBO_STACK_NAME)/.env.example
XIBO_SECRET_VARS := XIBO_MYSQL_PASSWORD
XIBO_NOTIFY_VARS := XIBO_APP_URL XIBO_DOMAIN XIBO_CMS_SERVER_NAME XIBO_MYSQL_HOST XIBO_MEMCACHED_HOST

xibo-pull-images: ## Pull images for the xibo stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(XIBO_STACK_NAME)
xibo-setup: ## Ensure xibo/.env, generate MySQL password, sync CMS_ALIAS / network
	@set -e; \
	envf='$(XIBO_ENV)'; \
	exf='$(XIBO_ENV_EXAMPLE)'; \
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
			XIBO_MYSQL_PASSWORD) printf '%s' '$(XIBO_MYSQL_PASSWORD)' ;; \
			XIBO_APP_URL) printf '%s' '$(XIBO_APP_URL)' ;; \
			XIBO_DOMAIN) printf '%s' '$(XIBO_DOMAIN)' ;; \
			XIBO_CMS_SERVER_NAME) printf '%s' '$(XIBO_CMS_SERVER_NAME)' ;; \
			XIBO_MYSQL_HOST) printf '%s' '$(XIBO_MYSQL_HOST)' ;; \
			XIBO_MEMCACHED_HOST) printf '%s' '$(XIBO_MEMCACHED_HOST)' ;; \
		esac; \
	}; \
	for k in $(XIBO_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 16); \
			if [ -z "$$v" ]; then \
				echo "Error: failed to generate alphanumeric $$k" >&2; exit 1; \
			fi; \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k (alphanumeric) → $$envf (create matching MySQL user on external DB)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(XIBO_NOTIFY_VARS); do \
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
	# Preserve empty BASE_PATH (Host-only). Only default when the key is absent.
	bp_set=0; \
	if grep -q '^XIBO_BASE_PATH=' "$$envf" 2>/dev/null; then \
		bp=$$(file_get "$$envf" XIBO_BASE_PATH); bp_set=1; \
	elif [ -n "$$root" ] && grep -q '^XIBO_BASE_PATH=' "$$root" 2>/dev/null; then \
		bp=$$(file_get "$$root" XIBO_BASE_PATH); bp_set=1; \
	fi; \
	[ "$$bp_set" -eq 1 ] || bp='/xibo'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" XIBO_BASE_PATH "/"; \
			upsert "$$envf" XIBO_CMS_ALIAS ""; \
			upsert "$$envf" XIBO_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then \
				upsert "$$root" XIBO_BASE_PATH "/"; \
				upsert "$$root" XIBO_CMS_ALIAS ""; \
				upsert "$$root" XIBO_MIDDLEWARES ""; \
			fi; \
			echo "XIBO_BASE_PATH=/ (or empty) → Host-only; cleared CMS_ALIAS."; \
			;; \
		*) \
			upsert "$$envf" XIBO_CMS_ALIAS "$$bp"; \
			upsert "$$envf" XIBO_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then \
				upsert "$$root" XIBO_CMS_ALIAS "$$bp"; \
				upsert "$$root" XIBO_MIDDLEWARES ""; \
			fi; \
			echo "XIBO_CMS_ALIAS=$$bp (from BASE_PATH; no stripPrefix — CMS handles alias)."; \
			;; \
	esac; \
	server=$$(file_get "$$envf" XIBO_CMS_SERVER_NAME); \
	[ -n "$$server" ] || server=$$(file_get "$$envf" XIBO_DOMAIN); \
	[ -n "$$server" ] || server=$$(file_get "$$root" XIBO_DOMAIN); \
	if [ -n "$$server" ]; then \
		upsert "$$envf" XIBO_CMS_SERVER_NAME "$$server"; \
		if [ -n "$$root" ]; then upsert "$$root" XIBO_CMS_SERVER_NAME "$$server"; fi; \
	fi; \
	smtp=$$(file_get "$$envf" XIBO_CMS_SMTP_SERVER); \
	[ -n "$$smtp" ] || smtp=$$(file_get "$$root" XIBO_CMS_SMTP_SERVER); \
	if [ -z "$$smtp" ]; then \
		echo "Note: XIBO_CMS_SMTP_* empty — mail features need SMTP in $$envf."; \
	fi; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='xibo-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "Xibo env OK ($$envf)."
.xibo-setup: xibo-setup
xibo-stack-up: .xibo-setup ## Deploy the xibo stack
	$(MAKE) stack-deploy STACK_NAME=$(XIBO_STACK_NAME)
xibo-stack-down: ## Remove the xibo stack
	$(MAKE) stack-rm STACK_NAME=$(XIBO_STACK_NAME)
xibo-stack-recreate: xibo-stack-down xibo-stack-up ## Recreate the xibo stack
xibo-stack-upgrade: ## Upgrade xibo swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(XIBO_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(XIBO_STACK_NAME)
xibo-stack-logs: ## Show logs of the xibo stack
	$(MAKE) stack-logs STACK_NAME=$(XIBO_STACK_NAME)
xibo-stack-watch-logs: ## Watch logs of the xibo stack
	$(MAKE) stack-watch-logs STACK_NAME=$(XIBO_STACK_NAME)
xibo-debug: ## Debug xibo swarm stack
	@echo "--- docker stack services ($(XIBO_STACK_NAME))"
	@$(DOCKER) stack services $(XIBO_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(XIBO_STACK_NAME))"
	@$(DOCKER) stack ps $(XIBO_STACK_NAME) --no-trunc
xibo-debug-logs: ## Tail recent logs for each xibo service
	@for s in $(XIBO_SERVICES_SHORT); do \
		echo "==================== $(XIBO_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(XIBO_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
xibo-compose-upgrade: ## Upgrade the xibo compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(XIBO_STACK_NAME)
xibo-compose-up: .xibo-setup ## Deploy xibo (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(XIBO_STACK_NAME)
xibo-compose-down: ## Remove xibo (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(XIBO_STACK_NAME)
xibo-compose-restart: ## Restart xibo (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(XIBO_STACK_NAME)
xibo-compose-recreate: xibo-compose-down xibo-compose-up ## Recreate xibo (compose)
xibo-compose-logs: ## Show xibo compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(XIBO_STACK_NAME)
xibo-compose-watch-logs: ## Watch xibo compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(XIBO_STACK_NAME)
