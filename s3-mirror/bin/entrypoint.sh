#!/usr/bin/env bash
# Permanent mc mirror while the container runs (uni or bi).
set -euo pipefail

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

MODE="${S3_MIRROR_MODE:-uni}"
MC_OPTS="${S3_MIRROR_MC_OPTS:-}"
DATA_ROOT="${S3_MIRROR_DATA_VOLUME_DIR:-/data}"

resolve_target() {
  local side="$1"
  local typ endpoint key secret bucket prefix path alias_opts alias_name uri
  local prefix_u

  prefix_u=$(printf '%s' "$side" | tr '[:lower:]' '[:upper:]')
  typ="$(eval "printf '%s' \"\${S3_MIRROR_${prefix_u}_TYPE:-}\"")"
  endpoint="$(eval "printf '%s' \"\${S3_MIRROR_${prefix_u}_ENDPOINT:-}\"")"
  key="$(eval "printf '%s' \"\${S3_MIRROR_${prefix_u}_ACCESS_KEY:-}\"")"
  secret="$(eval "printf '%s' \"\${S3_MIRROR_${prefix_u}_SECRET_KEY:-}\"")"
  bucket="$(eval "printf '%s' \"\${S3_MIRROR_${prefix_u}_BUCKET:-}\"")"
  prefix="$(eval "printf '%s' \"\${S3_MIRROR_${prefix_u}_PREFIX:-}\"")"
  path="$(eval "printf '%s' \"\${S3_MIRROR_${prefix_u}_PATH:-}\"")"
  alias_opts="$(eval "printf '%s' \"\${S3_MIRROR_${prefix_u}_MC_ALIAS_OPTS:-}\"")"
  alias_name="$side"

  case "$typ" in
    s3)
      if [ -z "$endpoint" ] || [ -z "$key" ] || [ -z "$secret" ] || [ -z "$bucket" ]; then
        log "ERROR: ${side} type=s3 requires ENDPOINT, ACCESS_KEY, SECRET_KEY, BUCKET"
        exit 1
      fi
      # shellcheck disable=SC2086
      mc alias set "$alias_name" "$endpoint" "$key" "$secret" $alias_opts >/dev/null
      uri="${alias_name}/${bucket}"
      if [ -n "$prefix" ]; then
        uri="${uri}/${prefix}"
      fi
      printf '%s\n' "$uri"
      ;;
    path)
      if [ -z "$path" ]; then
        path="$DATA_ROOT"
      elif [ "${path#/}" = "$path" ]; then
        path="${DATA_ROOT%/}/${path}"
      fi
      mkdir -p "$path"
      printf '%s\n' "$path"
      ;;
    *)
      log "ERROR: S3_MIRROR_${prefix_u}_TYPE must be 's3' or 'path' (got '${typ:-<empty>}')"
      exit 1
      ;;
  esac
}

SRC_URI="$(resolve_target src)"
DST_URI="$(resolve_target dst)"

log "MODE=${MODE}"
log "SRC=${SRC_URI}"
log "DST=${DST_URI}"
if [ -n "$MC_OPTS" ]; then
  log "MC_OPTS=${MC_OPTS}"
fi

# shellcheck disable=SC2206
OPTS_ARR=( $MC_OPTS )

case "$MODE" in
  uni)
    log "[src→dst] mc mirror --watch … ${SRC_URI} → ${DST_URI}"
    if [ "${#OPTS_ARR[@]}" -eq 0 ]; then
      exec mc mirror --watch "$SRC_URI" "$DST_URI"
    else
      exec mc mirror --watch "${OPTS_ARR[@]}" "$SRC_URI" "$DST_URI"
    fi
    ;;
  bi)
    log "WARNING: bi mode runs two watches; avoid --remove on both sides (delete loops)"
    if [ "${#OPTS_ARR[@]}" -eq 0 ]; then
      mc mirror --watch "$SRC_URI" "$DST_URI" &
      pid1=$!
      mc mirror --watch "$DST_URI" "$SRC_URI" &
      pid2=$!
    else
      mc mirror --watch "${OPTS_ARR[@]}" "$SRC_URI" "$DST_URI" &
      pid1=$!
      mc mirror --watch "${OPTS_ARR[@]}" "$DST_URI" "$SRC_URI" &
      pid2=$!
    fi
    log "[src→dst] pid=${pid1}"
    log "[dst→src] pid=${pid2}"
    status=0
    if wait -n "$pid1" "$pid2"; then
      status=0
    else
      status=$?
    fi
    kill "$pid1" "$pid2" 2>/dev/null || true
    wait "$pid1" 2>/dev/null || true
    wait "$pid2" 2>/dev/null || true
    log "ERROR: a mirror process exited (status=${status})"
    exit "${status:-1}"
    ;;
  *)
    log "ERROR: S3_MIRROR_MODE must be 'uni' or 'bi' (got '${MODE}')"
    exit 1
    ;;
esac
