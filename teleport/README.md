# Teleport

[Teleport Community Edition](https://goteleport.com/docs/installation/docker/) — bastion d’accès **SSH**, **RDP** (bureaux Windows via agents), bases, K8s, etc. Ce stack déploie **Auth + Proxy** dans un conteneur (`public.ecr.aws/gravitational/teleport-distroless:18.10.0`). UI Web **HTTPS 3080** (Traefik termine TLS devant ; le backend parle HTTPS Teleport). Auth **3025** (interne cluster).

Les **cibles** (VM Linux, Windows, K8s…) rejoignent le cluster via un **agent Teleport** — pas via des ports SSH/RDP publiés sur ce conteneur.

Default network: `teleport-network` (`EXTERNAL=false`). Pour Traefik Dokploy: `DEFAULT_NETWORK_NAME=dokploy-network` + `DEFAULT_NETWORK_EXTERNAL=true`, puis `make teleport-setup`.

`APP_NAME` scopes Traefik names (`${APP_NAME:-teleport}`). Listed in `.env.example` (default `teleport`).

## Quick start

```sh
make teleport-setup TELEPORT_DOMAIN=teleport.example.com TELEPORT_APP_URL=https://teleport.example.com
make teleport-compose-up   # or: make teleport-stack-up
```

Premier admin (image distroless — pas de shell ; `tctl` comme commande du conteneur):

```sh
docker compose -f teleport/docker-compose.yml exec teleport \
  tctl users add admin --roles=editor,access
```

Ne **pas** ajouter un `command:` Compose avec un second `teleport start` (erreur `unexpected start`).

Swarm: `docker stack deploy` ne lit pas `.env` seul — utiliser Make.

## Bastion — SSH, RDP, agents

| Rôle | Où | Accès |
|------|-----|--------|
| **Cluster** (Auth + Proxy) | Ce stack | UI `https://TELEPORT_DOMAIN`, API proxy multiplex |
| **Agent SSH** | Sur chaque serveur Linux | `teleport start` avec token/join → enregistre la cible |
| **Agent Desktop (RDP)** | Sur Windows ou jump host | `desktop_service` pour bureaux Windows ([doc Desktop Access](https://goteleport.com/docs/desktop-access/)) |
| **Client** | Poste admin | [`tsh`](https://goteleport.com/docs/connect-your-client/tsh/) ou UI Web |

Flux typique SSH:

```sh
# Installer tsh (client)
# macOS: brew install teleport

tsh login --proxy=teleport.example.com:443 --user=admin
tsh ls
tsh ssh user@hostname
```

Joindre un **agent** sur un serveur (hors de ce compose — une fois le cluster up):

```sh
# Sur le cluster (manager)
docker compose -f teleport/docker-compose.yml exec teleport tctl tokens add --type=node

# Sur le serveur cible (exemple binaire ou conteneur agent)
teleport start --token=<token> --auth-server=teleport.example.com:443
```

RDP: activer `desktop_service` dans la config agent / ressource Windows — le proxy route via le même `public_addr` (`TELEPORT_PUBLIC_ADDR`, défaut `<domain>:443`). Pas de publish host `:3389` sur le stack cluster.

Agents et clients utilisent **`TELEPORT_PUBLIC_ADDR`** (HTTPS), pas un port hôte publié sur le stack.

## Config

`teleport-setup` écrit `teleport/config/teleport.yaml` depuis `config/teleport.yaml.example` (`cluster_name` / `public_addr` depuis `TELEPORT_DOMAIN`). Fichier gitignored. Compose `configs:` → `/etc/teleport/teleport.yaml`. Après setup: `TELEPORT_CONFIG_FILE=./config/teleport.yaml`.

`TELEPORT_DOMAIN` → Traefik `Host()`. `public_addr` défaut `<domain>:443`. `trust_x_forwarded_for: true`.

## Base path

**Non supporté.** `TELEPORT_BASE_PATH=/` (sous-domaine dédié). Pas de PathPrefix / stripPrefix.

## Env / env_file

- `TELEPORT_ENV_FILE` (default `.env.example` ; prod → `.env`)
- Compose: `env_file` + `environment:` — **`environment:` gagne**
- Swarm: Make export root `.env` + interpolation compose
- Traefik → **HTTPS** port 3080 (`server.scheme=https`). Middleware `${APP_NAME}-br` force `Accept-Encoding: br` (UI Brotli — sans ça page noire, [teleport#66500](https://github.com/gravitational/teleport/issues/66500))
- UI sur **websecure** + TLS. Router HTTP → `redirect-to-https`. `TELEPORT_TLS_CERTRESOLVER` vide = cert Traefik default (`*.local`)

## Makefile

```sh
make teleport-setup
make teleport-pull-images
make teleport-stack-up
make teleport-stack-upgrade
make teleport-stack-down
make teleport-debug
make teleport-debug-logs
make teleport-compose-up
make teleport-compose-down
make teleport-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `APP_NAME` | Traefik scope (default `teleport`) |
| `TELEPORT_DOMAIN` / `TELEPORT_APP_URL` | Host public + Homepage |
| `TELEPORT_CLUSTER_NAME` / `TELEPORT_PUBLIC_ADDR` | Rendu dans `teleport.yaml` |
| `TELEPORT_CONFIG_FILE` | `./config/teleport.yaml` after setup |
| `TELEPORT_ENV_FILE` | Compose dotenv |

Do not commit `teleport/.env` or `teleport/config/teleport.yaml`.
