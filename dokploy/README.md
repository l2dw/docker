# Stack

`.env` is not read by `docker stack deploy`; use the helper so Traefik publishes `TRAEFIK_PORT_*` (e.g. 2080 / 20443):


```sh
# Run from devops/docker-templates (parent of the dokploy/ folder)
STACK_NAME=dokploy
set -a && source .env && set +a && docker stack deploy -c ${STACK_NAME}/stack-compose.yml ${STACK_NAME} --with-registry-auth
```
