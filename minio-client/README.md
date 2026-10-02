# MinIO Client

MinIO Client (`minio/mc`) sidecar (`sleep infinity`). Default network `minio-client-network`.

```sh
make minio-client-setup
make minio-client-compose-up
docker exec -it minio-client-minio-client-1 mc --help
```

Homepage labels present; `MINIO_CLIENT_HOMEPAGE_URL=` empty by default.
