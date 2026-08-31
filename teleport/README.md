# Teleport

[Teleport Community Edition](https://goteleport.com/docs/installation/docker/) — bastion d’accès **SSH**, **RDP** (bureaux Windows via agents), bases, K8s, etc. Ce stack déploie **Auth + Proxy** dans un conteneur (`public.ecr.aws/gravitational/teleport-distroless:18.10.0`). UI Web **HTTPS 3080** (Traefik termine TLS devant ; le backend parle HTTPS Teleport). Auth **3025** (interne cluster).

Les **cibles** (VM Linux, Windows, K8s…) rejoignent le cluster via un **agent Teleport** — pas via des ports SSH/RDP publiés sur ce conteneur.

Default network: `teleport-network` (`EXTERNAL=false`). Pour Traefik Dokploy: `DEFAULT_NETWORK_NAME=dokploy-network` + `DEFAULT_NETWORK_EXTERNAL=true`, puis `make teleport-setup`.

`APP_NAME` scopes Traefik names (`${APP_NAME:-teleport}`). Listed in `.env.example` (default `teleport`).

## Quick start

**Local (Make)**

```sh
make teleport-setup TELEPORT_DOMAIN=teleport.example.com TELEPORT_APP_URL=https://teleport.example.com
make teleport-compose-up   # or: make teleport-stack-up
```

**Dokploy** — le repo inclut `config/teleport.yaml` (template). Pour appliquer votre domaine, ajouter une **commande pre-deploy** :

```sh
sh teleport/generate-config.sh
```

Dokploy injecte `TELEPORT_DOMAIN`, `TELEPORT_CLUSTER_NAME`, `TELEPORT_PUBLIC_ADDR` dans l’env ; le script réécrit `config/teleport.yaml` avant `docker compose up`. Puis définir `TELEPORT_CONFIG_FILE=./config/teleport.yaml` dans l’env Dokploy (sinon le compose utilise `./config/teleport.yaml.example` par défaut).

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
| **Agent Desktop (RDP)** | AlmaLinux (ou autre Linux) | `windows_desktop_service` → bureaux Windows ([section AlmaLinux](#almalinux--windows-desktop-service-rdp)) |
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

RDP: activer `windows_desktop_service` sur un agent Linux (voir [AlmaLinux — RDP](#almalinux--windows-desktop-service-rdp)). Le proxy route via `TELEPORT_PUBLIC_ADDR`. Pas de publish host `:3389` sur le stack cluster.

Agents et clients utilisent **`TELEPORT_PUBLIC_ADDR`** (HTTPS), pas un port hôte publié sur le stack.

## AlmaLinux — Windows Desktop Service (RDP)

Le stack Docker ne fait que **Auth + Proxy**. Pour des bureaux Windows (RDP), installer **Teleport sur un serveur AlmaLinux** qui :

- joint le cluster via `TELEPORT_PUBLIC_ADDR` (ex. `teleport.example.com:443`) ;
- atteint les PC Windows en **TCP 3389** (RDP).

**CE** : max **5 bureaux** en utilisateurs Windows locaux (`ad: false`). Voir [Desktop Access](https://goteleport.com/docs/enroll-resources/desktop-access/getting-started/).

### Prérequis réseau

| Depuis | Vers | Port |
|--------|------|------|
| AlmaLinux (agent) | `TELEPORT_PUBLIC_ADDR` | 443 |
| AlmaLinux (agent) | PC Windows | 3389 |
| Poste admin | UI Teleport | 443 |

### 1. Préparer le PC Windows

Sur chaque bureau Windows (RDP activé) — remplacer `teleport.example.com` par `TELEPORT_DOMAIN` :

```cmd
curl.exe -fo teleport.cer https://teleport.example.com/webapi/auth/export?type=windows
curl.exe -fo teleport-windows-auth-setup-v18.10.0-amd64.exe https://cdn.teleport.dev/teleport-windows-auth-setup-v18.10.0-amd64.exe
teleport-windows-auth-setup-v18.10.0-amd64.exe install --cert=teleport.cer -r
```

Redémarrer Windows. Vérifier le package Teleport dans LSA :

```cmd
REG QUERY "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "Authentication Packages"
```

### 2. Token join (depuis le cluster Docker)

```sh
docker compose -f teleport/docker-compose.yml exec teleport \
  tctl tokens add --type=windowsdesktop
```

Copier le token (validité ~60 min) sur le serveur AlmaLinux.

### 3. Installer Teleport sur AlmaLinux 9

Même version que l’image cluster (`18.10.0`) :

```sh
TELEPORT_VERSION=18.10.0
curl -fsSL -o teleport-${TELEPORT_VERSION}-1.x86_64.rpm \
  https://cdn.teleport.dev/teleport-${TELEPORT_VERSION}-1.x86_64.rpm
sudo dnf install -y ./teleport-${TELEPORT_VERSION}-1.x86_64.rpm
teleport version
```

Firewall (si `firewalld` actif) — l’agent **initie** les connexions sortantes ; pas de port entrant obligatoire sur AlmaLinux pour le join :

```sh
# Optionnel : autoriser le trafic sortant HTTPS (déjà le cas en général)
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 4. Config agent — `/etc/teleport.yaml`

Remplacer `PROXY_ADDR` par `TELEPORT_PUBLIC_ADDR`, `JOIN_TOKEN` et l’IP/host Windows :

```yaml
version: v3
teleport:
  nodename: almalinux-desktop-agent
  proxy_server: PROXY_ADDR
  auth_token: JOIN_TOKEN

windows_desktop_service:
  enabled: true
  static_hosts:
    - name: win-bureau1
      ad: false
      addr: 192.168.1.50:3389
      labels:
        env: prod

auth_service:
  enabled: false
proxy_service:
  enabled: false
ssh_service:
  enabled: false
```

**Enregistrement dynamique** (ajout de bureaux sans éditer ce fichier) — remplacer `static_hosts` par :

```yaml
windows_desktop_service:
  enabled: true
  resources:
    - labels:
        "*": "*"
```

Puis créer les bureaux avec `tctl create` (voir [dynamic registration](https://goteleport.com/docs/enroll-resources/desktop-access/dynamic-registration/)).

### 5. Démarrer le service

```sh
sudo teleport install systemd -o /etc/systemd/system/teleport.service
sudo systemctl enable --now teleport
sudo systemctl status teleport
sudo journalctl -fu teleport
```

Vérifier depuis le cluster :

```sh
docker compose -f teleport/docker-compose.yml exec teleport tctl get windows_desktop_service
docker compose -f teleport/docker-compose.yml exec teleport tctl get windows_desktop
```

### 6. Rôle et utilisateur

Fichier `windows-desktop-admins.yaml` :

```yaml
kind: role
version: v7
metadata:
  name: windows-desktop-admins
spec:
  allow:
    windows_desktop_labels:
      "*": "*"
    windows_desktop_logins: ["Administrator", "alice"]
```

```sh
docker compose -f teleport/docker-compose.yml exec teleport \
  tctl create -f windows-desktop-admins.yaml

docker compose -f teleport/docker-compose.yml exec teleport \
  tctl users update admin --set-roles=editor,access,windows-desktop-admins
```

Se reconnecter à l’UI → **Resources** → **Desktops** → **Connect**.

### 7. Dépannage rapide

| Symptôme | Piste |
|----------|--------|
| Agent ne joint pas | Token expiré ; `curl -vk https://PROXY_ADDR/webapi/ping` depuis AlmaLinux |
| Bureau absent dans l’UI | `tctl get windows_desktop` ; labels vs rôle utilisateur |
| Connexion RDP échoue | RDP ouvert AlmaLinux → Windows ; package Windows Auth installé + reboot |
| Cert Windows | Ré-exporter : `https://TELEPORT_DOMAIN/webapi/auth/export?type=windows` |

### Option — SSH sur le même AlmaLinux

Pour enrôler ** aussi** le serveur AlmaLinux en cible SSH, générer un token `--type=node` et ajouter `ssh_service: enabled: true` dans le même `/etc/teleport.yaml` (ou un second agent dédié).


## Config

`config/teleport.yaml` est versionné (copie du template). `teleport-setup` ou `generate-config.sh` remplace `cluster_name` / `public_addr` depuis `TELEPORT_DOMAIN`. Compose `configs:` → `/etc/teleport/teleport.yaml` via `TELEPORT_CONFIG_FILE`.

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
| `TELEPORT_CLUSTER_NAME` / `TELEPORT_PUBLIC_ADDR` | Rendu dans `teleport.yaml` (via setup) |
| `TELEPORT_CONFIG_FILE` | Optionnel — `./config/teleport.yaml` after setup/generate-config ; défaut compose : `./config/teleport.yaml.example` |
| `TELEPORT_ENV_FILE` | Compose dotenv |

Do not commit `teleport/.env`.
