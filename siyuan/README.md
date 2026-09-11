# SiYuan

[SiYuan](https://github.com/siyuan-note/siyuan) — local-first knowledge base / note editor (Markdown block-based), self-hosted via the `b3log/siyuan` Docker image. Accessible via Traefik (network stack-local `siyuan-network`).

> **Étude en cours** — ce stack est un modèle (compose, env, Makefile). Pas encore déployé.

## Déploiement

```sh
# 1/2. Préparer siyuan/.env (copie de .env.example, génère ACCESS_AUTH_CODE, réseau stack-local)
make siyuan-setup

# Swarm
make siyuan-stack-up
# ou Compose
make siyuan-compose-up
```

## Configuration requise

| Var | Obligatoire | Note |
|-----|-------------|------|
| `SIYUAN_DOMAIN` | oui | ex. `siyuan.example.com` (averti si `example.com`) |
| `SIYUAN_ACCESS_AUTH_CODE` | oui | mot de passe verrouillage — généré par `make siyuan-setup` si `ChangeMe` |

Modifier `siyuan/.env`, puis `make siyuan-stack-recreate`.

## Docker / Swarm notes

- Image `b3log/siyuan` (port interne **6806**). Depuis v3.7.0, `command: serve --workspace=...` est requis.
- Volume nommé `siyuan_data` monté sur `/siyuan/workspace` (via `SIYUAN_DATA_DIR`/`SIYUAN_WORKSPACE_CONTAINER_PATH`).
- `env_file` (variable `SIYUAN_ENV_FILE`, défaut `.env.example`) **+** `environment:` (l'`environment:` écrase le fichier).
- **`docker stack deploy` ne lit pas `.env` seul** — utilise Make (exporte le `.env` racine + interpolation `environment:`).
- Traefik : noms router/service scoped par `APP_NAME` (Dokploy), **non listé** dans `.env.example`.

## Base path / reverse proxy

- **Subpath non supporté** par la doc SiYuan (reverse proxy recommandé). Déployer en **Host-only** (sous-domaine, `SIYUAN_BASE_PATH=/`).
- Le reverse proxy **doit** forwarder le WebSocket `/ws` (Traefik `passhostheader=true` actif).
- Pas de `stripPrefix` — les SPAs se cassent sous un path ; garder `/`.

## Target Make

`siyuan-pull-images`, `siyuan-stack-{up,down,recreate,upgrade,logs,watch-logs}`, `siyuan-debug`, `siyuan-debug-logs`, `siyuan-compose-{up,down,restart,recreate,logs,watch-logs}`, `siyuan-compose-upgrade`.
