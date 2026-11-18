# prometheus

Stack de supervision : **Prometheus** + exporters.

| Service Compose | Image | Port | Mode Swarm | Rôle |
|-----------------|-------|------|------------|------|
| `prometheus` | `docker.io/prom/prometheus:v3.16.0` | 9090 | replicated (1) | Collecte, stockage TSDB, UI (Traefik + Homepage) |
| `prometheus-node-exporter` | `docker.io/prom/node-exporter:v1.12.1` | 9100 | **global**, `dnsrr` | Métriques hôte (CPU, RAM, disques, réseau) |
| `prometheus-cadvisor` | `ghcr.io/google/cadvisor:v0.61.0` | 8080 | **global**, `dnsrr` | Métriques conteneurs |
| `prometheus-blackbox-exporter` | `docker.io/prom/blackbox-exporter:v0.29.1` | 9115 | replicated (1) | Sondes HTTP / TCP / ICMP |

Aucun port n'est publié : Prometheus est joint par Traefik, les exporters uniquement sur le réseau overlay.

## Démarrage

```sh
make prometheus-setup            # crée prometheus/.env, réseau, avertissements
make prometheus-check-config     # promtool check config
make prometheus-stack-up         # Swarm
make prometheus-compose-up       # Compose
```

`docker stack deploy` ne lit pas `.env` seul : passer par Make (export du `.env` racine).

Debug : `make prometheus-debug`, `make prometheus-debug-logs`, `make prometheus-stack-logs`.

## Fichiers

| Fichier | Contenu |
|---------|---------|
| `docker-compose.yml` | Stack complète, Traefik + Homepage (Make / Swarm) |
| `compose.yml` | Même stack sans Traefik, Homepage conservé |
| `prometheus-compose.yml` | Service `prometheus` seul |
| `node-exporter-compose.yml` | Service `prometheus-node-exporter` seul |
| `cadvisor-compose.yml` | Service `prometheus-cadvisor` seul |
| `blackbox-exporter-compose.yml` | Service `prometheus-blackbox-exporter` seul |
| `config/prometheus.yml` | Jobs de scrape |
| `config/blackbox.yml` | Modules blackbox (`http_2xx`, `http_2xx_insecure`, `tcp_connect`, `icmp`) |

## Configuration Prometheus

Les fichiers `config/*.yml` sont livrés comme **configs** Compose/Swarm (`PROMETHEUS_CONFIG_NAME`, `PROMETHEUS_BLACKBOX_EXPORTER_CONFIG_NAME`). Les configs Swarm sont immuables : après modification, incrémenter le suffixe (`prometheus_config_v2`) puis redéployer.

Jobs fournis :

- `prometheus` — auto-scrape (`metrics_path` doit inclure le base path) ;
- `node-exporter`, `cadvisor` — découverte `dns_sd_configs` (type A) sur le nom du service. En Swarm, `endpoint_mode: dnsrr` renvoie une IP par tâche, donc un target par nœud ; en Compose, le nom résout le conteneur ;
- `blackbox-exporter` — métriques propres ;
- `blackbox-http` — sondes HTTP ; ajouter les URLs dans `static_configs.targets`.

Le label `instance` des exporters est l'IP de la tâche ; le nom d'hôte est disponible via `node_uname_info{nodename=…}`.

## Base path

Prometheus supporte un sous-chemin (`--web.external-url`, `--web.route-prefix`).

| Mode | `PROMETHEUS_BASE_PATH` | `PROMETHEUS_APP_URL` | `metrics_path` du job `prometheus` |
|------|------------------------|----------------------|-------------------------------------|
| Sous-chemin (défaut) | `/prometheus` | `http://<domaine>/prometheus` | `/prometheus/metrics` |
| Sous-domaine | `/` | `http://<domaine>` | `/metrics` |

`make prometheus-setup` avertit si `metrics_path` ne correspond pas au base path. Ajuster aussi `PROMETHEUS_HOMEPAGE_SITEMONITOR` et la cible `blackbox-http`.

