## —— 🐝 Woodpecker commands ———————————————————————————————————
WOODPECKER_STACK_NAME := woodpecker
WOODPECKER_SERVICES_SHORT := woodpecker-server woodpecker-agent
WOODPECKER_ENV := $(WOODPECKER_STACK_NAME)/.env
WOODPECKER_ENV_EXAMPLE := $(WOODPECKER_STACK_NAME)/.env.example
WOODPECKER_SECRET_VARS := WOODPECKER_AGENT_SECRET
WOODPECKER_NOTIFY_VARS := WOODPECKER_HOST WOODPECKER_DOMAIN

woodpecker-pull-images: ## Pull images for the woodpecker stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-setup: ## Ensure woodpecker/.env, generate AGENT_SECRET, warn on HOST/DOMAIN/OAuth
	@set -e; \
	envf='$(WOODPECKER_ENV)'; \
	exf='$(WOODPECKER_ENV_EXAMPLE)'; \
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
			WOODPECKER_AGENT_SECRET) printf '%s' '$(WOODPECKER_AGENT_SECRET)' ;; \
			WOODPECKER_HOST) printf '%s' '$(WOODPECKER_HOST)' ;; \
			WOODPECKER_DOMAIN) printf '%s' '$(WOODPECKER_DOMAIN)' ;; \
		esac; \
	}; \
	for k in $(WOODPECKER_SECRET_VARS); do \
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
	for k in $(WOODPECKER_NOTIFY_VARS); do \
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
	gh=$$(file_get "$$envf" WOODPECKER_GITHUB); \
	[ -n "$$gh" ] || gh=$$(file_get "$$root" WOODPECKER_GITHUB); \
	gt=$$(file_get "$$envf" WOODPECKER_GITEA); \
	[ -n "$$gt" ] || gt=$$(file_get "$$root" WOODPECKER_GITEA); \
	if [ "$$gh" = "true" ]; then \
		c=$$(file_get "$$envf" WOODPECKER_GITHUB_CLIENT); \
		[ -n "$$c" ] || c=$$(file_get "$$root" WOODPECKER_GITHUB_CLIENT); \
		s=$$(file_get "$$envf" WOODPECKER_GITHUB_SECRET); \
		[ -n "$$s" ] || s=$$(file_get "$$root" WOODPECKER_GITHUB_SECRET); \
		if [ -z "$$c" ] || [ -z "$$s" ]; then \
			echo "Warning: WOODPECKER_GITHUB=true but CLIENT/SECRET empty — create a GitHub OAuth App (callback $$WOODPECKER_HOST/authorize)." >&2; \
		fi; \
	fi; \
	if [ "$$gt" = "true" ]; then \
		u=$$(file_get "$$envf" WOODPECKER_GITEA_URL); \
		[ -n "$$u" ] || u=$$(file_get "$$root" WOODPECKER_GITEA_URL); \
		c=$$(file_get "$$envf" WOODPECKER_GITEA_CLIENT); \
		[ -n "$$c" ] || c=$$(file_get "$$root" WOODPECKER_GITEA_CLIENT); \
		s=$$(file_get "$$envf" WOODPECKER_GITEA_SECRET); \
		[ -n "$$s" ] || s=$$(file_get "$$root" WOODPECKER_GITEA_SECRET); \
		if [ -z "$$u" ] || [ -z "$$c" ] || [ -z "$$s" ]; then \
			echo "Warning: WOODPECKER_GITEA=true but URL/CLIENT/SECRET incomplete (Forgejo uses the Gitea forge)." >&2; \
		fi; \
	fi; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "Woodpecker env OK ($$envf)."
.woodpecker-setup: woodpecker-setup
woodpecker-stack-up: .woodpecker-setup ## Deploy the woodpecker stack
	$(MAKE) stack-deploy STACK_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-stack-down: ## Remove the woodpecker stack
	$(MAKE) stack-rm STACK_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-stack-recreate: woodpecker-stack-down woodpecker-stack-up ## Recreate the woodpecker stack
woodpecker-stack-upgrade: ## Upgrade woodpecker swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(WOODPECKER_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-stack-logs: ## Show logs of the woodpecker stack
	$(MAKE) stack-logs STACK_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-stack-watch-logs: ## Watch logs of the woodpecker stack
	$(MAKE) stack-watch-logs STACK_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-debug: ## Debug woodpecker swarm stack
	@echo "--- docker stack services ($(WOODPECKER_STACK_NAME))"
	@$(DOCKER) stack services $(WOODPECKER_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(WOODPECKER_STACK_NAME))"
	@$(DOCKER) stack ps $(WOODPECKER_STACK_NAME) --no-trunc
woodpecker-debug-logs: ## Tail recent logs for each woodpecker service
	@for s in $(WOODPECKER_SERVICES_SHORT); do \
		echo "==================== $(WOODPECKER_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(WOODPECKER_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
woodpecker-compose-upgrade: ## Upgrade the woodpecker compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-compose-up: .woodpecker-setup ## Deploy woodpecker (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-compose-down: ## Remove woodpecker (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-compose-restart: ## Restart woodpecker (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-compose-recreate: woodpecker-compose-down woodpecker-compose-up ## Recreate woodpecker (compose)
woodpecker-compose-logs: ## Show woodpecker compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(WOODPECKER_STACK_NAME)
woodpecker-compose-watch-logs: ## Watch woodpecker compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(WOODPECKER_STACK_NAME)
