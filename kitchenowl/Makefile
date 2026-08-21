## —— 🐝 KitchenOwl commands ———————————————————————————————————
KITCHENOWL_STACK_NAME := kitchenowl
KITCHENOWL_SERVICES_SHORT := kitchenowl
KITCHENOWL_ENV := $(KITCHENOWL_STACK_NAME)/.env
KITCHENOWL_ENV_EXAMPLE := $(KITCHENOWL_STACK_NAME)/.env.example
KITCHENOWL_SECRET_VARS := KITCHENOWL_JWT_SECRET_KEY
KITCHENOWL_NOTIFY_VARS := KITCHENOWL_APP_URL KITCHENOWL_DOMAIN KITCHENOWL_FRONT_URL
KITCHENOWL_PG_REQUIRED := KITCHENOWL_DB_HOST KITCHENOWL_DB_NAME KITCHENOWL_DB_USER

kitchenowl-pull-images: ## Pull images for the kitchenowl stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-setup: ## Ensure kitchenowl/.env, generate JWT secret, sync BASE_HREF / network
	@set -e; \
	envf='$(KITCHENOWL_ENV)'; \
	exf='$(KITCHENOWL_ENV_EXAMPLE)'; \
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
			KITCHENOWL_JWT_SECRET_KEY) printf '%s' '$(KITCHENOWL_JWT_SECRET_KEY)' ;; \
			KITCHENOWL_APP_URL) printf '%s' '$(KITCHENOWL_APP_URL)' ;; \
			KITCHENOWL_DOMAIN) printf '%s' '$(KITCHENOWL_DOMAIN)' ;; \
			KITCHENOWL_FRONT_URL) printf '%s' '$(KITCHENOWL_FRONT_URL)' ;; \
			KITCHENOWL_DB_DRIVER) printf '%s' '$(KITCHENOWL_DB_DRIVER)' ;; \
			KITCHENOWL_DB_HOST) printf '%s' '$(KITCHENOWL_DB_HOST)' ;; \
			KITCHENOWL_DB_PORT) printf '%s' '$(KITCHENOWL_DB_PORT)' ;; \
			KITCHENOWL_DB_NAME) printf '%s' '$(KITCHENOWL_DB_NAME)' ;; \
			KITCHENOWL_DB_USER) printf '%s' '$(KITCHENOWL_DB_USER)' ;; \
			KITCHENOWL_DB_PASSWORD) printf '%s' '$(KITCHENOWL_DB_PASSWORD)' ;; \
		esac; \
	}; \
	for k in $(KITCHENOWL_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -hex 32); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(KITCHENOWL_NOTIFY_VARS); do \
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
	driver=$$(make_get KITCHENOWL_DB_DRIVER); \
	[ -n "$$driver" ] || driver=$$(file_get "$$envf" KITCHENOWL_DB_DRIVER); \
	[ -n "$$driver" ] || driver=$$(file_get "$$root" KITCHENOWL_DB_DRIVER); \
	[ -n "$$driver" ] || driver='sqlite'; \
	case "$$driver" in \
		sqlite) \
			echo "DB_DRIVER=sqlite (file under STORAGE_PATH; uploads still use the data volume)."; \
			;; \
		postgresql|postgres) \
			upsert "$$envf" KITCHENOWL_DB_DRIVER postgresql; \
			if [ -n "$$root" ]; then upsert "$$root" KITCHENOWL_DB_DRIVER postgresql; fi; \
			for k in $(KITCHENOWL_PG_REQUIRED); do \
				v=$$(make_get "$$k"); \
				[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
				[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
				if [ -z "$$v" ]; then \
					echo "Missing $$k for DB_DRIVER=postgresql — set host/name/user (external Postgres)." >&2; \
					missing=1; \
					continue; \
				fi; \
				if [ -n "$$(make_get "$$k")" ]; then \
					upsert "$$envf" "$$k" "$$v"; \
					if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
				fi; \
			done; \
			port=$$(make_get KITCHENOWL_DB_PORT); \
			[ -n "$$port" ] || port=$$(file_get "$$envf" KITCHENOWL_DB_PORT); \
			[ -n "$$port" ] || port=$$(file_get "$$root" KITCHENOWL_DB_PORT); \
			[ -n "$$port" ] || port='5432'; \
			upsert "$$envf" KITCHENOWL_DB_PORT "$$port"; \
			if [ -n "$$root" ]; then upsert "$$root" KITCHENOWL_DB_PORT "$$port"; fi; \
			v=$$(make_get KITCHENOWL_DB_PASSWORD); \
			[ -n "$$v" ] || v=$$(file_get "$$envf" KITCHENOWL_DB_PASSWORD); \
			[ -n "$$v" ] || v=$$(file_get "$$root" KITCHENOWL_DB_PASSWORD); \
			if [ -z "$$v" ]; then \
				if ! command -v openssl >/dev/null 2>&1; then \
					echo "Error: KITCHENOWL_DB_PASSWORD is empty and openssl is not available." >&2; exit 1; \
				fi; \
				v=$$(openssl rand -hex 24); \
				upsert "$$envf" KITCHENOWL_DB_PASSWORD "$$v"; \
				if [ -n "$$root" ]; then upsert "$$root" KITCHENOWL_DB_PASSWORD "$$v"; fi; \
				echo "Generated KITCHENOWL_DB_PASSWORD → $$envf (create matching role on Postgres)."; \
			fi; \
			echo "DB_DRIVER=postgresql → $$envf (external; this stack does not run Postgres)."; \
			;; \
		mysql|mariadb|*) \
			echo "Unsupported KITCHENOWL_DB_DRIVER=$$driver — KitchenOwl only supports sqlite and postgresql." >&2; \
			exit 1; \
			;; \
	esac; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	# Preserve empty BASE_PATH (Host-only). Only default when the key is absent.
	bp_set=0; \
	if grep -q '^KITCHENOWL_BASE_PATH=' "$$envf" 2>/dev/null; then \
		bp=$$(file_get "$$envf" KITCHENOWL_BASE_PATH); bp_set=1; \
	elif [ -n "$$root" ] && grep -q '^KITCHENOWL_BASE_PATH=' "$$root" 2>/dev/null; then \
		bp=$$(file_get "$$root" KITCHENOWL_BASE_PATH); bp_set=1; \
	fi; \
	[ "$$bp_set" -eq 1 ] || bp='/kitchenowl'; \
	case "$$bp" in \
		/|'') \
			upsert "$$envf" KITCHENOWL_BASE_PATH "/"; \
			upsert "$$envf" KITCHENOWL_BASE_HREF ""; \
			upsert "$$envf" KITCHENOWL_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then \
				upsert "$$root" KITCHENOWL_BASE_PATH "/"; \
				upsert "$$root" KITCHENOWL_BASE_HREF ""; \
				upsert "$$root" KITCHENOWL_MIDDLEWARES ""; \
			fi; \
			echo "KITCHENOWL_BASE_PATH=/ (or empty) → Host-only; cleared BASE_HREF."; \
			;; \
		*) \
			href="$$bp"; \
			case "$$href" in */) ;; *) href="$$href/" ;; esac; \
			case "$$href" in /*) ;; *) href="/$$href" ;; esac; \
			upsert "$$envf" KITCHENOWL_BASE_HREF "$$href"; \
			upsert "$$envf" KITCHENOWL_MIDDLEWARES ""; \
			if [ -n "$$root" ]; then \
				upsert "$$root" KITCHENOWL_BASE_HREF "$$href"; \
				upsert "$$root" KITCHENOWL_MIDDLEWARES ""; \
			fi; \
			echo "KITCHENOWL_BASE_HREF=$$href (from BASE_PATH=$$bp; no stripPrefix)."; \
			;; \
	esac; \
	front=$$(file_get "$$envf" KITCHENOWL_FRONT_URL); \
	[ -n "$$front" ] || front=$$(file_get "$$envf" KITCHENOWL_APP_URL); \
	[ -n "$$front" ] || front=$$(file_get "$$root" KITCHENOWL_APP_URL); \
	if [ -n "$$front" ]; then \
		upsert "$$envf" KITCHENOWL_FRONT_URL "$$front"; \
		if [ -n "$$root" ]; then upsert "$$root" KITCHENOWL_FRONT_URL "$$front"; fi; \
	fi; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='kitchenowl-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	echo "KitchenOwl env OK ($$envf)."
.kitchenowl-setup: kitchenowl-setup
kitchenowl-stack-up: .kitchenowl-setup ## Deploy the kitchenowl stack
	$(MAKE) stack-deploy STACK_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-stack-down: ## Remove the kitchenowl stack
	$(MAKE) stack-rm STACK_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-stack-recreate: kitchenowl-stack-down kitchenowl-stack-up ## Recreate the kitchenowl stack
kitchenowl-stack-upgrade: ## Upgrade kitchenowl swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(KITCHENOWL_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-stack-logs: ## Show logs of the kitchenowl stack
	$(MAKE) stack-logs STACK_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-stack-watch-logs: ## Watch logs of the kitchenowl stack
	$(MAKE) stack-watch-logs STACK_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-debug: ## Debug kitchenowl swarm stack
	@echo "--- docker stack services ($(KITCHENOWL_STACK_NAME))"
	@$(DOCKER) stack services $(KITCHENOWL_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(KITCHENOWL_STACK_NAME))"
	@$(DOCKER) stack ps $(KITCHENOWL_STACK_NAME) --no-trunc
kitchenowl-debug-logs: ## Tail recent logs for each kitchenowl service
	@for s in $(KITCHENOWL_SERVICES_SHORT); do \
		echo "==================== $(KITCHENOWL_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(KITCHENOWL_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
kitchenowl-compose-upgrade: ## Upgrade the kitchenowl compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-compose-up: .kitchenowl-setup ## Deploy kitchenowl (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-compose-down: ## Remove kitchenowl (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-compose-restart: ## Restart kitchenowl (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-compose-recreate: kitchenowl-compose-down kitchenowl-compose-up ## Recreate kitchenowl (compose)
kitchenowl-compose-logs: ## Show kitchenowl compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(KITCHENOWL_STACK_NAME)
kitchenowl-compose-watch-logs: ## Watch kitchenowl compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(KITCHENOWL_STACK_NAME)
