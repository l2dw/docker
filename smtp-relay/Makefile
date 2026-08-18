## —— 🐝 smtp-relay commands ———————————————————————————————————
SMTP_RELAY_STACK_NAME := smtp-relay
SMTP_RELAY_SERVICES_SHORT := smtp-relay
SMTP_RELAY_ENV := $(SMTP_RELAY_STACK_NAME)/.env
SMTP_RELAY_ENV_EXAMPLE := $(SMTP_RELAY_STACK_NAME)/.env.example
SMTP_RELAY_NOTIFY_VARS := SMTP_RELAY_MAILNAME

smtp-relay-pull-images: ## Pull images for the smtp-relay stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-setup: ## Ensure smtp-relay/.env, warn on MAILNAME / RELAY_NETWORKS
	@set -e; \
	envf='$(SMTP_RELAY_ENV)'; \
	exf='$(SMTP_RELAY_ENV_EXAMPLE)'; \
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
			SMTP_RELAY_MAILNAME) printf '%s' '$(SMTP_RELAY_MAILNAME)' ;; \
		esac; \
	}; \
	missing=0; \
	for k in $(SMTP_RELAY_NOTIFY_VARS); do \
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
	nets=$$(file_get "$$envf" SMTP_RELAY_NETWORKS); \
	[ -n "$$nets" ] || nets=$$(file_get "$$root" SMTP_RELAY_NETWORKS); \
	case "$$nets" in \
		:*) ;; \
		*) echo "Warning: SMTP_RELAY_NETWORKS must start with ':' (got '$$nets')" >&2 ;; \
	esac; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "smtp-relay env OK ($$envf)."
.smtp-relay-setup: smtp-relay-setup
smtp-relay-stack-up: .smtp-relay-setup ## Deploy the smtp-relay stack
	$(MAKE) stack-deploy STACK_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-stack-down: ## Remove the smtp-relay stack
	$(MAKE) stack-rm STACK_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-stack-recreate: smtp-relay-stack-down smtp-relay-stack-up ## Recreate the smtp-relay stack
smtp-relay-stack-upgrade: ## Upgrade smtp-relay swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(SMTP_RELAY_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-stack-logs: ## Show logs of the smtp-relay stack
	$(MAKE) stack-logs STACK_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-stack-watch-logs: ## Watch logs of the smtp-relay stack
	$(MAKE) stack-watch-logs STACK_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-debug: ## Debug smtp-relay swarm stack
	@echo "--- docker stack services ($(SMTP_RELAY_STACK_NAME))"
	@$(DOCKER) stack services $(SMTP_RELAY_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(SMTP_RELAY_STACK_NAME))"
	@$(DOCKER) stack ps $(SMTP_RELAY_STACK_NAME) --no-trunc
smtp-relay-debug-logs: ## Tail recent logs for each smtp-relay service
	@for s in $(SMTP_RELAY_SERVICES_SHORT); do \
		echo "==================== $(SMTP_RELAY_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(SMTP_RELAY_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
smtp-relay-compose-upgrade: ## Upgrade the smtp-relay compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-compose-up: .smtp-relay-setup ## Deploy smtp-relay (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-compose-down: ## Remove smtp-relay (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-compose-restart: ## Restart smtp-relay (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-compose-recreate: smtp-relay-compose-down smtp-relay-compose-up ## Recreate smtp-relay (compose)
smtp-relay-compose-logs: ## Show smtp-relay compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-compose-watch-logs: ## Watch smtp-relay compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(SMTP_RELAY_STACK_NAME)
smtp-relay-test-send: ## Send a test message to the local relay (not the upstream smarthost)
	@to='$(SMTP_RELAY_TEST_TO)'; \
	from='$(SMTP_RELAY_TEST_FROM)'; \
	host='$(SMTP_RELAY_TEST_HOST)'; \
	port='$(SMTP_RELAY_PORT_PUBLISHED)'; \
	[ -n "$$host" ] || host=127.0.0.1; \
	[ -n "$$port" ] || port=25; \
	if [ -z "$$to" ]; then echo "Set SMTP_RELAY_TEST_TO in smtp-relay/.env or pass SMTP_RELAY_TEST_TO=you@example.com" >&2; exit 1; fi; \
	$(CURDIR)/bin/send-test-email.sh $(ARGS) --to "$$to" --host "$$host" --port "$$port" $${from:+--from $$from}
# Aliases kept for older README / muscle memory
smtp-relay-deploy: smtp-relay-stack-up
smtp-relay-remove: smtp-relay-stack-down
smtp-relay-up: smtp-relay-compose-up
smtp-relay-down: smtp-relay-compose-down
send-test-email: smtp-relay-test-send ## Alias for smtp-relay-test-send
