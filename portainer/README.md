# Portainer

Subpath URL: `http://example.com/portainer` — set in `.env`:

```env
PORTAINER_DOMAIN=example.com
PORTAINER_BASE_PATH=/portainer
PORTAINER_TRAEFIK_ENTRYPOINTS=web
PORTAINER_TRAEFIK_MIDDLEWARES=strip-prefix-portainer@docker
PORTAINER_TRUSTED_ORIGINS=example.com
```

Traefik strips `${PORTAINER_BASE_PATH}` before forwarding; Portainer runs with `--base-url=/portainer`.

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
