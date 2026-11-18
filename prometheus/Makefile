## —— 🐝 Prometheus commands ———————————————————————————————————
PROMETHEUS_STACK_NAME := prometheus
PROMETHEUS_SERVICES_SHORT := prometheus prometheus-node-exporter prometheus-cadvisor prometheus-blackbox-exporter
PROMETHEUS_ENV := $(PROMETHEUS_STACK_NAME)/.env
PROMETHEUS_ENV_EXAMPLE := $(PROMETHEUS_STACK_NAME)/.env.example
PROMETHEUS_CONFIG := $(PROMETHEUS_STACK_NAME)/config/prometheus.yml
PROMETHEUS_NOTIFY_VARS := PROMETHEUS_DOMAIN PROMETHEUS_APP_URL
NETWORK_DRIVER ?= overlay

prometheus-pull-images: ## Pull images for the prometheus stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-setup: ## Ensure prometheus/.env, warn on placeholder domain/base path, sync DEFAULT_NETWORK_EXTERNAL
	@set -e; \
	envf='$(PROMETHEUS_ENV)'; \
	exf='$(PROMETHEUS_ENV_EXAMPLE)'; \
	root='$(ENV_FILE)'; \
	cfg='$(PROMETHEUS_CONFIG)'; \
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
	get() { _v=$$(file_get "$$envf" "$$1"); [ -n "$$_v" ] || _v=$$(file_get "$$root" "$$1"); printf '%s' "$$_v"; }; \
	net=$$(get DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='prometheus-network'; \
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
	for k in $(PROMETHEUS_NOTIFY_VARS); do \
		v=$$(get "$$k"); \
		case "$$v" in \
			*example.com*) echo "Warning: $$k=$$v still uses example.com — set the real value in $$envf" >&2 ;; \
		esac; \
	done; \
	bp=$$(get PROMETHEUS_BASE_PATH); \
	[ -n "$$bp" ] || bp=/; \
	mp=$$(awk '/job_name: prometheus$$/{f=1;next} f && /metrics_path:/{print $$2; exit}' "$$cfg"); \
	want="$${bp%/}/metrics"; \
	if [ -n "$$mp" ] && [ "$$mp" != "$$want" ]; then \
		echo "Warning: PROMETHEUS_BASE_PATH=$$bp but $$cfg job prometheus uses metrics_path $$mp (expected $$want)." >&2; \
	fi; \
	echo "Prometheus env OK ($$envf)."
.prometheus-setup: prometheus-setup
prometheus-stack-up: .prometheus-setup ## Deploy the prometheus stack
	$(MAKE) stack-deploy STACK_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-stack-down: ## Remove the prometheus stack
	$(MAKE) stack-rm STACK_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-stack-recreate: prometheus-stack-down prometheus-stack-up ## Recreate the prometheus stack
prometheus-stack-upgrade: ## Upgrade prometheus swarm images (pull + deploy)
	$(MAKE) docker-pull-images PROJECT_NAME=$(PROMETHEUS_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-stack-logs: ## Show logs of the prometheus stack
	$(MAKE) stack-logs STACK_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-stack-watch-logs: ## Watch logs of the prometheus stack
	$(MAKE) stack-watch-logs STACK_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-debug: ## Debug prometheus swarm stack
	@echo "--- docker stack services ($(PROMETHEUS_STACK_NAME))"
	@$(DOCKER) stack services $(PROMETHEUS_STACK_NAME) 2>/dev/null || echo "(stack missing or swarm unavailable)"
	@echo
	@echo "--- docker stack ps --no-trunc ($(PROMETHEUS_STACK_NAME))"
	@$(DOCKER) stack ps $(PROMETHEUS_STACK_NAME) --no-trunc
prometheus-debug-logs: ## Tail recent logs for each prometheus service
	@for s in $(PROMETHEUS_SERVICES_SHORT); do \
		echo "==================== $(PROMETHEUS_STACK_NAME)_$$s ===================="; \
		$(DOCKER) service logs "$(PROMETHEUS_STACK_NAME)_$$s" --tail 50 --timestamps 2>&1 || echo "(no logs or service missing)"; \
		echo; \
	done
prometheus-check-config: ## Validate prometheus/config/prometheus.yml with promtool (one-shot container)
	$(DOCKER) run --rm -i --entrypoint sh $(or $(PROMETHEUS_IMAGE),docker.io/prom/prometheus:v3.16.0) \
		-c 'cat > /tmp/prometheus.yml && promtool check config --syntax-only /tmp/prometheus.yml' < $(PROMETHEUS_CONFIG)
prometheus-compose-upgrade: ## Upgrade the prometheus compose project
	$(MAKE) docker-project-upgrade PROJECT_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-compose-up: .prometheus-setup ## Deploy prometheus (compose)
	$(MAKE) docker-project-up PROJECT_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-compose-down: ## Remove prometheus (compose)
	$(MAKE) docker-project-down PROJECT_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-compose-restart: ## Restart prometheus (compose)
	$(MAKE) docker-project-restart PROJECT_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-compose-recreate: prometheus-compose-down prometheus-compose-up ## Recreate prometheus (compose)
prometheus-compose-logs: ## Show prometheus compose logs
	$(MAKE) docker-project-logs PROJECT_NAME=$(PROMETHEUS_STACK_NAME)
prometheus-compose-watch-logs: ## Watch prometheus compose logs
	$(MAKE) docker-project-watch PROJECT_NAME=$(PROMETHEUS_STACK_NAME)
