# Minio-client

## Makefile

```sh
# Run from devops/docker-templates (parent of the dokploy/ folder)

## 1. copy and adjust .env from .env.example
STACK_NAME=minio-client
make minio-client-stack-deploy
make minio-client-stack-up
make minio-client-stack-down
make minio-client-stack-recreate
make minio-client-stack-logs
make minio-client-stack-watch
make minio-client-stack-debug
```
