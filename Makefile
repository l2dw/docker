# include .env if it exists
-include .env


# Parameters
SHELL         = sh
TZ            = America/Toronto
IP_ADDRESS 	  = $(shell ./bin/ip_address.sh)

# Executables
GIT           = git
DOCKER        	= docker
DOCKER_COMPOSE  = docker compose
DOCKER_SWARM    = docker swarm
MAKE            = make


# Misc
.DEFAULT_GOAL = help
.PHONY        : dokploy-debug dokploy-debug-logs

## —— 🐝 The Makefile 🐝 ———————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

## —— 🐝 Docker commands ———————————————————————————————————
docker-ps: ## List all running containers
	$(DOCKER) ps
docker-all: ## List all containers
	$(DOCKER) ps -a
docker-exists-container: ## Check if a container exists
	@# Check if the container name is provided
	@if [ -z "$(CONTAINER_NAME)" ]; then \
		echo "Container name is not provided"; \
		exit 1; \
	fi; \
	@# Check if the container exists
	@if ! $(DOCKER) ps -a | grep -q $(CONTAINER_NAME); then \
		echo "Container $(CONTAINER_NAME) does not exist"; \
		exit 1; \
	fi;
docker-stop: docker-exists-container ## Stop a container
	@# Check if the container is running
	@if $(DOCKER) ps | grep -q $(CONTAINER_NAME); then \
		echo "Container $(CONTAINER_NAME) is already running"; \
		exit 0; \
	fi;
	$(DOCKER) stop $(CONTAINER_NAME)

docker-start: docker-exists-container ## Start a container
	@# Check if the container is running
	@if $(DOCKER) ps | grep -q $(CONTAINER_NAME); then \
		echo "Container $(CONTAINER_NAME) is already running"; \
		exit 0; \
	fi;
	$(DOCKER) start $(CONTAINER_NAME)
docker-restart: docker-exists-container ## Restart a container
	$(DOCKER) restart $(CONTAINER_NAME)

docker-rm: docker-exists-container ## Remove a container
	$(DOCKER) rm -f $(CONTAINER_NAME)

docker-watch-logs: docker-exists-container ## Watch logs of a container
	$(DOCKER) logs -f $(CONTAINER_NAME)

## —— 🐝 swarm commands ———————————————————————————————————
swarm-init: ## Initialize the swarm
	$(DOCKER_SWARM) init --advertise-addr $(IP_ADDRESS)
swarm-info: ## Show swarm info
	$(DOCKER_SWARM) info
swarm-leave: ## Leave the swarm
	$(DOCKER_SWARM) leave --force
swarm-join: ## Join the swarm
	$(DOCKER_SWARM) join --token $(SWARM_TOKEN) $(SWARM_JOIN_ADDRESS)
swarm-unlock: ## Unlock the swarm
	$(DOCKER_SWARM) unlock
swarm-unlock-key: ## Show the unlock key
	$(DOCKER_SWARM) unlock-key

## —— 🐝 stack commands ———————————————————————————————————
.check-stack-name: ## Check if a stack name is provided
	@# Check if the stack name is provided
	@if [ -z "$(STACK_NAME)" ]; then \
		echo "Stack name is not provided"; \
		exit 1; \
	fi;
.check-stack-file: ## Check if a stack file is provided
	@# Check if the stack file is provided
	@if [ -z "$(STACK_FILE)" ]; then \
		echo "Stack file is not provided"; \
		exit 1; \
	fi;
	@# Check if the stack file exists
	@if [ ! -f "$(STACK_FILE)" ]; then \
		echo "Stack file $(STACK_FILE) does not exist"; \
		exit 1; \
	fi;
stack-deploy: .check-stack-name ## Deploy a stack
	$(DOCKER) stack deploy -c $(STACK_FILE) $(STACK_NAME) --with-registry-auth
stack-rm: .check-stack-name ## Remove a stack
	$(DOCKER) stack rm $(STACK_NAME)
