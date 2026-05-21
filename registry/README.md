# Registry

## Makefile

```sh
# Run from devops/docker-templates (parent of the registry/ folder)

## 1. copy and adjust .env from .env.example
make registry-deploy
make registry-remove
make registry-redeploy
make registry-stack-logs
make registry-stack-watch
make registry-stack-debug
# compose
make registry-up
make registry-down
make registry-recreate
make registry-compose-logs
make registry-compose-watch
```
