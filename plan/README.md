# docker-templates

Boîte à outils d’infrastructure Docker pour déployer et opérer des stacks (applications + services) sur des hôtes Linux — via **Docker Swarm** et/ou **Docker Compose**.

Nom GitLab / historique : `devops/docker-templates`. Ce dépôt local s’appelle souvent `docker-composer`.

## Modèle de branches

| Branche | Contenu |
|---------|---------|
| `main` | Catalogue de stacks (dokploy, traefik-related infra, jenkins, portainer, rustfs, …) |
| `dictfp`, `dokploy`, `traefik`, `keycloak`, … | **Une branche ≈ un stack** (dossier projet + Makefile inclus) |
| `template` | Scaffold pour créer un nouveau stack |
| `ocrx-cloud`, `ti-udem/*`, … | Variantes / agrégats par environnement |

Checkout d’un stack :

```sh
git checkout dictfp   # exemple
```

Le working tree peut contenir des restes locaux d’autres branches (overrides, `.env`). La vérité versionnée est celle de la branche courante (`git ls-files`), pas uniquement `ls`.

## Structure

```
.
├── Makefile                 # hub : Swarm, Compose, setup, include des projets
├── .env.example             # modèle d’environnement racine
├── bin/                     # scripts opérationnels
├── <projet>/                # un dossier = un stack
│   ├── .env.example
│   ├── Makefile             # cibles <projet>-stack-* / <projet>-compose-*
│   ├── docker-compose.yml   # (parfois aussi stack-compose.yml)
│   └── README.md            # doc spécifique (si présente)
└── docs/                    # notes d’infra (selon branche)
```

Fichiers **non versionnés** (voir `.gitignore`) :

- tous les dotfiles sauf `.gitignore`, `.gitkeep`, `*.example` → donc `.env`, `.env.*`
- `**/*.override.*` → overrides locaux Compose / notes `HELP.override.md`
- `appdata/`, `certs/`, `*_trash`

## Prérequis

- Docker CE + plugin Compose (ou Podman avec socket compatible — Swarm non supporté sous Podman)
- GNU Make
- Pour la prod typique : Swarm initialisé, réseau overlay partagé
- Chemins hôtes courants : `/infra` (clone), `/appdata` (données), certs/backups/logs

## Quickstart

```sh
# 1. Environnement
cp .env.example .env
# + éventuellement <projet>/.env.example → <projet>/.env
# Renseigner mots de passe, registry, INSTANCE_NAME, chemins, etc.

# 2. Bootstrap hôte (idéalement avec TTY)
ssh -t host 'cd /infra && make setup'

# 3. Réseau partagé (souvent requis pour Traefik / apps)
docker network create --driver overlay --attachable dokploy-network

# 4. Swarm (si besoin)
make swarm-init   # SWARM_ADVERTISE_ADDR=… pour forcer l’IP

# 5. Déployer un stack (ex. dictfp, depuis la branche dictfp)
make dictfp-stack-up
# ou générique :
make stack-deploy STACK_NAME=dictfp
```

Compose local (dev / machine sans Swarm) :

```sh
make dictfp-compose-up
# override local non versionné : dictfp/docker-compose.override.yml
```

## Swarm vs Compose

| | Swarm (`*-stack-*`) | Compose (`*-compose-*`) |
|--|---------------------|-------------------------|
| Commande | `docker stack deploy` | `docker compose -p NAME up -d` |
| Cible Make | `stack-deploy` / `stack-upgrade` | `docker-project-up` / `docker-project-upgrade` |
| `.env` | Exporté par le Makefile racine (Swarm ne lit pas `.env` seul) | `--env-file` projet si présent |
| Override | `-c …override.yml` si présent | `-f …override.yml` si présent |

Résolution des fichiers : `bin/resolve-project-compose.sh`

1. Compose : `COMPOSE_FILE` / `STACK_FILE`, sinon `<prj>/stack-compose.yml`, sinon `<prj>/docker-compose.yml`
2. Override : `COMPOSE_OVERRIDE` / `STACK_OVERRIDE`, sinon `stack-` ou `docker-compose.override.yml`
3. Env projet : `<prj>/.env` si présent

## Makefile (aperçu)

`make` / `make help` liste toutes les cibles.

| Groupe | Exemples |
|--------|----------|
| Conteneurs | `docker-login`, `docker-ps`, `docker-stop` (`CONTAINER_NAME=…`) |
| Compose générique | `docker-project-up\|down\|upgrade\|logs` (`PROJECT_NAME=…`) |
| Swarm | `swarm-init`, `swarm-info`, `swarm-join`, `swarm-leave` |
| Stacks | `stack-deploy`, `stack-rm`, `stack-upgrade`, `stack-logs` |
| Infra | `setup`, `update-server`, `fix-dns-resolv`, `add-swap-file` |
| Projet courant | `dictfp-stack-up`, `dictfp-compose-up`, `dictfp-debug`, … |

