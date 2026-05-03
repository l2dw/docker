# Tpl

## Makefile

```sh
# Run from devops/docker-templates (parent of the dokploy/ folder)

## 1. copy and adjust .env from .env.example
STACK_NAME=tpl
make tpl-stack-deploy
make tpl-stack-up
make tpl-stack-down
make tpl-stack-recreate
make tpl-stack-logs
make tpl-stack-watch
make tpl-stack-debug
```
