# $(ENV_FILE) is `-include`d as Makefile assignments; all KEY= names are `export`ed so every recipe and
# subprocess (`docker stack deploy`, etc.) inherits the same values. See `.env.example`.
ENV_FILE ?= $(CURDIR)/.env

# ENV_EXPORT_KEYS := $(shell test -f "$(ENV_FILE)" && sed -n '/^[[:space:]]*#/d;/^[[:space:]]*$$/d;/^[A-Za-z_][A-Za-z0-9_]*=/s/=.*$$//p' "$(ENV_FILE)" 2>/dev/null | tr '\n' ' ')
ENV_EXPORT_KEYS := $(shell test -f "$(ENV_FILE)" && sed -n '/^[[:space:]]*\#/d;/^[[:space:]]*$$/d;/^[A-Za-z_][A-Za-z0-9_]*=/s/=.*$$//p' "$(ENV_FILE)" 2>/dev/null | tr '\n' ' ')

ifneq (,$(wildcard $(ENV_FILE)))
-include $(ENV_FILE)
ifneq (,$(strip $(ENV_EXPORT_KEYS)))
export $(ENV_EXPORT_KEYS)
endif
endif

# Parameters (Makefile defaults apply only where below; .env overrides by inclusion above)
SHELL          = sh
TZ             ?= America/Toronto
IP_ADDRESS 	   = $(shell ./bin/ip_address.sh)

# Executables
GIT           = git
DOCKER        	= docker
DOCKER_COMPOSE  = docker compose
DOCKER_SWARM    = docker swarm
MAKE            = make


# Misc
.DEFAULT_GOAL = help
.PHONY        : dokploy-debug dokploy-debug-logs stack-watch-logs