`stack-upgrade` = pull images → deploy → `docker service update --force` (nécessaire si le tag ne change pas mais le digest oui).

Attention : `make commit-changes` ajoute, commit et **push** — à utiliser avec prudence.

## Scripts `bin/`

| Script | Rôle |
|--------|------|
| `utils.sh` | Lib commune (env, IP, sudo, docker/podman, helpers Swarm) |
| `resolve-project-compose.sh` | Résout compose / override / env pour Make |
| `setup-environment.sh` | `~/.env`, hosts, swappiness, symlinks `~/Makefile` `~/bin` |
| `setup-filesystem.sh` | Crée `INFRA_DIR`, `APPDATA_DIR`, logs, backups |
| `setup-swarm.sh` | `swarm init` (souvent conditionné au hostname) |
| `add-swap-file.sh` | Swap si `ENABLE_SWAP_FILE=true` |
| `fix-dns-resolv.sh` | Remplace resolv.conf si `UPDATE_DNS_RESOLVERS=true` |
| `server-update.sh` | Mise à jour paquets (`apt` / `dnf`) |
| `create-db.sh` | `CREATE USER/DATABASE` dans le service Swarm PostgreSQL d’infra |
| `docker-stack-follow-logs.sh` | Suit les logs de tous les services d’un stack |
| `install-sexy-bash-prompt.sh` | Prompt bash + `/etc/profile.d` |
| `ip_address.sh` | Affiche l’IPv4 détectée |

Sur `main`, d’autres scripts existent (`deploy-infrastructure.sh`, `install-docker-ce.sh`, …).

## Environnement

Le Makefile charge `.env` via `-include` et **exporte** les clés (important pour `stack deploy`).

Variables racine typiques (voir `.env.example`) :

- Proxy, `TZ`
- `DEFAULT_NETWORK_NAME` / `DEFAULT_NETWORK_EXTERNAL` (souvent `dokploy-network`)
- `INSTANCE_NAME`, `INFRA_*`, chemins `/infra`, `/appdata`, certs, backups, logs
- Registry Docker
- DNS optionnel

Chaque projet a son `.env.example` (ex. `dictfp/.env.example` pour MariaDB / WordPress / `BASE_PATH`).

**Ne jamais committer** `.env`, overrides, ni notes locales contenant des secrets.

## Stacks connus

Branche courante `dictfp` : WordPress + MariaDB — voir [`dictfp/README.md`](dictfp/README.md).

Sur `main` (catalogue) : `adguard`, `bytestash`, `dokploy`, `homepage`, `jenkins`, `jenkins-agent`, `minio-client`, `portainer`, `postfix-relay`, `registry`, `rustfs`, `smtp-relay`, …

Autres branches dédiées (ex.) : `traefik`, `keycloak`, `rie`, `vitrinerech/sadvr`, `postfix-relay`, `postgresql`, …

## Nouveau stack

1. Partir de la branche `template` (dossier `template/`, préfixe `tpl`).
2. Copier / renommer (`tpl` → nom du projet), ajuster `.env.example` et compose.
3. `-include <projet>/Makefile` dans le Makefile racine de la branche.
4. Documenter dans `<projet>/README.md`.

## Patterns notables

- **Réseau overlay externe** partagé (`dokploy-network`) pour Traefik et les apps
- **Overrides locaux** pour ports, mounts, labels Traefik — jamais versionnés
- **Labels Homepage** (group / icon / href) sur beaucoup de services
- Variables Compose `${VAR:-default}` ; Make exporte le `.env` racine
- Dualité systématique des cibles `*-stack-*` / `*-compose-*`

## Troubleshooting

| Symptôme | Piste |
|----------|--------|
| Service Swarm `0/1` | `make <projet>-debug` / `*-debug-logs` ; volumes manquants ; contraintes de placement |
| Image « à jour » mais vieux digest | `make <projet>-stack-upgrade` (force-update) |
| Variables vides en Swarm | Vérifier `.env` racine chargé par Make (pas seulement `.env` projet) |
| Réseau introuvable | Créer `dokploy-network` (overlay attachable) |
| Permissions volumes | Certains services imposent un uid (ex. 1000, 999) |

## Documentation liée

- [`dictfp/README.md`](dictfp/README.md) — stack WordPress + MariaDB (branche `dictfp`)
- `docs/infrastructure-deployment.md` — déploiement stack `infrastructure` + Traefik (branche `main`)
- `docs/fix-profilerc.md` — script profilerc (`main`)
- `make help` — référence des cibles de la branche courante
