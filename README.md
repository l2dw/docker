# docker-templates

Socle Make + scripts pour déployer des stacks Docker (Compose / Swarm) et bootstrapper un nœud.

## Démarrage

```sh
make help
```

Documentation Make / **`make setup`** : [`docs/MAKE.md`](docs/MAKE.md).

Variables d’exemple : [`.env.example`](.env.example). Aliases git installés par setup : [`etc/gitconfig`](etc/gitconfig).

## Generic app compose (root)

Scaffold générique (`APP_*`) à la racine — une branche stack dédiée reste le modèle pour une app réelle (`create-docker-stack` / skill **docker-composer**).

| File | Role |
|------|------|
| `compose.yml` | Base + Homepage labels + network aliases |
| `docker-compose.yml` | Same as compose (Homepage only, no Traefik) |
| `web.docker-compose.yml` | HTTP Traefik + Homepage (**pas de `ports:`**) |
| `tcp.docker-compose.yml` | TCP Traefik + long-form `ports:` + Homepage |

Pick the compose file in Dokploy / `docker stack deploy -c …`. Overlay DNS aliases: `${APP_NAME}` and `${APP_ALIAS}`.
### Networks

```yaml
networks:
  default:
    name: ${DEFAULT_NETWORK_NAME:-app-network}
    external: ${DEFAULT_NETWORK_EXTERNAL:-false}
```

| Goal | `DEFAULT_NETWORK_NAME` | `EXTERNAL` | Who creates it |
|------|------------------------|------------|----------------|
| Stack-local (template default in compose) | `app-network` | `false` | Swarm / Compose (below) |
| Dokploy / Traefik | `dokploy-network` | `true` | Infra — join only |

```sh
docker network create app-network --driver overlay   # Swarm
docker network create app-network --driver bridge    # Compose
```

### Volumes

Compose key **`data`** → `${APP_DATA_VOLUME_DIR:-/data}` :

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|------------|--------|--------|--------|
| **Local named** (default) | `false` | empty | empty | empty |
| **Bind** | `false` | `none` | `bind` | `/appdata/app` |
| **NFS** | `false` | `nfs` | `addr=host,rw,nfsvers=4` | `:/exports/app` |
| **External** | `true` | — | — | — |

```env
# Local named
APP_DATA_VOLUME_TYPE=
APP_DATA_VOLUME_OPTS=
APP_DATA_VOLUME_PATH=
APP_DATA_VOLUME_DIR=/data

# Bind
APP_DATA_VOLUME_TYPE=none
APP_DATA_VOLUME_OPTS=bind
APP_DATA_VOLUME_PATH=/appdata/app

# NFS
APP_DATA_VOLUME_TYPE=nfs
APP_DATA_VOLUME_OPTS=addr=nfs.example.com,rw,nfsvers=4
APP_DATA_VOLUME_PATH=:/exports/app
```

```sh
docker volume create app_data
docker volume create --driver local \
  --opt type=nfs --opt o=addr=nfs.example.com,rw,nfsvers=4 \
  --opt device=:/exports/app app_data
mkdir -p /appdata/app
```
