# otel

[OpenTelemetry Collector Contrib](https://opentelemetry.io/docs/collector/) — OTLP ingest (**4317** gRPC, **4318** HTTP), collector metrics **8888**, health **13133**. Default config is **receive-only** (pipelines → `debug` exporter).

Directory / branch / stack name: **`otel`**. Env prefix: **`OPENTELEMETRY_`**.

No Traefik on this stack: ports are **published** (long-form) in both compose files. Homepage labels are on both files. `compose.yml` and `docker-compose.yml` match (no Traefik twin).

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${OPENTELEMETRY_ENV_FILE:-.env.example}`; production: `OPENTELEMETRY_ENV_FILE=.env`. `environment:` wins on key conflicts.

```sh
make otel-setup
make otel-stack-up      # Swarm
# or
make otel-compose-up    # Compose
```

On this branch, root `compose.yml` / `docker-compose.yml` symlink into `otel/`. Root `README.md` stays the repo socle doc (not overwritten).

## Base path

Collector has **no** vendor web `BASE_PATH`. There is no Traefik HTTP UI routing. Keep `OPENTELEMETRY_BASE_PATH=/`.

## env_file

`OPENTELEMETRY_ENV_FILE` (default `.env.example`). Production → `.env`. Swarm: Make-exported root `.env`.

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `EXTERNAL` |
|------|------------------------|------------|
| Stack-local (default) | `otel-network` | `false` |
| Shared Dokploy / Traefik overlay | `dokploy-network` | `true` |

`make otel-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

```sh
docker network create otel-network --driver overlay   # Swarm
docker network create otel-network --driver bridge    # Compose
```

## Volumes

| Compose key | Container path | Default |
|-------------|----------------|---------|
| `config` | `/etc/otelcol-contrib` | bind `/appdata/otel/config` |
| `data` | `/var/lib/otelcol` | local named `otel_data` |

Collector reads `${OPENTELEMETRY_CONFIG_FILE:-/etc/otelcol-contrib/config.yaml}`. Setup seeds `config.yaml` from `otel/config/config.yaml` when the config volume is a bind and the file is missing.

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|------------|--------|--------|--------|
| Local named | `false` | empty | empty | empty |
| Bind (config default) | `false` | `none` | `bind` | `/appdata/otel/config` |
| NFS | `false` | `nfs` | `addr=host,rw,nfsvers=4` | `:/exports/otel` |
| External | `true` | — | — | — |

```sh
docker volume create otel_data
# Optional if switching config to local named / external:
docker volume create otel_config
```

## Clients (OTLP)

```text
gRPC:  host:4317   (or http://otel:4317 on the overlay)
HTTP:  host:4318   (paths /v1/traces, /v1/metrics, /v1/logs)
```

## Exporting later (edit `config.yaml`)

Replace or add exporters, then point pipelines at them. Restart/recreate the stack after edits. Examples for **contrib** image:

### Jaeger (OTLP to Jaeger)

```yaml
exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/jaeger]
```

### Grafana Tempo

```yaml
exporters:
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/tempo]
```

### Prometheus (scrape collector, or remote write)

Collector self-metrics already listen on **8888**. To expose **received** metrics for Prometheus scrape:

```yaml
exporters:
  prometheus:
    endpoint: 0.0.0.0:8889
service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
```

Or remote write:

```yaml
exporters:
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
```

### Remote OTLP

```yaml
exporters:
  otlp/remote:
    endpoint: otlp.example.com:4317
    headers:
      api-key: ChangeMe
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/remote]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/remote]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/remote]
```

You can list several exporters on one pipeline (e.g. `[debug, otlp/tempo]`).

## Makefile

```sh
make otel-setup
make otel-pull-images
make otel-stack-up
make otel-stack-upgrade
make otel-stack-down
make otel-debug
make otel-debug-logs
make otel-compose-up
make otel-compose-down
make otel-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `OPENTELEMETRY_CONFIG_VOLUME_PATH` | Host bind dir for config (default `/appdata/otel/config`) |
| `OPENTELEMETRY_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `APP_NAME` | Stack identity (`otel`; Homepage / future Traefik) |

Do not commit `otel/.env` or real secrets.
