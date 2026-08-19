## —— 🐝 nginx commands ———————————————————————————————————
NGINX_STACK_NAME := nginx
NGINX_SERVICES_SHORT := nginx
NGINX_ENV := $(NGINX_STACK_NAME)/.env
NGINX_ENV_EXAMPLE := $(NGINX_STACK_NAME)/.env.example
NGINX_NOTIFY_VARS := NGINX_DOMAIN

nginx-pull-images: ## Pull images for the nginx stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(NGINX_STACK_NAME)
nginx-setup: ## Ensure nginx/.env, warn on example.com / S3 ChangeMe, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(NGINX_ENV)'; \
	exf='$(NGINX_ENV_EXAMPLE)'; \
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
			NGINX_DOMAIN) printf '%s' '$(NGINX_DOMAIN)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(NGINX_NOTIFY_VARS); do \
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
	s3img=$$(file_get "$$envf" NGINX_IMAGE); \
	[ -n "$$s3img" ] || s3img=$$(file_get "$$root" NGINX_IMAGE); \
	s3sec=$$(file_get "$$envf" NGINX_S3_SECRET_KEY); \
	[ -n "$$s3sec" ] || s3sec=$$(file_get "$$root" NGINX_S3_SECRET_KEY); \
	case "$$s3img" in \
		*s3-gateway*) \
			case "$$s3sec" in \
				''|ChangeMe) echo "Warning: NGINX_S3_SECRET_KEY is empty or ChangeMe — required for nginx-s3-gateway" >&2 ;; \
			esac; \
			;; \
	esac; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='dokploy-network'; \
	case "$$net" in \
		''|dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "nginx env OK ($$envf)."
.nginx-setup: nginx-setup
nginx-stack-up: .nginx-setup ## Deploy the nginx stack
	$(MAKE) stack-deploy STACK_NAME=$(NGINX_STACK_NAME)
nginx-stack-down: ## Remove the nginx stack
	$(MAKE) stack-rm STACK_NAME=$(NGINX_STACK_NAME)
nginx-stack-recreate: nginx-stack-down nginx-stack-up ## Recreate the nginx stack
nginx-stack-upgrade: ## Upgrade nginx swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(NGINX_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(NGINX_STACK_NAME)
nginx-stack-logs: ## Show logs of the nginx stack
	$(MAKE) stack-logs STACK_NAME=$(NGINX_STACK_NAME)
nginx-stack-watch-logs: ## Watch logs of the nginx stack
	$(MAKE) stack-watch-logs STACK_NAME=$(NGINX_STACK_NAME)
nginx-debug: ## Debug nginx swarm stack
	@echo "--- docker stack services ($(NGINX_STACK_NAME))"
	@$(DOCKER) stack services $(NGINX_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(NGINX_STACK_NAME))"
	@$(DOCKER) stack ps $(NGINX_STACK_NAME) --no-trunc
nginx-debug-logs: ## Tail recent logs for each nginx service
	@for s in $(NGINX_SERVICES_SHORT); do \
		echo "==================== $(NGINX_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(NGINX_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
nginx-compose-upgrade: ## Upgrade the nginx compose project
	$(MAKE) docker-pull-images PROJECT_NAME=$(NGINX_STACK_NAME)
	$(MAKE) docker-project-up PROJECT_NAME=$(NGINX_STACK_NAME)
nginx-compose-up: .nginx-setup ## Deploy nginx (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(NGINX_STACK_NAME)
nginx-compose-down: ## Remove nginx (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(NGINX_STACK_NAME)
nginx-compose-restart: ## Restart nginx (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(NGINX_STACK_NAME)
nginx-compose-recreate: nginx-compose-down nginx-compose-up ## Recreate nginx (compose)
nginx-compose-logs: ## Show nginx compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(NGINX_STACK_NAME)
nginx-compose-watch-logs: ## Watch nginx compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(NGINX_STACK_NAME)
