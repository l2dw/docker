# Rie

## Makefile

```sh
# Run from devops/docker-templates (parent of the rie/ folder)

## 1. copy and adjust .env from .env.example
make rie-deploy
make rie-remove
make rie-redeploy
make rie-stack-logs
make rie-stack-watch
make rie-stack-debug
# compose
make rie-up
make rie-down
make rie-recreate
make rie-compose-logs
make rie-compose-watch
```
