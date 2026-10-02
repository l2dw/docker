# S3 Client

MinIO Client (`minio/mc`) sidecar (`sleep infinity`). Default network `s3-client-network`.

```sh
make s3-client-setup
make s3-client-compose-up
docker exec -it s3-client-s3-client-1 mc --help
```

Homepage labels present; `S3_CLIENT_HOMEPAGE_URL=` empty by default.
