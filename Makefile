# include .env.local
VERSION := v$(shell date +%Y.%m.%d)
DATETIME := $(shell date '+%Y.%m.%d %H:%M:%S')
ENV=prod

BIN_DIR=./bin
# BACKUPS_DIR=$(APPDATA_DIR)/backups

# Export environment variables from .env file if it exists
ENV_FILE ?= $(CURDIR)/.env
ENV_EXPORT_KEYS := $(shell test -f "$(ENV_FILE)" && sed -n '/^[[:space:]]*\#/d;/^[[:space:]]*$$/d;/^[A-Za-z_][A-Za-z0-9_]*=/s/=.*$$//p' "$(ENV_FILE)" 2>/dev/null | tr '\n' ' ')

ifneq (,$(wildcard $(ENV_FILE)))
-include $(ENV_FILE)
ifneq (,$(strip $(ENV_EXPORT_KEYS)))
export $(ENV_EXPORT_KEYS)
endif
endif


USE_CACHE = "yes"
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
<<<<<<< HEAD
.PHONY        : # Not needed here, but you can put your all your targets to be sure
                # there is no name conflict between your files and your targets.
=======
# .PHONY: help
>>>>>>> master

## —— 🐝 The Makefile 🐝 ———————————————————————————————————
help: ## Outputs this help screen
	@grep -h -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' \
		| sed -e 's/\[32m##/[33m/'

## —— 🐝 Docker commands ———————————————————————————————————
docker-login: ## Login to the Docker registry
	@echo "Logging in to the Docker registry '$(DOCKER_REGISTRY_HOST)' as $(DOCKER_REGISTRY_USER)"
	@$(DOCKER) login $(DOCKER_REGISTRY_HOST) -u $(DOCKER_REGISTRY_USER) -p $(DOCKER_REGISTRY_PASS)

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
	@eval "$$(COMPOSE_FILE='$(DOCKER_COMPOSE_FILE)' COMPOSE_OVERRIDE='$(DOCKER_COMPOSE_OVERRIDE)' $(BIN_DIR)/resolve-project-compose.sh '$(PROJECT_NAME)')"; \
	if [ -z "$$compose" ] || { [ ! -f "$$compose" ] && [ ! -L "$$compose" ]; }; then \
		echo "No compose file under $(PROJECT_NAME)/ (stack-compose.yml or docker-compose.yml)"; exit 1; \
	fi; \
	set -- $(DOCKER_COMPOSE) -p $(PROJECT_NAME) -f "$$compose"; \
	if [ -n "$$override" ] && [ -f "$$override" ]; then set -- "$$@" -f "$$override"; fi; \
	if [ -n "$$env_file" ]; then set -- "$$@" --env-file "$$env_file"; fi; \
	set -- "$$@" up -d; \
	"$$@"

docker-project-down: .docker-exists-project # Remove a docker-compose stack
	@eval "$$(COMPOSE_FILE='$(DOCKER_COMPOSE_FILE)' COMPOSE_OVERRIDE='$(DOCKER_COMPOSE_OVERRIDE)' $(BIN_DIR)/resolve-project-compose.sh '$(PROJECT_NAME)')"; \
	if [ -z "$$compose" ] || { [ ! -f "$$compose" ] && [ ! -L "$$compose" ]; }; then \
		echo "No compose file under $(PROJECT_NAME)/ (stack-compose.yml or docker-compose.yml)"; exit 1; \
	fi; \
	set -- $(DOCKER_COMPOSE) -p $(PROJECT_NAME) -f "$$compose"; \
	if [ -n "$$override" ] && [ -f "$$override" ]; then set -- "$$@" -f "$$override"; fi; \
	if [ -n "$$env_file" ]; then set -- "$$@" --env-file "$$env_file"; fi; \
	set -- "$$@" down; \
	"$$@"

docker-project-recreate: docker-project-down docker-project-up # Recreate a docker-compose project

docker-project-restart: .docker-exists-project # Restart a docker-compose project
	@eval "$$(COMPOSE_FILE='$(DOCKER_COMPOSE_FILE)' COMPOSE_OVERRIDE='$(DOCKER_COMPOSE_OVERRIDE)' $(BIN_DIR)/resolve-project-compose.sh '$(PROJECT_NAME)')"; \
	if [ -z "$$compose" ] || { [ ! -f "$$compose" ] && [ ! -L "$$compose" ]; }; then \
		echo "No compose file under $(PROJECT_NAME)/ (stack-compose.yml or docker-compose.yml)"; exit 1; \
	fi; \
	set -- $(DOCKER_COMPOSE) -p $(PROJECT_NAME) -f "$$compose"; \
	if [ -n "$$override" ] && [ -f "$$override" ]; then set -- "$$@" -f "$$override"; fi; \
	if [ -n "$$env_file" ]; then set -- "$$@" --env-file "$$env_file"; fi; \
	set -- "$$@" restart; \
	"$$@"

docker-project-logs: .docker-exists-project ## Show logs of a docker-compose project
	@eval "$$(COMPOSE_FILE='$(DOCKER_COMPOSE_FILE)' COMPOSE_OVERRIDE='$(DOCKER_COMPOSE_OVERRIDE)' $(BIN_DIR)/resolve-project-compose.sh '$(PROJECT_NAME)')"; \
	set -- $(DOCKER_COMPOSE) -p $(PROJECT_NAME) -f "$$compose"; \
	if [ -n "$$override" ] && [ -f "$$override" ]; then set -- "$$@" -f "$$override"; fi; \
	if [ -n "$$env_file" ]; then set -- "$$@" --env-file "$$env_file"; fi; \
	set -- "$$@" logs; \
	"$$@"

docker-project-watch: .docker-exists-project ## Watch logs of a docker-compose project
	@eval "$$(COMPOSE_FILE='$(DOCKER_COMPOSE_FILE)' COMPOSE_OVERRIDE='$(DOCKER_COMPOSE_OVERRIDE)' $(BIN_DIR)/resolve-project-compose.sh '$(PROJECT_NAME)')"; \
	set -- $(DOCKER_COMPOSE) -p $(PROJECT_NAME) -f "$$compose"; \
	if [ -n "$$override" ] && [ -f "$$override" ]; then set -- "$$@" -f "$$override"; fi; \
	if [ -n "$$env_file" ]; then set -- "$$@" --env-file "$$env_file"; fi; \
	set -- "$$@" logs -f; \
	"$$@"

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
	@eval "$$(COMPOSE_FILE='$(STACK_FILE)' COMPOSE_OVERRIDE='$(STACK_OVERRIDE)' $(BIN_DIR)/resolve-project-compose.sh '$(STACK_NAME)')"; \
	if [ -z "$$compose" ] || [ ! -f "$$compose" ]; then \
		echo "STACK_FILE is unset and no compose file found under $(STACK_NAME)/ (stack-compose.yml or docker-compose.yml)."; exit 1; \
	fi; \
	if [ -n "$$env_file" ]; then set -a && . "$$env_file" && set +a; fi; \
	set -- -c "$$compose"; \
	if [ -n "$$override" ] && [ -f "$$override" ]; then set -- "$$@" -c "$$override"; fi; \
	deploy_extra=""; \
	case "$(STACK_DEPLOY_WAIT)" in 1|true|yes|on) \
	  if $(DOCKER) stack deploy --help 2>/dev/null | grep -q -- '--detach'; then \
	    deploy_extra='--detach=false'; \
	  else \
	    echo >&2 "Note: $(DOCKER) stack deploy has no --detach on this host — cannot wait for rollout; use docker stack ps $(STACK_NAME)."; \
	  fi ;; \
	esac; \
	set +e; \
	$(DOCKER) stack deploy "$$@" "$(STACK_NAME)" --with-registry-auth $$deploy_extra; \
	rc=$$?; \
	if [ "$$rc" -ne 0 ]; then \
	$(DOCKER) stack deploy "$$@" "$(STACK_NAME)" --with-registry-auth $$deploy_extra; \
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

