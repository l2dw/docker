# Stack

`.env` is not read by `docker stack deploy`; use the helper so Traefik publishes `TRAEFIK_PORT_*` (e.g. 2080 / 20443):


```sh
# Run from devops/docker-templates (parent of the dokploy/ folder)
STACK_NAME=dokploy
set -a && source .env && set +a && docker stack deploy -c ${STACK_NAME}/stack-compose.yml ${STACK_NAME} --with-registry-auth
```

## Troubleshoot

1. Serveur TI; fix permissions

```sh
podman unshare bash -c '
  chown -R 999:999 /home/admin/appdata/dokploy/redis
  chown -R 999:999 /home/admin/appdata/logs/redis
  chown -R 999:999 /home/admin/appdata/logs/apache2
  chmod -R u+rwX /home/admin/appdata/logs/apache2
  chcon -R -t container_file_t -l s0 /home/admin/appdata/logs/apache2
'
podman start dokploy_waf_1
```
