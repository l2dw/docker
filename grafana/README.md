# grafana

**Grafana** (`docker.io/grafana/grafana:13.3.1`, port 3000) avec datasource Prometheus et dashboards **provisionnés** (lecture seule dans l'UI).

| Dashboard | Source grafana.com | Données |
|-----------|--------------------|---------|
| Node Exporter Full | 1860 rév. 46 | node-exporter |
| cadvisor dashboard | 19792 rév. 6 | cAdvisor |
| Blackbox Exporter (HTTP prober) | 13659 rév. 1 | blackbox-exporter |
| Prometheus 2.0 Overview | 3662 rév. 2 | Prometheus |

Les dashboards sont stockés dans `config/dashboards/` (JSON compacté, `${DS_*}` remplacé par l'uid `prometheus`, `id` nul, `uid` fixe `cen-*`). Stack compagnon : `prometheus` (branche `prometheus`). Node Exporter Full et cadvisor ont une variable **Cluster** (`label_values(…, cluster)`) appliquée à toutes les requêtes : le serveur central étiquette ses cibles `cluster=<serveur>` et les agents distants ajoutent leur label externe `cluster`.

## Démarrage

```sh
make grafana-setup          # crée grafana/.env, réseau, génère ADMIN_PASSWORD / SECRET_KEY si vides
make grafana-stack-up       # Swarm
make grafana-compose-up     # Compose
```

`docker stack deploy` ne lit pas `.env` seul : passer par Make (export du `.env` racine). Debug : `make grafana-debug`, `make grafana-debug-logs`.

## Fichiers

| Fichier | Contenu |
|---------|---------|
| `docker-compose.yml` | Service `grafana`, Traefik + Homepage (Make / Swarm) |
| `compose.yml` | Même service sans Traefik, Homepage conservé (domaines Dokploy) |
| `config/provisioning/datasources/prometheus.yml` | Datasource `Prometheus` (uid `prometheus`, URL `${GRAFANA_PROMETHEUS_URL}`) |
| `config/provisioning/dashboards/default.yml` | Provider fichier → dossier `Infrastructure` |
| `config/dashboards/*.json` | Dashboards |

Tout le provisioning est livré en **configs** Compose/Swarm. Les configs Swarm sont immuables : après modification d'un fichier, incrémenter le `*_CONFIG_NAME` correspondant (`_v2`) puis redéployer.

## Base de données

`GRAFANA_DB_TYPE=sqlite3` par défaut (fichier dans le volume `data`). Pour PostgreSQL :

```env
GRAFANA_DB_TYPE=postgres
GRAFANA_DB_HOST=postgresql:5432
GRAFANA_DB_NAME=grafana
GRAFANA_DB_USER=grafana
GRAFANA_DB_PASSWORD=          # secret
```

La base et le rôle doivent exister (`CREATE DATABASE grafana OWNER grafana`) ; Grafana crée son schéma au premier démarrage.

## Secrets et Dokploy (OpenBao)

Secrets : `GRAFANA_ADMIN_PASSWORD`, `GRAFANA_SECRET_KEY`, `GRAFANA_DB_PASSWORD` (jamais dans Git). Sur Dokploy avec Vault Provider, l'environnement ne contient que des références :

```env
GRAFANA_ADMIN_PASSWORD=${{vault.<infra>.grafana:ADMIN_PASSWORD}}
GRAFANA_ROOT_URL=${{vault.<infra>.grafana/config:ROOT_URL}}
```

`GRAFANA_SECRET_KEY` chiffre les secrets stockés en base (datasources) : ne pas le changer après le premier démarrage.

## Authentification OIDC (Keycloak)

Désactivée par défaut. Activer avec `GRAFANA_OAUTH_ENABLED=true`, `GRAFANA_OAUTH_ISSUER=https://<keycloak>/realms/<realm>` (ou `…/auth/realms/<realm>`), `GRAFANA_OAUTH_CLIENT_ID`, `GRAFANA_OAUTH_CLIENT_SECRET` (secret). Les URL auth/token/userinfo sont dérivées de l'issuer ; PKCE activé.

Client Keycloak : confidentiel, flux standard, PKCE S256, redirect `<GRAFANA_ROOT_URL>login/generic_oauth`, rôles client `admin` / `editor` / `viewer` mappés dans la claim `roles` (ID token + userinfo). Rôle Grafana : `GRAFANA_OAUTH_ROLE_ATTRIBUTE_PATH` (défaut : admin → Admin, editor → Editor, sinon Viewer). La connexion locale (admin) reste disponible (`GRAFANA_OAUTH_AUTO_LOGIN=false`).

Si le conteneur ne résout pas l'issuer (DNS de l'hôte), `GRAFANA_EXTRA_HOST=<nom>:<ip>` ajoute une entrée `/etc/hosts` (contournement ; corriger le DNS de l'hôte de préférence).

## Base path

Grafana supporte un sous-chemin : `GRAFANA_ROOT_URL=https://<domaine>/grafana/` + `GRAFANA_SERVE_FROM_SUB_PATH=true`, Traefik `PathPrefix(/grafana)` sans stripPrefix. Sous-domaine : `GRAFANA_BASE_PATH=/`, `GRAFANA_ROOT_URL=https://<domaine>/`, `GRAFANA_SERVE_FROM_SUB_PATH=false`.

## Variables d'environnement

- `APP_NAME=grafana` nomme le routeur et le service Traefik (Dokploy peut le surcharger).
- `GRAFANA_ENV_FILE` (défaut `.env.example`, production `.env`) ; `environment:` l'emporte sur le fichier. En Swarm, `env_file` n'est pas fiable : Make exporte le `.env` racine.
- `GRAFANA_COOKIE_SECURE=true` derrière HTTPS.
- Inscription, rapports d'usage, vérification des mises à jour et fil d'actualités désactivés.

## Networks

| Objectif | `DEFAULT_NETWORK_NAME` | `DEFAULT_NETWORK_EXTERNAL` |
|----------|------------------------|----------------------------|
| Overlay local à la stack (défaut) | `grafana-network` | `false` |
| Overlay partagé Dokploy / Traefik | `dokploy-network` | `true` |

`make grafana-setup` aligne `DEFAULT_NETWORK_EXTERNAL` sur le nom et crée le réseau s'il n'existe pas. Pour joindre Prometheus et une base partagée, rejoindre `dokploy-network`.

```sh
docker network create grafana-network --driver overlay
```

## Volumes

Une clé : `data` → `${GRAFANA_DATA_VOLUME_DIR:-/var/lib/grafana}` (plugins, sqlite si utilisé). Grafana tourne en uid 472.

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|------------|--------|--------|--------|
| Local nommé (défaut) | `false` | vide | vide | vide |
| Bind | `false` | `none` | `bind` | `/appdata/grafana` |
| NFS | `false` | `nfs` | `addr=nfs-host,rw,nfsvers=4` | `:/exports/grafana` |
| Externe | `true` | — | — | — |

```sh
sudo install -d -o 472 -g 472 /appdata/grafana   # bind
docker volume create grafana_data                # externe
docker volume create --driver local --opt type=nfs \
  --opt o=addr=nfs.example.com,rw,nfsvers=4 --opt device=:/exports/grafana grafana_data
```