## —— 🐝 The Makefile 🐝 ———————————————————————————————————
help: ## Outputs this help screen
	@grep -h -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' \
		| sed -e 's/\[32m##/[33m/'
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

# —— 🐝 docker-compose commands ———————————————————————————————————
.docker-exists-project: # Check if a docker-compose project exists
	@# Check if the project name is provided
	@if [ -z "$(PROJECT_NAME)" ]; then \
		echo "Project name is not provided"; \
		exit 1; \
	fi;
	@# Check if the folder exists
	@if [ ! -d "$(PROJECT_NAME)" ]; then \
		echo "Folder $(PROJECT_NAME) does not exist"; \
		exit 1; \
	fi;
docker-project-up: .docker-exists-project # Deploy a docker-compose stack
	@# if not set variable DOCKER_COMPOSE_FILE, use the docker-compose.yml file in the project folder
	@if [ -z "$(DOCKER_COMPOSE_FILE)" ]; then \
		DOCKER_COMPOSE_FILE=$(PROJECT_NAME)/docker-compose.yml; \
	fi;
	@# Check if the DOCKER_COMPOSE_FILE exists or is a symlink
	@if [ ! -f "$(DOCKER_COMPOSE_FILE)" ] && [ ! -L "$(DOCKER_COMPOSE_FILE)" ]; then \
		echo "docker compose file '$(DOCKER_COMPOSE_FILE)' does not exist or is not a symlink"; \
		exit 1; \
	fi;
	$(DOCKER_COMPOSE) up -p $(PROJECT_NAME) -f $(DOCKER_COMPOSE_FILE) -d

docker-project-down: .docker-exists-project # Remove a docker-compose stack
	@# if not set variable DOCKER_COMPOSE_FILE, use the docker-compose.yml file in the project folder
	@if [ -z "$(DOCKER_COMPOSE_FILE)" ]; then \
		DOCKER_COMPOSE_FILE=$(PROJECT_NAME)/docker-compose.yml; \
	fi;
	@# Check if the DOCKER_COMPOSE_FILE exists or is a symlink
	@if [ ! -f "$(DOCKER_COMPOSE_FILE)" ] && [ ! -L "$(DOCKER_COMPOSE_FILE)" ]; then \
		echo "docker compose file '$(DOCKER_COMPOSE_FILE)' does not exist or is not a symlink"; \
		exit 1; \
	fi;
	$(DOCKER_COMPOSE) down -p $(PROJECT_NAME) -f $(DOCKER_COMPOSE_FILE)

docker-project-recreate: docker-project-down docker-project-up # Recreate a docker-compose project

docker-project-restart: .docker-exists-project # Restart a docker-compose project
	@if [ -z "$(DOCKER_COMPOSE_FILE)" ]; then \
		DOCKER_COMPOSE_FILE=$(PROJECT_NAME)/docker-compose.yml; \
	fi;
	@if [ ! -f "$(DOCKER_COMPOSE_FILE)" ] && [ ! -L "$(DOCKER_COMPOSE_FILE)" ]; then \
		echo "docker compose file '$(DOCKER_COMPOSE_FILE)' does not exist or is not a symlink"; \
		exit 1; \
	fi;
	$(DOCKER_COMPOSE) restart -p $(PROJECT_NAME) -f $(DOCKER_COMPOSE_FILE)

docker-project-logs: .docker-exists-project ## Show logs of a docker-compose project
	$(DOCKER_COMPOSE) logs $(DOCKER_COMPOSE_FILE)

docker-project-watch: .docker-exists-project ## Watch logs of a docker-compose project
	$(DOCKER_COMPOSE) logs -f  -f $(DOCKER_COMPOSE_FILE)

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
# Default: no detach flag (CLI without `--detach` rejects it). STACK_DEPLOY_WAIT=1 passes --detach=false only if `docker stack deploy --help` lists `--detach`; else prints a stderr note so older hosts remain usable.
STACK_DEPLOY_WAIT ?= 1

stack-deploy: .check-stack-name ## Deploy a stack (STACK_FILE or $(STACK_NAME)/{stack-,docker-}compose.yml; STACK_DEPLOY_WAIT=1 waits when CLI supports --detach)
	@stk='$(STACK_NAME)'; compose='$(STACK_FILE)'; ovr='$(STACK_OVERRIDE)'; \
	if [ -z "$$compose" ] && [ -f "$$stk/stack-compose.yml" ]; then compose="$$stk/stack-compose.yml"; fi; \
	if [ -z "$$compose" ] && [ -f "$$stk/docker-compose.yml" ]; then compose="$$stk/docker-compose.yml"; fi; \
	if [ -z "$$compose" ] || [ ! -f "$$compose" ]; then \
		echo "STACK_FILE is unset and no compose file found under $$stk/ (stack-compose.yml or docker-compose.yml)."; exit 1; \
	fi; \
	if [ -z "$$ovr" ] && { [ -f "$$stk/stack-compose.override.yml" ] || [ -L "$$stk/stack-compose.override.yml" ]; }; then ovr="$$stk/stack-compose.override.yml"; fi; \
	if [ -z "$$ovr" ] && { [ -f "$$stk/docker-compose.override.yml" ] || [ -L "$$stk/docker-compose.override.yml" ]; }; then ovr="$$stk/docker-compose.override.yml"; fi; \
	set -- -c "$$compose"; \
	if [ -n "$$ovr" ] && [ -f "$$ovr" ]; then set -- "$$@" -c "$$ovr"; fi; \
	deploy_extra=""; \
	case "$(STACK_DEPLOY_WAIT)" in 1|true|yes|on) \
	  if $(DOCKER) stack deploy --help 2>/dev/null | grep -q -- '--detach'; then \
	    deploy_extra='--detach=false'; \
	  else \
	    echo >&2 "Note: $(DOCKER) stack deploy has no --detach on this host — cannot wait for rollout; use docker stack ps $$stk."; \
	  fi ;; \
	esac; \
	set +e; \
	$(DOCKER) stack deploy "$$@" "$$stk" --with-registry-auth $$deploy_extra; \
	rc=$$?; \
	if [ "$$rc" -ne 0 ]; then \
	$(DOCKER) stack deploy "$$@" "$$stk" --with-registry-auth $$deploy_extra; \
	rc=$$?; \
	fi; \
	set -e; \
	if [ "$$rc" -ne 0 ]; then \
		echo "Error: docker stack deploy failed (rc=$$rc)."; exit "$$rc"; \
	fi; \
	case "$(STACK_DEPLOY_WAIT)" in 1|true|yes|on) ;; *) \
		echo 'Tip: rollout continues asynchronously — docker stack ps '"$(STACK_NAME)"' · docker stack services '"$(STACK_NAME)" >&2; \
	;; esac
stack-rm: .check-stack-name ## Remove a stack
	$(DOCKER) stack rm $(STACK_NAME)
# Engines without `docker stack logs`: use merged `docker service logs` instead.
STACK_LOG_TAIL ?= 100
STACK_LOG_ARGS ?=

stack-logs: .check-stack-name ## Follow merged logs from all services (STACK_LOG_TAIL STACK_LOG_ARGS)
	@DOCKER="$(DOCKER)" STACK_LOG_TAIL="$(STACK_LOG_TAIL)" STACK_LOG_ARGS="$(STACK_LOG_ARGS)" \
		bin/docker-stack-follow-logs.sh "$(STACK_NAME)"

stack-watch-logs: ## Watch merged logs for STACK_NAME (same as stack-logs — kept for wording / scripts)
	@$(MAKE) stack-logs STACK_NAME="$(STACK_NAME)" STACK_LOG_TAIL="$(STACK_LOG_TAIL)" STACK_LOG_ARGS="$(STACK_LOG_ARGS)"

# Per-project targets (e.g. arcane-stack-up)
-include arcane/Makefile
