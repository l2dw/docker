# Bytestash

## Makefile

```sh
# Run from devops/docker-templates (parent of the bytestash/ folder)

## 1. copy and adjust .env from .env.example
make bytestash-deploy
make bytestash-remove
make bytestash-redeploy
make bytestash-stack-logs
make bytestash-stack-watch
make bytestash-stack-debug
# compose
make bytestash-up
make bytestash-down
make bytestash-recreate
make bytestash-compose-logs
make bytestash-compose-watch
```
