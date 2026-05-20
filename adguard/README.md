# Adguard

## Makefile

```sh
# Run from devops/docker-templates (parent of the adguard/ folder)

## 1. copy and adjust .env from .env.example
make adguard-deploy
make adguard-remove
make adguard-redeploy
make adguard-stack-logs
make adguard-stack-watch
make adguard-stack-debug
# compose
make adguard-up
make adguard-down
make adguard-recreate
make adguard-compose-logs
make adguard-compose-watch
```
