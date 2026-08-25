## —— 🐝 Guacamole commands ———————————————————————————————————
GUACAMOLE_STACK_NAME := guacamole
GUACAMOLE_SERVICES_SHORT := guacamole guacamole-guacd
GUACAMOLE_ENV := $(GUACAMOLE_STACK_NAME)/.env
GUACAMOLE_ENV_EXAMPLE := $(GUACAMOLE_STACK_NAME)/.env.example
GUACAMOLE_SECRET_VARS := GUACAMOLE_POSTGRESQL_PASSWORD
GUACAMOLE_NOTIFY_VARS := GUACAMOLE_APP_URL GUACAMOLE_DOMAIN GUACAMOLE_POSTGRESQL_HOSTNAME

# Postgres Swarm service for create-db / schema init (empty = auto dokploy|infrastructure).
GUACAMOLE_PG_SERVICE ?=

guacamole-pull-images: ## Pull images for the guacamole stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(GUACAMOLE_STACK_NAME)

# Create role/DB (guacamole_user / guacamole_db) + load JDBC schema if missing.
guacamole-db-init: .guacamole-setup ## Create Postgres role/DB and Guacamole schema
	@set -e; \
	envf='$(GUACAMOLE_ENV)'; \
	file_get() { _f=$$1; _k=$$2; [ -f "$$_f" ] || return 0; sed -n "s/^$${_k}=//p" "$$_f" | head -n 1; }; \
	DB_USER=$$(file_get "$$envf" GUACAMOLE_POSTGRESQL_USERNAME); \
	DB_PASS=$$(file_get "$$envf" GUACAMOLE_POSTGRESQL_PASSWORD); \
	DB_NAME=$$(file_get "$$envf" GUACAMOLE_POSTGRESQL_DATABASE); \
	IMG=$$(file_get "$$envf" GUACAMOLE_IMAGE); \
	[ -n "$$DB_USER" ] || DB_USER=guacamole_user; \
	[ -n "$$DB_NAME" ] || DB_NAME=guacamole_db; \
	[ -n "$$DB_PASS" ] || { echo "Error: GUACAMOLE_POSTGRESQL_PASSWORD empty in $$envf" >&2; exit 1; }; \
	[ -n "$$IMG" ] || IMG=docker.io/guacamole/guacamole:1.6.0; \
	export DB_USER DB_PASS DB_NAME GUACAMOLE_IMAGE="$$IMG"; \
	if [ -n "$(GUACAMOLE_PG_SERVICE)" ]; then export PG_SERVICE="$(GUACAMOLE_PG_SERVICE)"; fi; \
	echo "guacamole-db-init: $$DB_USER / $$DB_NAME (PG_SERVICE=$${PG_SERVICE:-auto})"; \
	$(BIN_DIR)/create-db.sh; \
	$(BIN_DIR)/guacamole-init-schema.sh

