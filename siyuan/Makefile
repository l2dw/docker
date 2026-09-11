## —— 🐝 SiYuan commands ———————————————————————————————————
SIYUAN_STACK_NAME := siyuan
SIYUAN_SERVICES_SHORT := siyuan
SIYUAN_ENV := $(SIYUAN_STACK_NAME)/.env
SIYUAN_ENV_EXAMPLE := $(SIYUAN_STACK_NAME)/.env.example
SIYUAN_NOTIFY_VARS := SIYUAN_DOMAIN SIYUAN_ACCESS_AUTH_CODE

siyuan-pull-images: ## Pull images for the siyuan stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(SIYUAN_STACK_NAME)
siyuan-setup: ## Ensure siyuan/.env, generate ACCESS_AUTH_CODE secret, set DEFAULT_NETWORK_NAME=siyuan-network / EXTERNAL=false, warn on example.com / ChangeMe
	@set -e; \
	envf='$(SIYUAN_ENV)'; \
	exf='$(SIYUAN_ENV_EXAMPLE)'; \
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
			SIYUAN_DOMAIN) printf '%s' '$(SIYUAN_DOMAIN)' ;; \
			SIYUAN_ACCESS_AUTH_CODE) printf '%s' '$(SIYUAN_ACCESS_AUTH_CODE)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(SIYUAN_NOTIFY_VARS); do \
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
			*ChangeMe*) echo "Warning: $$k still contains ChangeMe — set a real password in $$envf" >&2 ;; \
		esac; \
	done; \
	sk=$$(make_get SIYUAN_ACCESS_AUTH_CODE); \
	[ -n "$$sk" ] || sk=$$(file_get "$$envf" SIYUAN_ACCESS_AUTH_CODE); \
	[ -n "$$sk" ] || sk=$$(file_get "$$root" SIYUAN_ACCESS_AUTH_CODE); \
	if [ -z "$$sk" ] || [ "$$sk" = ChangeMe ]; then \
		sk=$$(openssl rand -hex 16); \
		upsert "$$envf" SIYUAN_ACCESS_AUTH_CODE "$$sk"; \
		if [ -n "$$root" ]; then upsert "$$root" SIYUAN_ACCESS_AUTH_CODE "$$sk"; fi; \
		echo "Generated SIYUAN_ACCESS_AUTH_CODE → $$envf"; \
	elif [ -n "$$from_make" ]; then \
		upsert "$$envf" SIYUAN_ACCESS_AUTH_CODE "$$from_make"; \
		if [ -n "$$root" ]; then upsert "$$root" SIYUAN_ACCESS_AUTH_CODE "$$from_make"; fi; \
	fi; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='siyuan-network'; \
	case "$$net" in \
		siyuan-network) ext=false ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; fi; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "SiYuan env OK ($$envf)."
.siyuan-setup: siyuan-setup
siyuan-stack-up: .siyuan-setup ## Deploy the siyuan stack
	$(MAKE) stack-deploy STACK_NAME=$(SIYUAN_STACK_NAME)
siyuan-stack-down: ## Remove the siyuan stack
	$(MAKE) stack-rm STACK_NAME=$(SIYUAN_STACK_NAME)
siyuan-stack-recreate: siyuan-stack-down siyuan-stack-up ## Recreate the siyuan stack
siyuan-stack-upgrade: ## Upgrade siyuan swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(SIYUAN_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(SIYUAN_STACK_NAME)
siyuan-stack-logs: ## Show logs of the siyuan stack
	$(MAKE) stack-logs STACK_NAME=$(SIYUAN_STACK_NAME)
siyuan-stack-watch-logs: ## Watch logs of the siyuan stack
	$(MAKE) stack-watch-logs STACK_NAME=$(SIYUAN_STACK_NAME)
siyuan-debug: ## Debug siyuan swarm stack
	@echo "--- docker stack services ($(SIYUAN_STACK_NAME))"
	@$(DOCKER) stack services $(SIYUAN_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(SIYUAN_STACK_NAME))"
	@$(DOCKER) stack ps $(SIYUAN_STACK_NAME) --no-trunc
siyuan-debug-logs: ## Tail recent logs for each siyuan service
	@for s in $(SIYUAN_SERVICES_SHORT); do \
		echo "==================== $(SIYUAN_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(SIYUAN_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
siyuan-compose-upgrade: ## Upgrade the siyuan compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(SIYUAN_STACK_NAME)
siyuan-compose-up: .siyuan-setup ## Deploy siyuan (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(SIYUAN_STACK_NAME)
siyuan-compose-down: ## Remove siyuan (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(SIYUAN_STACK_NAME)
siyuan-compose-restart: ## Restart siyuan (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(SIYUAN_STACK_NAME)
siyuan-compose-recreate: siyuan-compose-down siyuan-compose-up ## Recreate siyuan (compose)
siyuan-compose-logs: ## Show siyuan compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(SIYUAN_STACK_NAME)
siyuan-compose-watch-logs: ## Watch siyuan compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(SIYUAN_STACK_NAME)
