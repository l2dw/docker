## —— 🐝 GitLab CE commands ———————————————————————————————————
GITLAB_STACK_NAME := gitlab-ce
GITLAB_SERVICES_SHORT := gitlab-ce
GITLAB_ENV := $(GITLAB_STACK_NAME)/.env
GITLAB_ENV_EXAMPLE := $(GITLAB_STACK_NAME)/.env.example
GITLAB_SECRET_VARS := GITLAB_ROOT_PASSWORD
GITLAB_NOTIFY_VARS := GITLAB_DOMAIN GITLAB_EXTERNAL_URL GITLAB_DB_HOST GITLAB_DB_PASSWORD GITLAB_REDIS_HOST
NETWORK_DRIVER ?= overlay

gitlab-ce-pull-images: ## Pull images for the gitlab-ce stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-setup: ## Ensure gitlab-ce/.env, generate root password, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(GITLAB_ENV)'; \
	exf='$(GITLAB_ENV_EXAMPLE)'; \
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
			GITLAB_ROOT_PASSWORD) printf '%s' '$(GITLAB_ROOT_PASSWORD)' ;; \
			GITLAB_DOMAIN) printf '%s' '$(GITLAB_DOMAIN)' ;; \
			GITLAB_EXTERNAL_URL) printf '%s' '$(GITLAB_EXTERNAL_URL)' ;; \
			GITLAB_DB_HOST) printf '%s' '$(GITLAB_DB_HOST)' ;; \
			GITLAB_DB_PASSWORD) printf '%s' '$(GITLAB_DB_PASSWORD)' ;; \
			GITLAB_REDIS_HOST) printf '%s' '$(GITLAB_REDIS_HOST)' ;; \
		esac; \
	}; \
	for k in $(GITLAB_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			if ! command -v openssl >/dev/null 2>&1; then \
				echo "Error: $$k is empty and openssl is not available." >&2; exit 1; \
			fi; \
			v=$$(openssl rand -base64 24 | tr -d "/+=\n"); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf (and $$root)."; \
		fi; \
	done; \
	missing=0; \
	for k in $(GITLAB_NOTIFY_VARS); do \
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
	[ -n "$$net" ] || net='gitlab-ce-network'; \
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
	echo "GitLab CE env OK ($$envf)."
.gitlab-ce-setup: gitlab-ce-setup
gitlab-ce-stack-up: .gitlab-ce-setup ## Deploy the gitlab-ce stack
	$(MAKE) stack-deploy STACK_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-stack-down: ## Remove the gitlab-ce stack
	$(MAKE) stack-rm STACK_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-stack-recreate: gitlab-ce-stack-down gitlab-ce-stack-up ## Recreate the gitlab-ce stack
gitlab-ce-stack-upgrade: ## Upgrade gitlab-ce swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(GITLAB_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-stack-logs: ## Show logs of the gitlab-ce stack
	$(MAKE) stack-logs STACK_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-stack-watch-logs: ## Watch logs of the gitlab-ce stack
	$(MAKE) stack-watch-logs STACK_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-debug: ## Debug gitlab-ce swarm stack
	@echo "--- docker stack services ($(GITLAB_STACK_NAME))"
	@$(DOCKER) stack services $(GITLAB_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(GITLAB_STACK_NAME))"
	@$(DOCKER) stack ps $(GITLAB_STACK_NAME) --no-trunc
gitlab-ce-debug-logs: ## Tail recent logs for each gitlab-ce service
	@for s in $(GITLAB_SERVICES_SHORT); do \
		echo "==================== $(GITLAB_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(GITLAB_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
gitlab-ce-compose-upgrade: ## Upgrade the gitlab-ce compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-compose-up: .gitlab-ce-setup ## Deploy gitlab-ce (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-compose-down: ## Remove gitlab-ce (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-compose-restart: ## Restart gitlab-ce (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-compose-recreate: gitlab-ce-compose-down gitlab-ce-compose-up ## Recreate gitlab-ce (compose)
gitlab-ce-compose-logs: ## Show gitlab-ce compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(GITLAB_STACK_NAME)
gitlab-ce-compose-watch-logs: ## Watch gitlab-ce compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(GITLAB_STACK_NAME)
