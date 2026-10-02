## —— 🐝 Jenkins commands ———————————————————————————————————
JENKINS_STACK_NAME := jenkins
JENKINS_SERVICES_SHORT := jenkins
JENKINS_ENV := $(JENKINS_STACK_NAME)/.env
JENKINS_ENV_EXAMPLE := $(JENKINS_STACK_NAME)/.env.example
JENKINS_NOTIFY_VARS := JENKINS_DOMAIN
NETWORK_DRIVER ?= overlay

jenkins-pull-images:
	$(MAKE) docker-pull-images PROJECT_NAME=$(JENKINS_STACK_NAME)
jenkins-setup:
	@set -e; \
	envf='$(JENKINS_ENV)'; exf='$(JENKINS_ENV_EXAMPLE)'; root='$(ENV_FILE)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; fi; \
	upsert() { _f=$$1; _k=$$2; _v=$$3; tmp=$$(mktemp); awk -v k="$$_k" -v v="$$_v" 'BEGIN{done=0} index($$0,k"=")==1 {print k"="v; done=1; next} {print} END{if(!done) print k"="v}' "$$_f" > "$$tmp" && mv "$$tmp" "$$_f"; }; \
	file_get() { [ -f "$$1" ] || return 0; sed -n "s/^$$2=//p" "$$1" | head -n 1; }; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net='jenkins-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	case "$$ext" in true) ;; *) if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then $(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); fi ;; esac; \
	echo "Jenkins env OK ($$envf)."
.jenkins-setup: jenkins-setup
jenkins-stack-up: .jenkins-setup
	$(MAKE) stack-deploy STACK_NAME=$(JENKINS_STACK_NAME)
jenkins-stack-down:
	$(MAKE) stack-rm STACK_NAME=$(JENKINS_STACK_NAME)
jenkins-stack-recreate: jenkins-stack-down jenkins-stack-up
jenkins-stack-upgrade: .jenkins-setup
	$(MAKE) docker-pull-images PROJECT_NAME=$(JENKINS_STACK_NAME)
	$(MAKE) stack-deploy STACK_NAME=$(JENKINS_STACK_NAME)
jenkins-stack-logs:
	$(MAKE) stack-logs STACK_NAME=$(JENKINS_STACK_NAME)
jenkins-compose-up: .jenkins-setup
	$(MAKE) docker-project-up PROJECT_NAME=$(JENKINS_STACK_NAME)
jenkins-compose-down:
	$(MAKE) docker-project-down PROJECT_NAME=$(JENKINS_STACK_NAME)
jenkins-compose-logs:
	$(MAKE) docker-project-logs PROJECT_NAME=$(JENKINS_STACK_NAME)
