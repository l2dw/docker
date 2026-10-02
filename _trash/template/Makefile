## —— 🐝 TPL commands ———————————————————————————————————
TPL_STACK_NAME := tpl
TPL_SERVICES_SHORT := tpl
tpl-pull-images: ## Pull images for the tpl stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(TPL_STACK_NAME)
tpl-stack-setup: ## Setup the tpl stack
	@echo "Setting up the tpl stack..."
tpl-stack-up: .tpl-stack-setup ## Deploy the tpl stack
	$(MAKE) stack-deploy STACK_NAME=$(TPL_STACK_NAME)
tpl-stack-down: ## Remove the tpl stack
	$(MAKE) stack-rm STACK_NAME=$(TPL_STACK_NAME)
tpl-stack-recreate: tpl-stack-down tpl-stack-up ## Recreate the tpl stack
tpl-stack-logs: ## Show logs of the tpl stack
	$(MAKE) stack-logs STACK_NAME=$(TPL_STACK_NAME)
tpl-stack-watch-logs: ## Watch logs of the tpl stack
	$(MAKE) stack-watch-logs STACK_NAME=$(TPL_STACK_NAME)
tpl-debug: ## Debug tpl swarm stack: services, tasks (states/errors), traefik ports
	@echo "--- docker stack services ($(TPL_STACK_NAME))"
	@$(DOCKER) stack services $(TPL_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker service ls (${TPL_STACK_NAME}_*) ---"
	@$(DOCKER) service ls --filter label=com.docker.stack.namespace=$(TPL_STACK_NAME) 2>/dev/null \
		|| $(DOCKER) service ls | grep '$(TPL_STACK_NAME)_' \
		|| echo "(could not filter services)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(TPL_STACK_NAME))"
	@$(DOCKER) stack ps $(TPL_STACK_NAME) --no-trunc
	@echo
	@echo "--- traefik published ports ---"
	@$(DOCKER) service inspect $(TPL_STACK_NAME)_tpl-traefik --format '{{json .Endpoint.Ports}}' 2>/dev/null || echo "(no traefik service or inspect failed)"
tpl-debug-logs: ## Tail recent logs for each tpl service (e.g. services at 0/1)
	@for s in $(TPL_SERVICES_SHORT); do \
		echo "==================== $(TPL_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(TPL_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
tpl-compose-upgrade: ## Upgrade the tpl stack
	make docker-project-upgrade PROJECT_NAME=$(TPL_STACK_NAME)
tpl-compose-up: ## Deploy the tpl stack
	make docker-project-up PROJECT_NAME=$(TPL_STACK_NAME)
tpl-compose-down: ## Remove the tpl stack
	make docker-project-down PROJECT_NAME=$(TPL_STACK_NAME)
tpl-compose-restart: ## Restart the tpl stack
	make docker-project-restart PROJECT_NAME=$(TPL_STACK_NAME)
tpl-compose-recreate: tpl-compose-down tpl-compose-up ## Recreate the tpl stack
tpl-compose-logs: ## Show logs of the tpl stack
	make docker-project-logs PROJECT_NAME=$(TPL_STACK_NAME)
tpl-compose-watch-logs: ## Watch logs of the tpl stack
	make docker-project-watch PROJECT_NAME=$(TPL_STACK_NAME)
