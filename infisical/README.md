# Infisical

[Infisical](https://infisical.com) — open-source (MIT) secrets management platform (secrets, certificates/PKI, PAM, KMS), self-hosted via the `infisical/infisical` Docker image. Accessible via Traefik on the stack-local network `infisical-network`.

> **Étude en cours** — ce stack est un modèle (compose, env, Makefile). Pas encore déployé.

## Déploiement

```sh
# 1/2. Préparer infisical/.env (copie de .env.example, génère ENCRYPTION_KEY / AUTH_SECRET / DB_PASSWORD,
#      dérive DB_CONNECTION_URI, force le réseau stack-local)
make infisical-setup

# Swarm
make infisical-stack-up
# ou Compose
make infisical-compose-up
```

Premier démarrage : ouvrir `INFISICAL_SITE_URL` et créer le compte admin — **le premier utilisateur inscrit devient administrateur**.

## Services

| Service | Rôle | Port interne |
|---------|------|--------------|
| `infisical-backend` | Application (API + UI) | **8080** |
| `infisical-db` | PostgreSQL 16 — secrets chiffrés, utilisateurs, projets | 5432 (interne) |
| `infisical-redis` | Cache + files de jobs | 6379 (interne) |

## Configuration requise

| Var | Obligatoire | Note |
|-----|-------------|------|
| `INFISICAL_DOMAIN` | oui | ex. `infisical.example.com` (averti si `example.com`) |
| `INFISICAL_SITE_URL` | oui | URL absolue avec protocole, sans slash final — doit correspondre à l'accès Traefik |
| `INFISICAL_ENCRYPTION_KEY` | oui | 16 octets aléatoires en hex (`openssl rand -hex 16`) — **chiffre tous les secrets stockés** |
| `INFISICAL_AUTH_SECRET` | oui | 32 octets aléatoires en base64 (`openssl rand -base64 32`) — signe les JWT |
| `INFISICAL_DB_PASSWORD` | oui | généré par `make infisical-setup` si `ChangeMe` |

Modifier `infisical/.env`, puis `make infisical-stack-recreate`.

> **`INFISICAL_ENCRYPTION_KEY` : à sauvegarder.** Perdre cette clé rend tous les secrets stockés illisibles. La rotation est documentée côté Infisical (Rotating the encryption key).

## Docker / Swarm notes

- Image `infisical/infisical` (port interne **8080** ; `EXPOSE 443 8080` — le 443 n'est pas utilisé ici). Épinglée à `v0.165.10` ; `latest` est déconseillé en production.
- L'image définit déjà `HOST=0.0.0.0` et `PORT=8080`. `INFISICAL_HOST` est répété explicitement dans le compose car **le défaut vendor du binaire est `localhost`** — sans lui, rien n'écoute hors du conteneur et Traefik renvoie 502.
- `env_file` (variable `*_ENV_FILE`, défaut `.env.example`) **+** `environment:` (l'`environment:` écrase le fichier).
- **`docker stack deploy` ne lit pas `.env` seul** — utiliser Make (exporte le `.env` racine + interpolation `environment:`).
- `NODE_OPTIONS` est abaissé à `--max-old-space-size=768` (l'image embarque 2048) pour rester sous la limite mémoire de 1G et laisser V8 faire du GC au lieu d'être OOM-killed.
- PostgreSQL n'accepte **qu'un seul réplica** (service stateful). Redis idem.
- Traefik : noms router/service scoped par `APP_NAME` (Dokploy), **non listé** dans `.env.example`. `passhostheader=true` activé (OAuth/SSO redirects).
- Réseau **stack-local** (`infisical-network`) : Postgres et Redis ne sont joignables que depuis ce stack. Ne pas publier 5432 / 6379.

## Base path / reverse proxy

- **Subpath non supporté** — déployer en **Host-only** (sous-domaine, `INFISICAL_BASE_PATH=/`), conformément à la convention du repo pour les SPA.
- `INFISICAL_SITE_URL` doit correspondre exactement à l'URL publique (protocole, host) : Infisical la compare pour les redirects OAuth/SSO.
- Pas de `stripPrefix`.

## Volumes

- `infisical_pg_data` → `/var/lib/postgresql/data` : **contient tous les secrets chiffrés**. Ne jamais supprimer sans backup intentionnel.
- `infisical_redis_data` → `/data` : cache + jobs (régénérable).
- Volumes nommés Docker par défaut ; repointables vers un bind ou un partage NFS via `*_VOLUME_DRIVER_TYPE` / `_O` / `_DEVICE` (voir `.env.example`), sans modifier les compose.

## Cibles Make

`infisical-pull-images`, `infisical-setup`, `infisical-stack-{up,down,recreate,upgrade,logs,watch-logs}`, `infisical-debug`, `infisical-debug-logs`, `infisical-compose-{up,down,restart,recreate,logs,watch-logs}`, `infisical-compose-upgrade`.
