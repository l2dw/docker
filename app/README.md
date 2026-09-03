# App (generic stack template)

Générique wrapper pour déployer **n'importe quelle image** en Swarm/Compose derrière Traefik, sans réécrire un stack par app.

## Fichiers

- `docker-compose.yml` — canonique (Make / Swarm), avec labels Traefik + Homepage.
- `compose.yml` — même stack sans labels (ingress via port publié, pas de Traefik). Contient la publication de port en forme longue (`ports: - target/published/protocol/mode`).
- `.env.example` — toutes les clés `APP_*`.
- `Makefile` — cibles `app-*`.

## Usage

```sh
cp app/.env.example app/.env
# éditer APP_IMAGE, APP_DOMAIN, APP_PORT, ...
make app-setup
make app-stack-up       # Swarm
# ou
make app-compose-up     # Compose local
```

## Réseau

Par défaut réseau local `app-network` (`DEFAULT_NETWORK_EXTERNAL=false`). Pour rejoindre l'overlay partagé Dokploy/Traefik : `DEFAULT_NETWORK_NAME=dokploy-network` + `DEFAULT_NETWORK_EXTERNAL=true`. `make app-setup` synchronise `DEFAULT_NETWORK_EXTERNAL` selon le nom choisi.

## Volume NFS

Le volume `app_data` (Docker named volume) peut être repointé vers un export **NFS** directement, sans bind mount côté hôte et sans modifier `compose.yml` / `docker-compose.yml` — uniquement via les variables d'env :

| Variable | Rôle | Défaut |
|----------|------|--------|
| `APP_DATA_VOLUME_DRIVER` | Driver du volume | `local` |
| `APP_DATA_VOLUME_DRIVER_TYPE` | Type de montage (`nfs` pour NFS) | vide (volume local normal) |
| `APP_DATA_VOLUME_DRIVER_O` | Options `-o` passées au montage (adresse serveur NFS, options `rw`/`nfsvers`, etc.) | vide |
| `APP_DATA_VOLUME_DRIVER_DEVICE` | Export distant (`:/chemin/export`) | vide |

Ces trois clés alimentent `driver_opts` du volume dans `compose.yml`/`docker-compose.yml` :

```yaml
volumes:
  app_data:
    name: ${APP_DATA_VOLUME_NAME:-app_data}
    external: ${APP_DATA_VOLUME_EXTERNAL:-false}
    driver: ${APP_DATA_VOLUME_DRIVER:-local}
    driver_opts:
      type: ${APP_DATA_VOLUME_DRIVER_TYPE:-}
      o: ${APP_DATA_VOLUME_DRIVER_O:-}
      device: ${APP_DATA_VOLUME_DRIVER_DEVICE:-}
```

Vide (défaut) = volume Docker local classique, géré par Docker. Pour monter un export NFS, dans `app/.env` :

```env
APP_DATA_VOLUME_DRIVER_TYPE=nfs
APP_DATA_VOLUME_DRIVER_O=addr=nfs-server.example.com,rw,nfsvers=4
APP_DATA_VOLUME_DRIVER_DEVICE=:/exports/app-data
```

Docker (et Swarm — chaque nœud doit avoir accès réseau au serveur NFS) montera alors directement l'export comme volume nommé, sans passer par un bind mount local ni un montage NFS manuel sur l'hôte. Fonctionne identiquement en Compose et en Swarm (`docker stack deploy`).

Pour un **bind mount** classique plutôt qu'un named volume : utiliser `APP_DATA_HOST_PATH` (chemin hôte) au lieu de toucher au driver — cf. la ligne `volumes:` du service.

## Port

`APP_PORT` = port d'écoute du conteneur (utilisé par le label Traefik `loadbalancer.server.port` dans `docker-compose.yml`).
`APP_PUBLISHED_PORT` / `APP_PORT_MODE` = uniquement dans `compose.yml` (pas de Traefik) — publication en forme longue :

```yaml
ports:
  - target: ${APP_PORT:-3000}
    published: ${APP_PUBLISHED_PORT:-30000}
    protocol: tcp
    mode: ${APP_PORT_MODE:-ingress}
```

Ne pas publier de port dans `docker-compose.yml` si Traefik gère l'ingress (labels uniquement).

## Base path

Stack générique : impossible de vérifier le support de sous-chemin app par app. Défaut `APP_BASE_PATH=/` (Host-only). Si l'app cible supporte un `base_path`, ajuster `APP_BASE_PATH` et le mapper vers la variable d'env spécifique au vendor.

## Env file

`APP_ENV_FILE` (défaut `.env.example`) est chargé via `env_file` sur le service ; `environment:` (s'il est ajouté) prévaudrait sur le fichier. `docker stack deploy` ne lit pas `env_file` de façon fiable — Swarm utilise l'export Make de `.env` racine + interpolation `environment:`.

## Debug

```sh
make app-debug
make app-debug-logs
```
