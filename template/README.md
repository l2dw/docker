# Tpl

## Makefile

```sh
# Run from devops/docker-templates (parent of the tpl/ folder)

## 1. copy and adjust .env from .env.example
make tpl-deploy
make tpl-remove
make tpl-redeploy
make tpl-stack-logs
make tpl-stack-watch
make tpl-stack-debug
# compose
make tpl-up
make tpl-down
make tpl-recreate
make tpl-compose-logs
make tpl-compose-watch
```
