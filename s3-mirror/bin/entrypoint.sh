#!/bin/sh
# s3-mirror: periodic one-way rclone copy/sync between two targets (s3 bucket or local path).
# Runs as: /bin/sh /entrypoint.sh            -> loop (copy|sync every S3_MIRROR_INTERVAL s)
#          /bin/sh /entrypoint.sh health     -> healthcheck (last successful pass not too old)
set -eu

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

umask "${S3_MIRROR_UMASK:-022}"   # 002 keeps group-write on files created in a shared bind directory

INTERVAL="${S3_MIRROR_INTERVAL:-3600}"
STATE=/tmp/last_ok

case "$INTERVAL" in ''|*[!0-9]*) log "ERROR: S3_MIRROR_INTERVAL must be an integer (seconds)"; exit 1 ;; esac
[ "$INTERVAL" -ge 10 ] || { log "ERROR: S3_MIRROR_INTERVAL must be >= 10"; exit 1; }

if [ "${1:-}" = "health" ]; then
  [ -f "$STATE" ] || exit 1
  read -r ok < "$STATE"
  now=$(date +%s)
  [ $((now - ok)) -le $((INTERVAL * 2 + 120)) ]
  exit $?
fi

MODE="${S3_MIRROR_MODE:-copy}"
case "$MODE" in copy|sync) ;; *) log "ERROR: S3_MIRROR_MODE must be 'copy' or 'sync' (got '$MODE')"; exit 1 ;; esac

# Sets RESULT to the rclone location of one side ($1 = SRC|DST) and exports the remote config through
# RCLONE_CONFIG_<SIDE>_* variables (no config file, no secret in argv). Not called in a subshell.
resolve_side() {
  side="$1"
  eval "typ=\${S3_MIRROR_${side}_TYPE:-}"
  eval "endpoint=\${S3_MIRROR_${side}_ENDPOINT:-}"
  eval "key=\${S3_MIRROR_${side}_ACCESS_KEY:-}"
  eval "secret=\${S3_MIRROR_${side}_SECRET_KEY:-}"
  eval "bucket=\${S3_MIRROR_${side}_BUCKET:-}"
  eval "prefix=\${S3_MIRROR_${side}_PREFIX:-}"
  eval "path=\${S3_MIRROR_${side}_PATH:-}"
  lower=$(printf '%s' "$side" | tr 'A-Z' 'a-z')
  case "$typ" in
    s3)
      if [ -z "$endpoint" ] || [ -z "$key" ] || [ -z "$secret" ] || [ -z "$bucket" ]; then
        log "ERROR: ${side} type=s3 requires ENDPOINT, ACCESS_KEY, SECRET_KEY, BUCKET"; exit 1
      fi
      export "RCLONE_CONFIG_${side}_TYPE=s3"
      export "RCLONE_CONFIG_${side}_PROVIDER=${S3_MIRROR_S3_PROVIDER:-Other}"
      export "RCLONE_CONFIG_${side}_ENDPOINT=$endpoint"
      export "RCLONE_CONFIG_${side}_ACCESS_KEY_ID=$key"
      export "RCLONE_CONFIG_${side}_SECRET_ACCESS_KEY=$secret"
      export "RCLONE_CONFIG_${side}_FORCE_PATH_STYLE=${S3_MIRROR_S3_FORCE_PATH_STYLE:-true}"
      prefix=$(printf '%s' "$prefix" | sed 's#^/*##; s#/*$##')
      if [ -n "$prefix" ]; then RESULT="$lower:$bucket/$prefix"; else RESULT="$lower:$bucket"; fi
      ;;
    path)
      root="/$lower"
      if [ -z "$path" ]; then path="$root"; elif [ "${path#/}" = "$path" ]; then path="$root/$path"; fi
      mkdir -p "$path" 2>/dev/null || true
      RESULT="$path"
      ;;
    *) log "ERROR: S3_MIRROR_${side}_TYPE must be 's3' or 'path' (got '${typ:-<empty>}')"; exit 1 ;;
  esac
}

resolve_side SRC; SRC_URI=$RESULT
resolve_side DST; DST_URI=$RESULT
[ "${S3_MIRROR_SRC_TYPE:-}" != "path" ] || SRC_LOCAL="$SRC_URI"

set -f # no globbing while splitting the option lists below
EXCLUDES="${S3_MIRROR_EXCLUDE:-}"
OPTS="${S3_MIRROR_RCLONE_OPTS:-}"
MAXDEL="${S3_MIRROR_MAX_DELETE:-10}"

run_once() {
  set -- "$MODE" "$SRC_URI" "$DST_URI" --log-level INFO --stats-one-line
  # Default comparison = size + modification time. --checksum only on request: some S3 backends (RustFS) return
  # a multipart-style ETag for streamed uploads, rclone then has no hash and silently falls back to size only.
  [ "${S3_MIRROR_CHECKSUM:-false}" != "true" ] || set -- "$@" --checksum
  old_ifs=$IFS; IFS=','
  for p in $EXCLUDES; do [ -z "$p" ] || set -- "$@" --exclude "$p"; done
  IFS=$old_ifs
  if [ "$MODE" = "sync" ] && [ "$MAXDEL" -gt 0 ] 2>/dev/null; then set -- "$@" --max-delete "$MAXDEL"; fi
  # shellcheck disable=SC2086
  rclone "$@" $OPTS
}

# An s3 source that lists no file (empty bucket/prefix, wrong credentials, endpoint down) must never be
# synced onto a destination: it would empty it. Same spirit as the local-source guard below.
src_s3_has_files() {
  set -- lsf "$SRC_URI" --files-only -R
  old_ifs=$IFS; IFS=','
  for p in $EXCLUDES; do [ -z "$p" ] || set -- "$@" --exclude "$p"; done
  IFS=$old_ifs
  [ -n "$(rclone "$@" 2>/dev/null | head -n 1)" ]
}

log "MODE=$MODE INTERVAL=${INTERVAL}s EXCLUDE='${EXCLUDES}' MAX_DELETE=$MAXDEL"
log "SRC=$SRC_URI"
log "DST=$DST_URI"

trap 'log "stopping"; exit 0' TERM INT

while true; do
  # Never run a sync from an empty/missing local source: it would empty the destination.
  if [ -n "${SRC_LOCAL:-}" ] && { [ ! -d "$SRC_LOCAL" ] || [ -z "$(ls -A "$SRC_LOCAL" 2>/dev/null)" ]; }; then
    log "ERROR: source path $SRC_LOCAL is missing or empty; pass skipped"
  elif [ "${S3_MIRROR_SRC_TYPE:-}" = "s3" ] && [ "$MODE" = "sync" ] && ! src_s3_has_files; then
    log "ERROR: s3 source $SRC_URI lists no file (empty or unreachable); pass skipped"
  elif run_once; then
    date +%s > "$STATE"
    log "pass OK"
  else
    log "ERROR: pass failed (rclone exit $?)"
  fi
  sleep "$INTERVAL" &
  wait $!
done
