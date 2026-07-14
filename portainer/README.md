# Portainer

## Makefile

```sh
# Run from devops/docker-templates (parent of the portainer/ folder)

## 1. copy and adjust .env from .env.example
make portainer-pull-images
make portainer-deploy
make portainer-remove
make portainer-redeploy
make portainer-stack-logs
make portainer-stack-watch
make portainer-stack-debug
# compose
make portainer-compose-upgrade
make portainer-compose-up
make portainer-compose-down
make portainer-compose-recreate
make portainer-compose-logs
make portainer-compose-watch
```
