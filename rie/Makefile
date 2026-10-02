## —— 🐝 RIE commands ———————————————————————————————————
RIE_STACK_NAME := rie
RIE_SERVICES_SHORT := app
RIE_ENV := $(RIE_STACK_NAME)/.env
RIE_ENV_EXAMPLE := $(RIE_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

rie-setup:
	@set -e; \
	envf='$(RIE_ENV)'; exf='$(RIE_ENV_EXAMPLE)'; root='$(ENV_FILE)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; fi; \
	upsert() { _f=$$1; _k=$$2; _v=$$3; tmp=$$(mktemp); awk -v k="$$_k" -v v="$$_v" 'BEGIN{done=0} index($$0,k"=")==1 {print k"="v; done=1; next} {print} END{if(!done) print k"="v}' "$$_f" > "$$tmp" && mv "$$tmp" "$$_f"; }; \
	file_get() { [ -f "$$1" ] || return 0; sed -n "s/^$$2=//p" "$$1" | head -n 1; }; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net='rie-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	case "$$ext" in true) ;; *) if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then $(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); fi ;; esac; \
	echo "RIE env OK ($$envf)."
.rie-setup: rie-setup
rie-stack-up: .rie-setup
	$(MAKE) stack-deploy STACK_NAME=$(RIE_STACK_NAME)
rie-stack-down:
	$(MAKE) stack-rm STACK_NAME=$(RIE_STACK_NAME)
rie-compose-up: .rie-setup
	$(MAKE) docker-project-up PROJECT_NAME=$(RIE_STACK_NAME)
rie-compose-down:
	$(MAKE) docker-project-down PROJECT_NAME=$(RIE_STACK_NAME)
