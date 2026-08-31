# Hermes

[Hermes Agent](https://hermes-agent.nousresearch.com/) (Nous Research) — assistant IA avec gateway (Telegram, Discord, Slack, cron, outils). Ce stack déploie la configuration **trois conteneurs** recommandée par [hermes-webui](https://github.com/nesquena/hermes-webui) :

| Service | Image | Rôle |
|---------|-------|------|
| `agent` | `nousresearch/hermes-agent` | Gateway (messaging, cron, API `:8642`) |
| `dashboard` | `nousresearch/hermes-agent` | Monitoring sessions / ressources (`:9119`) |
| `webui` | `ghcr.io/nesquena/hermes-webui` | Chat Web (`:8787`) |

Ingress via **Traefik** (pas de ports hôte publiés). `APP_NAME` scope les routers (`${APP_NAME:-hermes}`, `${APP_NAME:-hermes}-dashboard`) — fourni par Dokploy, absent de `.env.example`.

Default network: `hermes-network` (`EXTERNAL=false`). Pour Dokploy + Traefik partagé : `DEFAULT_NETWORK_NAME=dokploy-network` + `DEFAULT_NETWORK_EXTERNAL=true` (ou `make hermes-setup`).

## Quick start (Docker)

```sh
make hermes-setup \
  HERMES_DOMAIN=hermes.example.com \
  HERMES_APP_URL=https://hermes.example.com \
  HERMES_DASHBOARD_DOMAIN=hermes-dashboard.example.com \
  HERMES_DASHBOARD_APP_URL=https://hermes-dashboard.example.com \
  HERMES_WEBUI_PASSWORD='your-secure-password' \
  HERMES_DASHBOARD_BASIC_AUTH_PASSWORD='your-dashboard-password'
make hermes-compose-up   # or: make hermes-stack-up
```

- `hermes-setup` génère `HERMES_API_SERVER_KEY` (≥16 caractères) si absent — requis pour l’API gateway et les sondes WebUI.
- Définir **`HERMES_WEBUI_PASSWORD`** et **`HERMES_DASHBOARD_BASIC_AUTH_PASSWORD`** avant d’exposer via Traefik (le dashboard refuse `0.0.0.0` sans auth provider depuis la hardening Hermes 2026 ; `--insecure` est ignoré).
- `hermes-setup` génère aussi `HERMES_DASHBOARD_BASIC_AUTH_SECRET` si absent (sessions stables après redémarrage).
- Swarm : `docker stack deploy` ne lit pas `.env` seul — utiliser Make.

### URLs (après Traefik)

| Surface | Variable | Défaut |
|---------|----------|--------|
| Web UI | `HERMES_DOMAIN` | `https://hermes.example.com` |
| Dashboard | `HERMES_DASHBOARD_DOMAIN` | `https://hermes-dashboard.example.com` |
| Gateway API | interne | `HERMES_GATEWAY_URL` (défaut `http://agent:8642`) |

### Fichiers compose

| Fichier | Contenu |
|---------|---------|
| `docker-compose.yml` | Stack complet + labels Traefik/Homepage |
| `compose.yml` | Même stack, sans labels |
| `agent-compose.yml` | `agent` seul |
| `dashboard-compose.yml` | `dashboard` seul (sans labels) |
| `webui-compose.yml` | `webui` seul (sans labels) |

Volumes nommés partagés : `hermes-home` (état `~/.hermes`), `hermes-agent-src` (code agent pour `uv pip install` au démarrage WebUI), `hermes-workspace` (`/workspace` dans l’UI).

**Upgrade image agent** : après `docker pull`, supprimer le volume `hermes-agent-src` pour forcer la ré-init depuis la nouvelle image (voir [docs/docker.md](https://github.com/nesquena/hermes-webui/blob/master/docs/docker.md)).

## Outils Hermes (hors Docker)

Une fois le gateway configuré (`hermes gateway setup`), les surfaces utiles :

| Outil | Commande / accès | Usage |
|-------|------------------|--------|
| **CLI chat** | `hermes` | Session interactive |
| **Gateway** | `hermes gateway run` | Bots + cron (service systemd) |
| **Dashboard** | `hermes dashboard` ou conteneur | Monitoring |
| **Web UI** | conteneur ou `hermes-webui` | Chat navigateur |
| **Cron / watchdogs** | `hermes cron` / outil `cronjob` | Alertes script sans LLM (`--no-agent`) |
| **Modèles** | `hermes model` | Provider LLM |
| **Outils** | `hermes tools` | Terminal, browser, messaging, etc. |
| **API OpenAI-compatible** | gateway `:8642` | Intégrations (`HERMES_API_SERVER_KEY`) |
| **tsh / doctor** | `hermes doctor`, `hermes update` | Diagnostic et mise à jour |

Doc : [Installation](https://hermes-agent.nousresearch.com/docs/getting-started/installation) · [Messaging](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/) · [Cron](https://hermes-agent.nousresearch.com/docs/user-guide/features/cron).

## Installation native — Debian / Red Hat (sans Docker)

Pour un **agent always-on** sur une VM (gateway Telegram/Discord, cron, outils) **sans** conteneur — complément ou alternative au stack Docker.

### Prérequis

| Distro | Paquets |
|--------|---------|
| **Debian / Ubuntu** | `git curl xz-utils libatomic1` (+ `build-essential` si desktop / modules natifs) |
| **AlmaLinux / RHEL / Rocky** | `git curl xz libatomic` (+ `gcc gcc-c++ make` si desktop) |

```sh
# AlmaLinux / RHEL / Rocky
sudo dnf install -y git curl xz libatomic

# Debian / Ubuntu
sudo apt install -y git curl xz-utils libatomic1
```

L’installateur officiel gère **uv**, Python 3.11, Node.js, ripgrep et ffmpeg.

### 1. Installer Hermes Agent

```sh
# Headless (serveur) — sans navigateur Playwright
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser

# Poste de travail / computer-use
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

Le binaire est dans `~/.local/bin/hermes` — ajouter au `PATH` :

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
hermes version
```

**Alternative PyPI** : `pip install hermes-agent` (Python 3.11+).

### 2. Configuration initiale

```sh
hermes setup          # assistant complet
# ou étape par étape :
hermes model          # provider LLM (clé API)
hermes tools          # outils activés par plateforme
hermes gateway setup  # Telegram, Discord, Slack, etc.
```

Fichiers sous `~/.hermes/` (`config.yaml`, sessions, skills, `scripts/` pour cron no-agent).

### 3. Gateway en service (production)

**Utilisateur dédié (recommandé)** :

```sh
sudo useradd -m -s /bin/bash hermes
sudo -u hermes -H bash -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser'
sudo -u hermes hermes gateway setup
```

**systemd (Debian et RHEL)** — en root ou avec sudo :

```sh
sudo hermes gateway install --system
sudo hermes gateway start --system
sudo systemctl status hermes-gateway
sudo journalctl -u hermes-gateway -f
```

Sans `--system` (utilisateur courant) :

```sh
hermes gateway install
hermes gateway start
```

Pour un service utilisateur qui survive à la déconnexion :

```sh
sudo loginctl enable-linger "$USER"
```

### 4. Dashboard natif (optionnel)

```sh
# Local sans login (loopback uniquement)
hermes dashboard --host 127.0.0.1 --port 9119

# Derrière Traefik / reverse proxy — auth obligatoire sur bind non-loopback :
export HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
export HERMES_DASHBOARD_BASIC_AUTH_PASSWORD='choose-a-strong-password'
export HERMES_DASHBOARD_BASIC_AUTH_SECRET="$(openssl rand -base64 32)"
export HERMES_DASHBOARD_PUBLIC_URL='https://hermes-dashboard.example.com'
hermes dashboard --host 0.0.0.0 --port 9119 --no-open
```

Doc : [Web Dashboard](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard).

### 5. Web UI sans stack Docker

L’image WebUI attend un home `~/.hermes` partagé. Sur la même VM que l’agent natif :

```sh
docker run -d \
  -e WANTED_UID=$(id -u) -e WANTED_GID=$(id -g) \
  -v "$HOME/.hermes:/home/hermeswebui/.hermes" \
  -v "$HOME/.hermes/hermes-agent:/home/hermeswebui/.hermes/hermes-agent:ro" \
  -v "$HOME/workspace:/workspace" \
  -e HERMES_WEBUI_PASSWORD='ChangeMe' \
  -e HERMES_API_URL=http://host.docker.internal:8642 \
  -p 127.0.0.1:8787:8787 \
  ghcr.io/nesquena/hermes-webui:latest
```

Sur Linux, remplacer `host.docker.internal` par l’IP de la VM ou `--network host` si acceptable.

### 6. Mise à jour

```sh
hermes update
# ou
pip install -U hermes-agent
# ou depuis le clone git
cd ~/.hermes/hermes-agent && git pull && uv pip install -e ".[all]"
```

### 7. Dépannage

```sh
hermes doctor
hermes gateway status    # si disponible
journalctl -u hermes-gateway -n 100
```

| Problème | Piste |
|----------|--------|
| `libatomic.so.1: cannot open shared object file` | AlmaLinux/RHEL : `sudo dnf install -y libatomic` — Debian : `sudo apt install -y libatomic1` — puis relancer l’installateur |
| `hermes: command not found` | Install incomplet ; `export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"` puis relancer `install.sh` |
| Gateway ne démarre pas | `hermes doctor` ; clés API / `config.yaml` |
| Cron silencieux | Jobs dans `~/.hermes/cron/jobs.json` ; `hermes cron list` |
| WebUI « gateway not reachable » | `HERMES_API_SERVER_KEY` ≥16 chars ; port 8642 ouvert localement |
| Dashboard « Refusing to bind … no auth providers » | Définir `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` + `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` (+ `HERMES_DASHBOARD_BASIC_AUTH_SECRET` pour sessions stables) ; retirer `--insecure` (ignoré) |

## Base path

**Non supporté** pour Web UI et Dashboard (SPA à la racine). `HERMES_BASE_PATH=/` et `HERMES_DASHBOARD_BASE_PATH=/` — utiliser des **sous-domaines dédiés** (`hermes.` / `hermes-dashboard.`).

## Env / env_file

- `HERMES_ENV_FILE` (default `.env.example` ; prod → `.env`)
- Compose : `env_file` + `environment:` — **`environment:` gagne**
- Swarm : Make export root `.env` + interpolation compose (pas `env_file` fiable)
- `HERMES_API_SERVER_KEY` : secret gateway — généré par `hermes-setup`, ne pas committer

## Makefile

```sh
make hermes-setup
make hermes-pull-images
make hermes-stack-up
make hermes-stack-upgrade
make hermes-stack-down
make hermes-debug
make hermes-debug-logs
make hermes-compose-up
make hermes-compose-down
make hermes-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `HERMES_DOMAIN` / `HERMES_APP_URL` | Web UI (Traefik + Homepage) |
| `HERMES_DASHBOARD_DOMAIN` / `HERMES_DASHBOARD_APP_URL` | Dashboard |
| `HERMES_API_SERVER_KEY` | Gateway API (auto-généré par setup) |
| `HERMES_GATEWAY_URL` | Gateway pour dashboard (`GATEWAY_HEALTH_URL`) et webui (`HERMES_API_URL`) |
| `HERMES_WEBUI_PASSWORD` | Auth Web UI (obligatoire en prod) |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` / `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | Auth dashboard (`0.0.0.0` derrière Traefik) |
| `HERMES_DASHBOARD_BASIC_AUTH_SECRET` | Clé de signature session (auto-généré par setup) |
| `HERMES_UID` / `HERMES_GID` | Permissions volumes partagés |
| `HERMES_ENV_FILE` | Compose dotenv |

Do not commit `hermes/.env`.
