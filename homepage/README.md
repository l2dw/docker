# Homepage stack

Homepage is deployed as a single Docker Swarm service behind the existing Traefik instance.
The service reads the Docker socket to display Docker resources; keep `HOMEPAGE_PRIVILEGED=false` unless the image requires otherwise.

## Configuration

Copy `.env.example` to `.env` and set the host/domain and bind path values. The stack joins the existing `dokploy-network` by default so Traefik can reach it. Set `DEFAULT_NETWORK_NAME` and `DEFAULT_NETWORK_EXTERNAL` together when using another network.

The Swarm placement constraint is controlled by:

```dotenv
HOMEPAGE_PLACEMENT_CONSTRAINTS=node.role==manager
```

## Validation

```bash
docker compose -f homepage/docker-compose.yml --env-file homepage/.env.example config
docker stack config -c homepage/stack-compose.yml
```

## Make targets

```bash
make homepage-pull-images
make homepage-stack-up
make homepage-stack-logs
make homepage-stack-debug
```
