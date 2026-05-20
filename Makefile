# include .env.local
VERSION := v$(shell date +%Y.%m.%d)
DATETIME := $(shell date '+%Y.%m.%d %H:%M:%S')
ENV=prod

# APPDATA_DIR=/appdata
# CONF_DIR=/infra
# INFRA_DIR=/infra
# LOGS_DIR=$(APPDATA_DIR)/logs
BIN_DIR=./bin
# BACKUPS_DIR=$(APPDATA_DIR)/backups

# Executables


USE_CACHE = "yes"


# Misc
.DEFAULT_GOAL = help
.PHONY        : # Not needed here, but you can put your all your targets to be sure
                # there is no name conflict between your files and your targets.

## —— 🐝 The Makefile 🐝 ———————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

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
	@$(BIN_DIR)/fix-profilerc.sh
	@# TODO: Install sexy-bash-prompt if not installed
	@if [ ! -f /etc/profile.d/zz-bash_prompt.sh ]; then \
		$(BIN_DIR)/install-sexy-bash-prompt.sh; \
	fi
	@$(BIN_DIR)/install-utilities-packages.sh
	@$(BIN_DIR)/install-docker-ce.sh
	@$(BIN_DIR)/fix-dns-resolv.sh

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

create-db: ## Create database
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

connect-db: ## Connect to database
	@echo "Connecting to database with user: postgres"
	@bash -lc 'set -euo pipefail; \
	cid="$$(docker ps -q --filter "label=com.docker.swarm.service.name=infrastructure_postgresql" | head -n 1)"; \
	if [ -z "$$cid" ]; then \
		echo "Error: no running container found for Swarm service infrastructure_postgresql."; \
		echo "Hint: run: docker service ps infrastructure_postgresql"; \
		exit 1; \
	fi; \
	echo "Using postgresql task container: $$cid"; \
	# Use -it only when we have a TTY (prevents failures when run over non-interactive SSH).\n\
	if [ -t 0 ] && [ -t 1 ]; then \
		docker exec -it "$$cid" psql -U postgres -d postgres; \
	else \
		docker exec -i "$$cid" psql -U postgres -d postgres; \
	fi'
