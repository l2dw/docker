## —— 🐝 ByteStash commands ———————————————————————————————————
BYTESTASH_STACK_NAME := bytestash
BYTESTASH_SERVICES_SHORT := bytestash
BYTESTASH_ENV := $(BYTESTASH_STACK_NAME)/.env
BYTESTASH_ENV_EXAMPLE := $(BYTESTASH_STACK_NAME)/.env.example
BYTESTASH_SECRET_VARS := BYTESTASH_JWT_SECRET
BYTESTASH_NOTIFY_VARS := BYTESTASH_DOMAIN
NETWORK_DRIVER ?= overlay

bytestash-pull-images: ## Pull images for the bytestash stack
	$(MAKE) docker-pull-images PROJECT_NAME=$(BYTESTASH_STACK_NAME)
bytestash-setup: ## Ensure bytestash/.env, generate JWT_SECRET, sync network
	@set -e; \
	envf='$(BYTESTASH_ENV)'; \
	exf='$(BYTESTASH_ENV_EXAMPLE)'; \
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
			BYTESTASH_JWT_SECRET) printf '%s' '$(BYTESTASH_JWT_SECRET)' ;; \
			BYTESTASH_DOMAIN) printf '%s' '$(BYTESTASH_DOMAIN)' ;; \
		esac; \
	}; \
	for k in $(BYTESTASH_SECRET_VARS); do \
		v=$$(make_get "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then \
			v=$$(openssl rand -hex 32); \
			upsert "$$envf" "$$k" "$$v"; \
			if [ -n "$$root" ]; then upsert "$$root" "$$k" "$$v"; fi; \
			echo "Generated $$k → $$envf."; \
		fi; \
	done; \
	missing=0; \
	for k in $(BYTESTASH_NOTIFY_VARS); do \
		from_make=$$(make_get "$$k"); \
		v=$$from_make; \
		[ -n "$$v" ] || v=$$(file_get "$$envf" "$$k"); \
		[ -n "$$v" ] || v=$$(file_get "$$root" "$$k"); \
		if [ -z "$$v" ]; then echo "Missing $$k" >&2; missing=1; continue; fi; \
		if [ -n "$$from_make" ]; then upsert "$$envf" "$$k" "$$from_make"; fi; \
		case "$$v" in *example.com*) echo "Warning: $$k=$$v uses example.com" >&2 ;; esac; \
	done; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); \
	[ -n "$$net" ] || net='bytestash-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; \
	upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	case "$$ext" in true) ;; *) \
		if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then \
			$(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); \
		fi ;; \
	esac; \
	if [ "$$missing" -ne 0 ]; then exit 1; fi; \
	echo "ByteStash env OK ($$envf)."
.bytestash-setup: bytestash-setup
bytestash-stack-up: .bytestash-setup
	$(MAKE) stack-deploy STACK_NAME=$(BYTESTASH_STACK_NAME)
bytestash-stack-down:
	$(MAKE) stack-rm STACK_NAME=$(BYTESTASH_STACK_NAME)
bytestash-stack-recreate: bytestash-stack-down bytestash-stack-up
bytestash-stack-upgrade: .bytestash-setup
	$(MAKE) docker-pull-images PROJECT_NAME=$(BYTESTASH_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(BYTESTASH_STACK_NAME)
bytestash-stack-logs:
	$(MAKE) stack-logs STACK_NAME=$(BYTESTASH_STACK_NAME)
bytestash-compose-up: .bytestash-setup
	$(MAKE) docker-project-up PROJECT_NAME=$(BYTESTASH_STACK_NAME)
bytestash-compose-down:
	$(MAKE) docker-project-down PROJECT_NAME=$(BYTESTASH_STACK_NAME)
bytestash-compose-logs:
	$(MAKE) docker-project-logs PROJECT_NAME=$(BYTESTASH_STACK_NAME)