guacamole-setup: ## Ensure guacamole/.env, generate DB password, sync WEBAPP_CONTEXT / network
	@set -e; \
	envf='$(GUACAMOLE_ENV)'; \
	exf='$(GUACAMOLE_ENV_EXAMPLE)'; \
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
			GUACAMOLE_POSTGRESQL_PASSWORD) printf '%s' '$(GUACAMOLE_POSTGRESQL_PASSWORD)' ;; \
			GUACAMOLE_APP_URL) printf '%s' '$(GUACAMOLE_APP_URL)' ;; \
			GUACAMOLE_DOMAIN) printf '%s' '$(GUACAMOLE_DOMAIN)' ;; \
			GUACAMOLE_POSTGRESQL_HOSTNAME) printf '%s' '$(GUACAMOLE_POSTGRESQL_HOSTNAME)' ;; \
		esac; \
	}; \
	for k in $(GUACAMOLE_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 24); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (run make guacamole-db-init to create the role)."; \
		fi; \
	done; \
	[ -n "$$(file_get "$$envf" GUACAMOLE_POSTGRESQL_USERNAME)" ] || upsert "$$envf" GUACAMOLE_POSTGRESQL_USERNAME "guacamole_user"; \
	[ -n "$$(file_get "$$envf" GUACAMOLE_POSTGRESQL_DATABASE)" ] || upsert "$$envf" GUACAMOLE_POSTGRESQL_DATABASE "guacamole_db"; \
	if [ -n "$$root" ]; then \
		upsert "$$root" GUACAMOLE_POSTGRESQL_USERNAME "$$(file_get "$$envf" GUACAMOLE_POSTGRESQL_USERNAME)"; \
		upsert "$$root" GUACAMOLE_POSTGRESQL_DATABASE "$$(file_get "$$envf" GUACAMOLE_POSTGRESQL_DATABASE)"; \
		upsert "$$root" GUACAMOLE_POSTGRESQL_PASSWORD "$$(file_get "$$envf" GUACAMOLE_POSTGRESQL_PASSWORD)"; \
	fi; \
	missing=0; \
	for k in $(GUACAMOLE_NOTIFY_VARS); do \
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
	if grep -q '^GUACAMOLE_BASE_PATH=' "$$envf" 2>/dev/null; then \
		bp=$$(file_get "$$envf" GUACAMOLE_BASE_PATH); bp_set=1; \
	elif [ -n "$$root" ] && grep -q '^GUACAMOLE_BASE_PATH=' "$$root" 2>/dev/null; then \
		bp=$$(file_get "$$root" GUACAMOLE_BASE_PATH); bp_set=1; \
	fi; \
	[ "$$bp_set" -eq 1 ] || bp='/guacamole'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" GUACAMOLE_BASE_PATH "/"; \
			upsert "$$envf" GUACAMOLE_WEBAPP_CONTEXT "ROOT"; \
			upsert "$$envf" GUACAMOLE_MIDDLEWARES ""; \
			upsert "$$envf" GUACAMOLE_HOMEPAGE_SITEMONITOR "http://guacamole:8080/"; \
			if [ -n "$$root" ]; then \
				upsert "$$root" GUACAMOLE_BASE_PATH "/"; \
				upsert "$$root" GUACAMOLE_WEBAPP_CONTEXT "ROOT"; \
				upsert "$$root" GUACAMOLE_MIDDLEWARES ""; \
				upsert "$$root" GUACAMOLE_HOMEPAGE_SITEMONITOR "http://guacamole:8080/"; \
			fi; \
			echo "GUACAMOLE_BASE_PATH=/ → WEBAPP_CONTEXT=ROOT (Host-only)."; \
			;; \
		*) \
			ctx=$$(printf '%s' "$$bp" | sed 's|^/||;s|/$$||'); \
			[ -n "$$ctx" ] || ctx='guacamole'; \
			upsert "$$envf" GUACAMOLE_WEBAPP_CONTEXT "$$ctx"; \
			upsert "$$envf" GUACAMOLE_MIDDLEWARES ""; \
			upsert "$$envf" GUACAMOLE_HOMEPAGE_SITEMONITOR "http://guacamole:8080/$$ctx/"; \
			if [ -n "$$root" ]; then \
				upsert "$$root" GUACAMOLE_WEBAPP_CONTEXT "$$ctx"; \
				upsert "$$root" GUACAMOLE_MIDDLEWARES ""; \
				upsert "$$root" GUACAMOLE_HOMEPAGE_SITEMONITOR "http://guacamole:8080/$$ctx/"; \
			fi; \
			echo "GUACAMOLE_WEBAPP_CONTEXT=$$ctx (from BASE_PATH=$$bp; no stripPrefix)."; \
			;; \
	esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='guacamole-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "Guacamole env OK ($$envf). Next: make guacamole-db-init (role+schema) then compose/stack up."
.guacamole-setup: guacamole-setup
guacamole-stack-up: guacamole-db-init ## Deploy the guacamole stack (DB init first)
	$(MAKE) stack-deploy STACK_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-stack-down: ## Remove the guacamole stack
	$(MAKE) stack-rm STACK_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-stack-recreate: guacamole-stack-down guacamole-stack-up ## Recreate the guacamole stack
guacamole-stack-upgrade: ## Upgrade guacamole swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(GUACAMOLE_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-stack-logs: ## Show logs of the guacamole stack
	$(MAKE) stack-logs STACK_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-stack-watch-logs: ## Watch logs of the guacamole stack
	$(MAKE) stack-watch-logs STACK_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-debug: ## Debug guacamole swarm stack
	@echo "--- docker stack services ($(GUACAMOLE_STACK_NAME))"
	@$(DOCKER) stack services $(GUACAMOLE_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(GUACAMOLE_STACK_NAME))"
	@$(DOCKER) stack ps $(GUACAMOLE_STACK_NAME) --no-trunc
guacamole-debug-logs: ## Tail recent logs for each guacamole service
	@for s in $(GUACAMOLE_SERVICES_SHORT); do \
		echo "==================== $(GUACAMOLE_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(GUACAMOLE_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
guacamole-compose-upgrade: ## Upgrade the guacamole compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-compose-up: guacamole-db-init ## Deploy guacamole (compose; DB init first)
	$(MAKE) docker-project-up PROJECT_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-compose-down: ## Remove guacamole (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-compose-restart: ## Restart guacamole (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-compose-recreate: guacamole-compose-down guacamole-compose-up ## Recreate guacamole (compose)
guacamole-compose-logs: ## Show guacamole compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(GUACAMOLE_STACK_NAME)
guacamole-compose-watch-logs: ## Watch guacamole compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(GUACAMOLE_STACK_NAME)
