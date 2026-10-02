## —— 🐝 S3 Client commands ———————————————————————————————————
S3_CLIENT_STACK_NAME := s3-client
S3_CLIENT_SERVICES_SHORT := s3-client
S3_CLIENT_ENV := $(S3_CLIENT_STACK_NAME)/.env
S3_CLIENT_ENV_EXAMPLE := $(S3_CLIENT_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

s3-client-pull-images:
	$(MAKE) docker-pull-images PROJECT_NAME=$(S3_CLIENT_STACK_NAME)
s3-client-setup:
	@set -e; \
	envf='$(S3_CLIENT_ENV)'; exf='$(S3_CLIENT_ENV_EXAMPLE)'; root='$(ENV_FILE)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; fi; \
	upsert() { _f=$$1; _k=$$2; _v=$$3; tmp=$$(mktemp); awk -v k="$$_k" -v v="$$_v" 'BEGIN{done=0} index($$0,k"=")==1 {print k"="v; done=1; next} {print} END{if(!done) print k"="v}' "$$_f" > "$$tmp" && mv "$$tmp" "$$_f"; }; \
	file_get() { [ -f "$$1" ] || return 0; sed -n "s/^$$2=//p" "$$1" | head -n 1; }; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net='s3-client-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	case "$$ext" in true) ;; *) if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then $(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); fi ;; esac; \
	echo "S3 Client env OK ($$envf)."
.s3-client-setup: s3-client-setup
s3-client-stack-up: .s3-client-setup
	$(MAKE) stack-deploy STACK_NAME=$(S3_CLIENT_STACK_NAME)
s3-client-stack-down:
	$(MAKE) stack-rm STACK_NAME=$(S3_CLIENT_STACK_NAME)
s3-client-compose-up: .s3-client-setup
	$(MAKE) docker-project-up PROJECT_NAME=$(S3_CLIENT_STACK_NAME)
s3-client-compose-down:
	$(MAKE) docker-project-down PROJECT_NAME=$(S3_CLIENT_STACK_NAME)
