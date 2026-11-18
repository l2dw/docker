# loki

Loki 3.7.10 (single binary, schéma TSDB v13) : backend de logs, ingestion OTLP native `/otlp/v1/logs`, API 3100.

## Configuration pilotée par l'environnement

`config/loki.yaml` ne contient que des `${VAR:-défaut}` (`-config.expand-env=true`) : toute valeur se change par variable d'environnement (Dokploy, références Vault Provider pour les secrets), sans modifier le fichier.

Variables : LOKI_STORAGE_BACKEND (filesystem|s3), LOKI_S3_ENDPOINT/BUCKET/REGION/ACCESS_KEY/SECRET_KEY/INSECURE/FORCE_PATH_STYLE, LOKI_RETENTION (720h), LOKI_SCHEMA_FROM, ports, log level. Liste complète et défauts : `.env.example`.

La config est livrée en config Swarm (`LOKI_CONFIG_NAME`, immuable) : après modification du fichier, incrémenter `_vN` puis redéployer.

## Démarrage

```sh
make loki-setup && make loki-stack-up      # Swarm
make loki-compose-up                     # Compose
```

Endpoints : /ready, /loki/api/v1/query_range, /metrics. Aucun port publié : joindre `dokploy-network` (`DEFAULT_NETWORK_NAME=dokploy-network`, `DEFAULT_NETWORK_EXTERNAL=true`) pour être joint par le collecteur OpenTelemetry et Grafana (`loki:<port>`).

## Volumes

`data` → `${LOKI_DATA_VOLUME_DIR}` (WAL, index, cache ; les blocs vont dans S3 si backend `s3`). Recettes local / bind / NFS / externe : `.env.example`.

## Production

Backend `s3` recommandé (bucket dédié, clés dans OpenBao). Rétention par `LOKI_RETENTION`. Superviser `/metrics`.