stack-logs: .check-stack-name ## Show logs of a stack
	$(DOCKER) stack logs -f $(STACK_NAME)
stack-watch-logs: .check-stack-name ## Watch logs of a stack
	$(DOCKER) stack logs -f $(STACK_NAME)

## —— 🐝 Dokploy commands ———————————————————————————————————
DOKPLOY_STACK_NAME := dokploy
DOKPLOY_STACK_FILE := $(DOKPLOY_STACK_NAME)/stack-compose.yml
DOKPLOY_SERVICES_SHORT := dokploy dokploy-postgresql dokploy-redis dokploy-traefik
.dokploy-stack-setup:
	@# Create network if it doesn't exist
	@if ! $(DOCKER) network ls | grep -q "dokploy-network"; then \
		$(DOCKER) network create "dokploy-network" --driver overlay; \
	fi;
	@# Swarm stack deploy needs a manager control plane (ControlAvailable). LocalNodeState can be error when another node is Down while this leader still works.
	@swarm_ctrl="$$($(DOCKER) info -f '{{.Swarm.ControlAvailable}}' 2>/dev/null)"; \
	swarm_state="$$($(DOCKER) info -f '{{.Swarm.LocalNodeState}}' 2>/dev/null)"; \
	if [ "$$swarm_ctrl" = "true" ]; then \
		exit 0; \
	elif [ "$$swarm_state" = "active" ]; then \
		exit 0; \
	else \
		echo "Swarm stack commands not available here (ControlAvailable=$$swarm_ctrl LocalNodeState=$$swarm_state)."; \
		echo "If another node shows Down / Unknown, fix or remove it: docker node ls && docker node rm"; \
		echo "Otherwise join/init: make swarm-init"; \
		exit 1; \
	fi
dokploy-stack-up: .dokploy-stack-setup ## Deploy the dokploy stack
	$(MAKE) stack-deploy STACK_FILE=$(DOKPLOY_STACK_FILE) STACK_NAME=$(DOKPLOY_STACK_NAME)

dokploy-stack-down: ## Remove the dokploy stack
	$(MAKE) stack-rm STACK_NAME=$(DOKPLOY_STACK_NAME)

dokploy-stack-recreate: dokploy-stack-down dokploy-stack-up ## Recreate the dokploy stack

dokploy-stack-logs: ## Show logs of the dokploy stack
	$(MAKE) stack-logs STACK_NAME=$(DOKPLOY_STACK_NAME)
dokploy-stack-watch-logs: ## Watch logs of the dokploy stack
	$(MAKE) stack-watch-logs STACK_NAME=$(DOKPLOY_STACK_NAME)

dokploy-debug: ## Debug dokploy swarm stack: services, tasks (states/errors), traefik ports
	@echo "--- docker stack services ($(DOKPLOY_STACK_NAME))"
	@$(DOCKER) stack services $(DOKPLOY_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker service ls (${DOKPLOY_STACK_NAME}_*) ---"
	@$(DOCKER) service ls --filter label=com.docker.stack.namespace=$(DOKPLOY_STACK_NAME) 2>/dev/null \
		|| $(DOCKER) service ls | grep '$(DOKPLOY_STACK_NAME)_' \
		|| echo "(could not filter services)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(DOKPLOY_STACK_NAME))"
	@$(DOCKER) stack ps $(DOKPLOY_STACK_NAME) --no-trunc
	@echo
	@echo "--- traefik published ports ---"
	@$(DOCKER) service inspect $(DOKPLOY_STACK_NAME)_dokploy-traefik --format '{{json .Endpoint.Ports}}' 2>/dev/null || echo "(no traefik service or inspect failed)"

dokploy-debug-logs: ## Tail recent logs for each dokploy service (e.g. services at 0/1)
	@for s in $(DOKPLOY_SERVICES_SHORT); do \
		echo "==================== $(DOKPLOY_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(DOKPLOY_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
