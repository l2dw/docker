# tempo

Tempo 3.1.1 (monolithique) : backend de traces OTLP (gRPC 4317, HTTP 4318), API 3200.

## Configuration pilotée par l'environnement

`config/tempo.yaml` ne contient que des `${VAR:-défaut}` (`-config.expand-env=true`) : toute valeur se change par variable d'environnement (Dokploy, références Vault Provider pour les secrets), sans modifier le fichier.

Variables : TEMPO_STORAGE_BACKEND (local|s3), TEMPO_S3_ENDPOINT/BUCKET/REGION/ACCESS_KEY/SECRET_KEY/INSECURE/FORCE_PATH_STYLE, TEMPO_RETENTION (336h), ports, log level. Liste complète et défauts : `.env.example`.

La config est livrée en config Swarm (`TEMPO_CONFIG_NAME`, immuable) : après modification du fichier, incrémenter `_vN` puis redéployer.

## Démarrage

```sh
make tempo-setup && make tempo-stack-up      # Swarm
make tempo-compose-up                     # Compose
```

Endpoints : /ready, /api/traces/<id>, /metrics. Aucun port publié : joindre `dokploy-network` (`DEFAULT_NETWORK_NAME=dokploy-network`, `DEFAULT_NETWORK_EXTERNAL=true`) pour être joint par le collecteur OpenTelemetry et Grafana (`tempo:<port>`).

## Volumes

`data` → `${TEMPO_DATA_VOLUME_DIR}` (WAL, index, cache ; les blocs vont dans S3 si backend `s3`). Recettes local / bind / NFS / externe : `.env.example`.

## Production

Backend `s3` recommandé (bucket dédié, clés dans OpenBao). Rétention par `TEMPO_RETENTION`. Superviser `/metrics`.
