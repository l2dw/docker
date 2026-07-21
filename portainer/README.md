# Portainer

Subpath URL: `http://example.com/portainer` — set in `.env`:

```env
PORTAINER_DOMAIN=example.com
PORTAINER_BASE_PATH=/portainer
PORTAINER_TRAEFIK_ENTRYPOINTS=web
PORTAINER_TRAEFIK_MIDDLEWARES=stripprefix-portainer
PORTAINER_TRUSTED_ORIGINS=example.com
```

Traefik strips `${PORTAINER_BASE_PATH}` before forwarding; Portainer runs with `--base-url=/portainer`.

## Makefile

```sh
# Run from devops/docker-templates (parent of the app folder)
make portainer-pull-images
make portainer-stack-up
make portainer-stack-down
make portainer-stack-recreate
make portainer-stack-logs
make portainer-stack-watch-logs
make portainer-debug
make portainer-debug-logs
# compose
make portainer-compose-upgrade
make portainer-compose-up
make portainer-compose-down
make portainer-compose-recreate
make portainer-compose-logs
make portainer-compose-watch-logs
```