## Variables d'environnement

- `APP_NAME=prometheus` nomme le routeur et le service Traefik (Dokploy peut le surcharger).
- `env_file` : `PROMETHEUS_ENV_FILE`, `PROMETHEUS_NODE_EXPORTER_ENV_FILE`, `PROMETHEUS_CADVISOR_ENV_FILE`, `PROMETHEUS_BLACKBOX_EXPORTER_ENV_FILE` (défaut `.env.example`, production `.env`). `environment:` l'emporte sur le fichier. En Swarm, `env_file` n'est pas fiable : Make exporte le `.env` racine et l'interpolation `${…}` s'applique.
- Rétention : `PROMETHEUS_RETENTION_TIME` (15d), `PROMETHEUS_RETENTION_SIZE` (0 = désactivé).
- `PROMETHEUS_WEB_ENABLE_LIFECYCLE=false` par défaut : `true` expose `/-/reload` et `/-/quit` sans authentification.

## Sécurité

- Prometheus n'a **pas d'authentification** intégrée : renseigner `PROMETHEUS_MIDDLEWARES` (basicauth / forwardauth Traefik) avant d'exposer un domaine public.
- node-exporter et cAdvisor montent `/`, `/proc`, `/sys` et le répertoire Docker **en lecture seule**, sans `:z` (ne jamais réétiqueter SELinux sur `/`).
- `PROMETHEUS_CADVISOR_PRIVILEGED=false` par défaut ; la doc cAdvisor recommande `true` en Compose (Swarm ignore `privileged`).
- Hôtes Podman : `PROMETHEUS_CADVISOR_DOCKER_DIR` doit pointer vers le stockage réel ; les métriques par conteneur peuvent être incomplètes.
- Le module `icmp` du blackbox requiert `CAP_NET_RAW`, non ajouté par défaut.

## Networks

| Objectif | `DEFAULT_NETWORK_NAME` | `DEFAULT_NETWORK_EXTERNAL` |
|----------|------------------------|----------------------------|
| Overlay local à la stack (défaut) | `prometheus-network` | `false` |
| Overlay partagé Dokploy / Traefik | `dokploy-network` | `true` |

`make prometheus-setup` aligne `DEFAULT_NETWORK_EXTERNAL` sur le nom (`true` seulement pour `dokploy-network`) et crée le réseau s'il n'existe pas (`NETWORK_DRIVER=overlay` par défaut, `bridge` pour Compose seul) :

```sh
docker network create prometheus-network --driver overlay
```

Pour que Traefik atteigne Prometheus ou pour scraper d'autres stacks, rejoindre `dokploy-network`.

## Volumes

Une seule clé de volume : `data` → `${PROMETHEUS_DATA_VOLUME_DIR:-/prometheus}` (TSDB). Prometheus tourne en `nobody` (uid 65534) : un bind ou un export NFS doit être accessible en écriture par cet uid.

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|------------|--------|--------|--------|
| Local nommé (défaut) | `false` | vide | vide | vide |
| Bind | `false` | `none` | `bind` | `/appdata/prometheus` |
| NFS | `false` | `nfs` | `addr=nfs-host,rw,nfsvers=4` | `:/exports/prometheus` |
| Externe | `true` | — | — | — (`PROMETHEUS_DATA_VOLUME_NAME` = volume existant) |

```env
PROMETHEUS_DATA_VOLUME_NAME=prometheus_data
PROMETHEUS_DATA_VOLUME_TYPE=none
PROMETHEUS_DATA_VOLUME_OPTS=bind
PROMETHEUS_DATA_VOLUME_PATH=/appdata/prometheus
```

```sh
# Bind : préparer le répertoire
sudo install -d -o 65534 -g 65534 /appdata/prometheus

# Externe
docker volume create prometheus_data

# NFS
docker volume create --driver local \
  --opt type=nfs --opt o=addr=nfs.example.com,rw,nfsvers=4 \
  --opt device=:/exports/prometheus prometheus_data
```
