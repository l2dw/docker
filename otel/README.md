# otel

OpenTelemetry Collector **contrib 0.165.0** : point d'entrée OTLP unique (traces, métriques, logs) qui route vers les backends.

| Signal | Réception | Destination (variable) | Défaut |
|---|---|---|---|
| Traces | OTLP gRPC 4317 / HTTP 4318 | `OTEL_TRACES_ENDPOINT` (OTLP HTTP) | `http://tempo:4318` |
| Logs | OTLP | `OTEL_LOGS_ENDPOINT` (OTLP HTTP) | `http://loki:3100/otlp` |
| Métriques | OTLP + scrape interne | `OTEL_METRICS_ENDPOINT` (Prometheus remote write) | `http://prometheus:9090/api/v1/write` |

## Configuration pilotée par l'environnement

`config/config.yaml` ne contient que des `${env:VAR:-défaut}` : backends, URL, chemins, cluster, environnement se changent par variables (Dokploy), sans modifier le fichier. Principales variables :

- `OTEL_TRACES_ENDPOINT`, `OTEL_LOGS_ENDPOINT`, `OTEL_METRICS_ENDPOINT` : backends ;
- `OTEL_HTTP_BASE_PATH` : sous-chemin de réception OTLP HTTP (ex. `/otel` → `/otel/v1/traces`) ; vide = `/v1/*`. gRPC ne supporte pas de chemin ;
- `OTEL_CLUSTER` (label `cluster` des métriques), `OTEL_ENVIRONMENT` (`deployment.environment`) ;
- `OTEL_SCRAPE_TEMPO`, `OTEL_SCRAPE_LOKI` : `/metrics` des backends (avec celles du collecteur, port `OTEL_TELEMETRY_PORT`) renvoyées vers Prometheus ;
- `OTEL_MEMORY_LIMIT_PERCENTAGE`, `OTEL_MEMORY_SPIKE_PERCENTAGE`, ports, `OTEL_DEBUG_VERBOSITY`.

La config est livrée en config Swarm (`OPENTELEMETRY_CONFIG_NAME`, immuable) : après modification du fichier, incrémenter `_vN`.

## Exposition

Aucun port publié. En interne : `otel:4317` / `otel:4318` sur `dokploy-network`. En externe (HTTP uniquement) : domaine Traefik/Dokploy sur le port 4318 avec chemin (`OPENTELEMETRY_BASE_PATH` = `OTEL_HTTP_BASE_PATH`, pas de stripPrefix) et **middleware d'authentification obligatoire**. Client : `OTEL_EXPORTER_OTLP_ENDPOINT=https://<hôte><chemin>`.

## Démarrage

```sh
make otel-setup && make otel-stack-up      # Swarm
make otel-compose-up                       # Compose
```

Santé : `:13133`. Volumes : `data` (`/var/lib/otelcol`). Recettes : `.env.example`.
