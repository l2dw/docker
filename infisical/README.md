# Infisical

[Infisical](https://infisical.com) — open-source (MIT) secrets management platform (secrets, certificates/PKI, PAM, KMS), self-hosted via the `infisical/infisical` Docker image. Accessible via Traefik on the stack-local network `infisical-network`.

> **Étude en cours** — ce stack est un modèle (compose, env, Makefile). Pas encore déployé.

PostgreSQL et Redis sont **externes** — ce stack n'embarque **aucun** service `db` ni `redis` (voir § PostgreSQL externe / § Redis externe). Les deux peuvent tourner sur une autre VM.

## Déploiement

```sh
# 1/2. Préparer infisical/.env (copie de .env.example, génère ENCRYPTION_KEY / AUTH_SECRET, avertit
#      si INFISICAL_DB_CONNECTION_URI / INFISICAL_REDIS_URL pointent encore vers <DB_HOST>/<REDIS_HOST>)
make infisical-setup

# Swarm
make infisical-stack-up
# ou Compose
make infisical-compose-up
```

**Pré-requis** : créer le rôle et la base PostgreSQL d'Infisical **avant le premier démarrage** (§ PostgreSQL externe), sinon Infisical ne peut pas initialiser son schéma.

Premier démarrage réussi : ouvrir `INFISICAL_SITE_URL` et créer le compte admin — **le premier utilisateur inscrit devient administrateur**.

## Services

| Service | Rôle | Port interne |
|---------|------|--------------|
| `backend` | Application Infisical (API + UI) | **8080** |

## Configuration requise

| Var | Obligatoire | Note |
|-----|-------------|------|
| `INFISICAL_DOMAIN` | oui | ex. `infisical.example.com` (averti si `example.com`) |
| `INFISICAL_SITE_URL` | oui | URL absolue avec protocole, sans slash final — doit correspondre à l'accès Traefik |
| `INFISICAL_ENCRYPTION_KEY` | oui | 16 octets aléatoires en hex (`openssl rand -hex 16`) — **chiffre tous les secrets stockés** |
| `INFISICAL_AUTH_SECRET` | oui | 32 octets aléatoires en base64 (`openssl rand -base64 32`) — signe les JWT |
| `INFISICAL_DB_CONNECTION_URI` | oui | DSN PostgreSQL externe (remplacer `<DB_HOST>` et `ChangeMe`) |
| `INFISICAL_REDIS_URL` | oui | URL Redis externe (remplacer `<REDIS_HOST>`) |

Modifier `infisical/.env`, puis `make infisical-stack-recreate`.

> **`INFISICAL_ENCRYPTION_KEY` : à sauvegarder.** Perdre cette clé rend tous les secrets stockés illisibles. La rotation est documentée côté Infisical (Rotating the encryption key).

## Docker / Swarm notes

- Image `infisical/infisical` (port interne **8080** ; `EXPOSE 443 8080` — le 443 n'est pas utilisé ici). Épinglée à `v0.165.10` ; `latest` est déconseillé en production.
- L'image définit déjà `HOST=0.0.0.0` et `PORT=8080`. `INFISICAL_HOST` est répété explicitement dans le compose car **le défaut vendor du binaire est `localhost`** — sans lui, rien n'écoute hors du conteneur et Traefik renvoie 502.
- `env_file` (variable `INFISICAL_ENV_FILE`, défaut `.env.example`) **+** `environment:` (l'`environment:` écrase le fichier).
- **`docker stack deploy` ne lit pas `.env` seul** — utiliser Make (exporte le `.env` racine + interpolation `environment:`).
- `NODE_OPTIONS` est abaissé à `--max-old-space-size=768` (l'image embarque 2048) pour rester sous la limite mémoire de 1G et laisser V8 faire du GC au lieu d'être OOM-killed.
- Un seul réplica : Infisical partage son état via PostgreSQL/Redis, mais le déploiement monte en charge horizontalement seulement avec plusieurs instances + PostgreSQL/Redis dédiés.
- Traefik : noms router/service scoped par `APP_NAME` (Dokploy), **non listé** dans `.env.example`. `passhostheader=true` activé (OAuth/SSO redirects).
- Réseau **stack-local** (`infisical-network`) : pour joindre une PostgreSQL/Redis externes, ils doivent être joignables depuis l'overlay (même réseau Docker/Swarm, ou adresse routable depuis les nœuds). Si les services tournent sur le **même swarm**, mettre `DEFAULT_NETWORK_NAME=dokploy-network` + `DEFAULT_NETWORK_EXTERNAL=true` pour les résoudre par leur nom.
- **Ne jamais exposer 5432 / 6379 publiquement** — uniquement sur le réseau interne.

## Base path / reverse proxy

- **Subpath non supporté** — déployer en **Host-only** (sous-domaine, `INFISICAL_BASE_PATH=/`), conformément à la convention du repo pour les SPA.
- `INFISICAL_SITE_URL` doit correspondre exactement à l'URL publique (protocole, host) : Infisical la compare pour les redirects OAuth/SSO.
- Pas de `stripPrefix`.

## PostgreSQL externe

Ce stack n'embarque **pas** de service `db` : Infisical se connecte à une **PostgreSQL existante** (autre VM / installation native / service déjà sur l'overlay). Créez le rôle et la base **avant le premier démarrage**.

> Le rôle doit être **propriétaire** de la base et disposer de **tous les privilèges** (création de schémas, DDL : CREATE/UPDATE/DELETE sur tables et index). Infisical exécute ses migrations au démarrage.

### 1. Générer un mot de passe fort (`DB_PWD`)

`make infisical-setup` ne génère **pas** le mot de passe PostgreSQL (la base est externe et le rôle préexiste). Générez-le vous-même :

```sh
DB_PASS=$(openssl rand -hex 24)
echo "$DB_PASS"   # à conserver pour l'étape 3
```

### 2. Créer le rôle (`DB_USER`) et la base (`DB_NAME`) via `psql`

La base est **hors de ce swarm** (autre VM / installation native). Connectez-vous avec le client `psql` classique en super-utilisateur :

```sh
DB_HOST=<adresse IP ou nom DNS de la VM Postgres>
# Exemple: DB_HOST=192.168.10.20
psql -h "$DB_HOST" -U postgres -d postgres
```

Une fois dans le prompt `psql`, créez le rôle et la base (remplacez `<le mot de passe>` par `$DB_PASS`) :

```sql
CREATE USER infisical WITH PASSWORD '<le mot de passe>';
CREATE DATABASE infisical OWNER infisical;
```

En une commande sans entrée interactive (si vous préférez `-c`). Attention : `psql -c` **n'effectue pas** la substitution de variables `:` — passez les mots de passe en littéral :

```sh
psql -h "$DB_HOST" -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE USER infisical WITH PASSWORD '<le mot de passe>'"
psql -h "$DB_HOST" -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE infisical OWNER infisical"
```

`<le mot de passe>` n'a **pas** de quote imbriquée : une valeur contenant un simple guillemet ne peut pas être passée ainsi.

> **Pré-requis accès distant** : la VM Postgres doit accepter les connexions TCP (client + réseau autorisé dans `pg_hba.conf` et un `listen_addresses` non-bouclé). Le port par défaut est `5432` — ajoutez `-p <port>` si différent.

### 3. Renseigner le Stack

Dans `infisical/.env` (ou via `make infisical-setup INFISICAL_DB_CONNECTION_URI='...'`), mettez à jour :

```env
INFISICAL_DB_HOST=<DB_HOST>
INFISICAL_DB_PORT=5432
INFISICAL_DB_USER=infisical
INFISICAL_DB_PASSWORD=<le mot de passe généré>
INFISICAL_DB_NAME=infisical
# Le DSN réellement utilisé par Infisical (les 5 variables ci-dessus ne servent qu'à composer celui-ci) :
INFISICAL_DB_CONNECTION_URI=postgresql://infisical:<le mot de passe>@<DB_HOST>:5432/infisical
```

`make infisical-setup` avertit si `INFISICAL_DB_CONNECTION_URI` contient encore `<DB_HOST>` ou `ChangeMe`.

Variantes utiles du DSN :

```env
# TLS vérifié (RDS & co) : ajouter sslmode
INFISICAL_DB_CONNECTION_URI=postgresql://infisical:<mdp>@<DB_HOST>:5432/infisical?sslmode=verify-full
```

## Redis externe

Ce stack n'embarque **pas** de service `redis` : Infisical se connecte à un **Redis existant**. **Redis est obligatoire** — l'instance ne démarre pas sans `REDIS_URL` (cache + files de jobs).

### Sans authentification

```env
INFISICAL_REDIS_URL=redis://<REDIS_HOST>:6379
```

### Avec mot de passe

```env
INFISICAL_REDIS_PASSWORD=<le mot de passe>
INFISICAL_REDIS_URL=redis://:<le mot de passe>@<REDIS_HOST>:6379
```

### Avec TLS

Utiliser le protocole `rediss://`. Si le certificat est signé par une CA privée ou auto-signé, monter le certificat et pointer `NODE_EXTRA_CA_CERTS` :

```env
INFISICAL_REDIS_URL=rediss://<REDIS_HOST>:6379
# ajouter dans environment: du compose :
#   - NODE_EXTRA_CA_CERTS=/path/to/ca.crt
```

> **Redis Sentinel / Cluster** : Infisical supporte `REDIS_SENTINEL_HOSTS` / `REDIS_CLUSTER_HOSTS` au lieu de `REDIS_URL` (voir la doc Infisical). Un setup actif-passif est recommandé ; l'actif-actif n'est pas testé par l'éditeur.

`make infisical-setup` avertit si `INFISICAL_REDIS_URL` contient encore `<REDIS_HOST>`.

## Volumes

Ce stack n'a **aucun volume** : tout l'état persistant vit dans la PostgreSQL/Redis externes.

## Cibles Make

`infisical-pull-images`, `infisical-setup`, `infisical-stack-{up,down,recreate,upgrade,logs,watch-logs}`, `infisical-debug`, `infisical-debug-logs`, `infisical-compose-{up,down,restart,recreate,logs,watch-logs}`, `infisical-compose-upgrade`.
