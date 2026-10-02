## —— 🐝 Jenkins Agent commands ———————————————————————————————————
JENKINS_AGENT_STACK_NAME := jenkins-agent
JENKINS_AGENT_SERVICES_SHORT := jenkins-agent
JENKINS_AGENT_ENV := $(JENKINS_AGENT_STACK_NAME)/.env
JENKINS_AGENT_ENV_EXAMPLE := $(JENKINS_AGENT_STACK_NAME)/.env.example
NETWORK_DRIVER ?= overlay

jenkins-agent-pull-images:
	$(MAKE) docker-pull-images PROJECT_NAME=$(JENKINS_AGENT_STACK_NAME)
jenkins-agent-setup:
	@set -e; \
	envf='$(JENKINS_AGENT_ENV)'; exf='$(JENKINS_AGENT_ENV_EXAMPLE)'; root='$(ENV_FILE)'; \
	if [ ! -f "$$exf" ]; then echo "Error: missing $$exf" >&2; exit 1; fi; \
	if [ ! -f "$$envf" ]; then cp "$$exf" "$$envf"; fi; \
	upsert() { _f=$$1; _k=$$2; _v=$$3; tmp=$$(mktemp); awk -v k="$$_k" -v v="$$_v" 'BEGIN{done=0} index($$0,k"=")==1 {print k"="v; done=1; next} {print} END{if(!done) print k"="v}' "$$_f" > "$$tmp" && mv "$$tmp" "$$_f"; }; \
	file_get() { [ -f "$$1" ] || return 0; sed -n "s/^$$2=//p" "$$1" | head -n 1; }; \
	net=$$(file_get "$$envf" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net=$$(file_get "$$root" DEFAULT_NETWORK_NAME); [ -n "$$net" ] || net='jenkins-agent-network'; \
	case "$$net" in dokploy-network) ext=true ;; *) ext=false ;; esac; \
	upsert "$$envf" DEFAULT_NETWORK_NAME "$$net"; upsert "$$envf" DEFAULT_NETWORK_EXTERNAL "$$ext"; \
	if [ -n "$$root" ]; then upsert "$$root" DEFAULT_NETWORK_NAME "$$net"; upsert "$$root" DEFAULT_NETWORK_EXTERNAL "$$ext"; fi; \
	echo "DEFAULT_NETWORK_NAME=$$net → DEFAULT_NETWORK_EXTERNAL=$$ext"; \
	case "$$ext" in true) ;; *) if ! $(DOCKER) network ls --format '{{.Name}}' | grep -qx "$$net"; then $(DOCKER) network create "$$net" --driver $(NETWORK_DRIVER); fi ;; esac; \
	echo "Jenkins Agent env OK ($$envf)."
.jenkins-agent-setup: jenkins-agent-setup
jenkins-agent-stack-up: .jenkins-agent-setup
	$(MAKE) stack-deploy STACK_NAME=$(JENKINS_AGENT_STACK_NAME)
jenkins-agent-stack-down:
	$(MAKE) stack-rm STACK_NAME=$(JENKINS_AGENT_STACK_NAME)
jenkins-agent-compose-up: .jenkins-agent-setup
	$(MAKE) docker-project-up PROJECT_NAME=$(JENKINS_AGENT_STACK_NAME)
jenkins-agent-compose-down:
	$(MAKE) docker-project-down PROJECT_NAME=$(JENKINS_AGENT_STACK_NAME)
