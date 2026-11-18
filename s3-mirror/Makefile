## —— 🐝 s3-mirror commands ———————————————————————————————————
S3_MIRROR_STACK_NAME := s3-mirror
S3_MIRROR_SERVICES_SHORT := s3-mirror
S3_MIRROR_ENV := $(S3_MIRROR_STACK_NAME)/.env
S3_MIRROR_ENV_EXAMPLE := $(S3_MIRROR_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

s3-mirror-pull-images: ## Pull images for the s3-mirror stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(S3_MIRROR_STACK_NAME)

s3-mirror-setup: ## Ensure s3-mirror/.env and sync DEFAULT_NETWORK_EXTERNAL (true only for dokploy-network)
	@set -e; \
	envf='$(S3_MIRROR_ENV)'; \
	exf='$(S3_MIRROR_ENV_EXAMPLE)'; \
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
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='s3-mirror-network'; \
	case "$$net" in \
		dokploy-network) ext=true ;; \
		*) ext=false ;; \
	esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ] && [ -f "$$root" ]; then \
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
	echo "s3-mirror env OK ($$envf)."
.s3-mirror-setup: s3-mirror-setup

s3-mirror-stack-up: .s3-mirror-setup ## Deploy the s3-mirror stack
	$(MAKE) stack-deploy STACK_NAME=$(S3_MIRROR_STACK_NAME)
s3-mirror-stack-down: ## Remove the s3-mirror stack
	$(MAKE) stack-rm STACK_NAME=$(S3_MIRROR_STACK_NAME)
s3-mirror-stack-recreate: s3-mirror-stack-down s3-mirror-stack-up ## Recreate the s3-mirror stack
s3-mirror-stack-upgrade: ## Upgrade s3-mirror swarm images (pull + deploy)
	$(MAKE) s3-mirror-pull-images
	$(MAKE) stack-deploy STACK_NAME=$(S3_MIRROR_STACK_NAME)
s3-mirror-stack-logs: ## Show logs of the s3-mirror stack
	$(MAKE) stack-logs STACK_NAME=$(S3_MIRROR_STACK_NAME)
s3-mirror-debug: ## Debug s3-mirror swarm stack
	@echo "--- docker stack services ($(S3_MIRROR_STACK_NAME))"
	@$(DOCKER) stack services $(S3_MIRROR_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(S3_MIRROR_STACK_NAME))"
	@$(DOCKER) stack ps $(S3_MIRROR_STACK_NAME) --no-trunc 2>/dev/null || true
s3-mirror-debug-logs: ## Tail recent logs for each s3-mirror service
	@for s in $(S3_MIRROR_SERVICES_SHORT); do \
		echo "=== $(S3_MIRROR_STACK_NAME)_$$s ==="; \
		$(DOCKER) service logs --tail 80 $(S3_MIRROR_STACK_NAME)_$$s 2>/dev/null || true; \
	done

s3-mirror-compose-up: .s3-mirror-setup ## Deploy s3-mirror (compose)
	@envf='$(S3_MIRROR_ENV)'; \
	[ -f "$$envf" ] || envf='$(S3_MIRROR_ENV_EXAMPLE)'; \
	$(DOCKER) compose -f $(S3_MIRROR_STACK_NAME)/docker-compose.yml --env-file "$$envf" up -d
s3-mirror-compose-down: ## Remove s3-mirror (compose)
	@$(DOCKER) compose -f $(S3_MIRROR_STACK_NAME)/docker-compose.yml --env-file $(S3_MIRROR_ENV_EXAMPLE) down
s3-mirror-compose-restart: ## Restart s3-mirror (compose)
	@$(DOCKER) compose -f $(S3_MIRROR_STACK_NAME)/docker-compose.yml --env-file $(S3_MIRROR_ENV_EXAMPLE) restart
s3-mirror-compose-logs: ## Logs s3-mirror (compose)
	@$(DOCKER) compose -f $(S3_MIRROR_STACK_NAME)/docker-compose.yml --env-file $(S3_MIRROR_ENV_EXAMPLE) logs -f --tail=100
s3-mirror-compose-recreate: s3-mirror-compose-down s3-mirror-compose-up ## Recreate s3-mirror (compose)
