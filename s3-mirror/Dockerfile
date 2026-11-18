# Alpine + MinIO Client (mc). Official minio/mc is often scratch (no shell).
FROM docker.io/library/alpine:3.20
RUN apk add --no-cache ca-certificates curl bash \
 && curl -fsSL "https://dl.min.io/client/mc/release/linux-amd64/mc" -o /usr/local/bin/mc \
 && chmod +x /usr/local/bin/mc \
 && mc --version
COPY bin/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
