# Jenkins-agent

## Makefile

```sh
# Run from devops/docker-templates (parent of the dokploy/ folder)

## 1. copy and adjust .env from .env.example
STACK_NAME=jenkins-agent
make jenkins-agent-stack-deploy
make jenkins-agent-stack-up
make jenkins-agent-stack-down
make jenkins-agent-stack-recreate
make jenkins-agent-stack-logs
make jenkins-agent-stack-watch
make jenkins-agent-stack-debug
```