## —— Infrastructure 🐳 ————————————————————————————————————————————————————————————————
commit-changes: ## Commit changes to the infrastructure
	@echo "Committing changes to the infrastructure..."
	chmod +x $(BIN_DIR)/*.sh
	git add .
	git commit -m "Update infrastructure: $(DATETIME)"
	git push origin

setup: ## Setup infrastructure (remote: use `ssh -t host make setup` if you want a real TTY)
	@echo "Setting up infrastructure..."
	@$(BIN_DIR)/setup-environment.sh
	@$(BIN_DIR)/setup-filesystem.sh
	@$(BIN_DIR)/install-sexy-bash-prompt.sh

update-server: ## Update server
	@echo "Updating server..."
	@$(BIN_DIR)/server-update.sh

deploy-infrastructure: ## Deploy infrastructure
	@echo "Deploying infrastructure..."
	@$(BIN_DIR)/setup-swarm.sh
	@$(BIN_DIR)/deploy-infrastructure.sh

fix-dns-resolv: ## Fix DNS resolver
	@echo "Fixing DNS resolv.conf..."
	@$(BIN_DIR)/fix-dns-resolv.sh

services-list: ## List services
	@echo "Listing services..."
	@docker service ls

.create-db: ## Create database
	@echo "Creating database..."
	@# Swarm: task container name isn't stable; exec into the running task container.
	@# Requires vars: DB_USER, DB_PASS, DB_NAME
	@bash -lc 'set -euo pipefail; \
	: "$${DB_USER:?Missing DB_USER}"; : "$${DB_PASS:?Missing DB_PASS}"; : "$${DB_NAME:?Missing DB_NAME}"; \
	cid="$$(docker ps -q --filter "label=com.docker.swarm.service.name=infrastructure_postgresql" | head -n 1)"; \
	if [ -z "$$cid" ]; then \
		echo "Error: no running container found for Swarm service infrastructure_postgresql."; \
		echo "Hint: run: docker service ps infrastructure_postgresql"; \
		exit 1; \
	fi; \
	echo "Using postgresql task container: $$cid"; \
	role_exists="$$(docker exec "$$cid" psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '\''$${DB_USER}'\'';")"; \
	if [ "$$role_exists" != "1" ]; then \
		echo "Creating role $${DB_USER} ..."; \
		docker exec "$$cid" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "CREATE USER \"$${DB_USER}\" WITH PASSWORD '\''$${DB_PASS}'\'';"; \
	else \
		echo "Role $${DB_USER} already exists."; \
	fi; \
	db_exists="$$(docker exec "$$cid" psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '\''$${DB_NAME}'\'';")"; \
	if [ "$$db_exists" != "1" ]; then \
		echo "Creating database $${DB_NAME} ..."; \
		docker exec "$$cid" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$${DB_NAME}\" OWNER \"$${DB_USER}\";"; \
	else \
		echo "Database $${DB_NAME} already exists."; \
	fi'

.connect-db: ## Connect to database
	@echo "Connecting to database with user: postgres"
	@bash -lc 'set -euo pipefail; \
	cid="$$(docker ps -q --filter "label=com.docker.swarm.service.name=infrastructure_postgresql" | head -n 1)"; \
	if [ -z "$$cid" ]; then \
		echo "Error: no running container found for Swarm service infrastructure_postgresql."; \
		echo "Hint: run: docker service ps infrastructure_postgresql"; \
		exit 1; \
	fi; \
	echo "Using postgresql task container: $$cid"; \
	if [ -t 0 ] && [ -t 1 ]; then \
		docker exec -it "$$cid" psql -U postgres -d postgres; \
	else \
		docker exec -i "$$cid" psql -U postgres -d postgres; \
	fi'

# —— 🐝 git commands ———————————————————————————————————
push-udem: ## Push changes to the UDEM repository
	## push the current branch to the UDEM repository
	git push ti-udem $(CURRENT_BRANCH)

## —— 🐝 Dokploy commands ———————————————————————————————————
DOKPLOY_STACK_NAME := dokploy
DOKPLOY_SERVICES_SHORT := dokploy postgresql redis traefik
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
	$(MAKE) stack-deploy STACK_NAME=$(DOKPLOY_STACK_NAME)

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

dokploy-compose-up: ## Deploy the dokploy stack
	make docker-project-up PROJECT_NAME=$(DOKPLOY_STACK_NAME)
dokploy-compose-down: ## Remove the dokploy stack
	make docker-project-down PROJECT_NAME=$(DOKPLOY_STACK_NAME)
dokploy-compose-restart: ## Restart the dokploy stack
	make docker-project-restart PROJECT_NAME=$(DOKPLOY_STACK_NAME)
dokploy-compose-recreate: dokploy-compose-down dokploy-compose-up ## Recreate the dokploy stack
dokploy-compose-logs: ## Show logs of the dokploy stack
	make docker-project-logs PROJECT_NAME=$(DOKPLOY_STACK_NAME)
dokploy-compose-watch-logs: ## Watch logs of the dokploy stack
	make docker-project-watch PROJECT_NAME=$(DOKPLOY_STACK_NAME)
