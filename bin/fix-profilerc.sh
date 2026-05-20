#!/usr/bin/env bash
# Apply ~/.profile + ~/.bashrc coordination so /etc/profile and /etc/profile.d
# run for non-login interactive shells and prompts from profile.d are not
# overwritten after login. Safe to run multiple times (idempotent).
#
# Usage: fix-profilerc.sh [HOME_DIR]
#   HOME_DIR defaults to $HOME. Use when fixing another user, e.g.:
#   sudo -u someuser env HOME=/home/someuser /path/to/fix-profilerc.sh

set -euo pipefail

TARGET_HOME="${1:-$HOME}"
PROFILE="${TARGET_HOME}/.profile"
BASHRC="${TARGET_HOME}/.bashrc"
MARKER="FIX_PROFILERC_V1"

die() {
  echo "fix-profilerc: $*" >&2
  exit 1
}

insert_profile_marker() {
  local f="$1"
  local tmp
  tmp="$(mktemp)"
  local done=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    printf '%s\n' "$line" >>"$tmp"
    if [[ $done -eq 0 ]] && [[ "$line" == *"the files are located in the bash-doc package."* ]]; then
      printf '\n' >>"$tmp"
      cat >>"$tmp" <<'EOF'
# FIX_PROFILERC_V1: coordinate /etc/profile with interactive non-login shells.
# Bash already sourced /etc/profile before this file. Mark it so ~/.bashrc can
# avoid running the full profile twice (non-login shells still source it there).
export ETC_PROFILE_SOURCED=1
EOF
      done=1
    fi
  done <"$f"
  if [[ $done -eq 0 ]]; then
    rm -f "$tmp"
    die "could not find anchor line in ${f} (expected bash-doc package comment)"
  fi
  mv "$tmp" "$f"
}

append_bashrc_block() {
  local f="$1"
  cat >>"$f" <<'EOF'

# FIX_PROFILERC_V1: ensure /etc/profile and /etc/profile.d apply for all interactive bash.
# Non-login interactive shells never run /etc/profile, so PATH and
# /etc/profile.d are skipped. Login shells run it before ~/.profile, but the
# PS1 assignments above overwrite prompts from profile.d—re-apply profile.d.
if [ -z "${ETC_PROFILE_SOURCED:-}" ] && [ -f /etc/profile ]; then
  export ETC_PROFILE_SOURCED=1
  # shellcheck source=/etc/profile
  . /etc/profile
elif [ -n "${ETC_PROFILE_SOURCED:-}" ]; then
  if [ -d /etc/profile.d ]; then
    for i in /etc/profile.d/*.sh; do
      if [ -r "$i" ]; then
        # shellcheck source=/dev/null
        . "$i"
      fi
    done
    unset i
  fi
fi
EOF
}

main() {
  [[ -n "$TARGET_HOME" ]] || die "HOME is empty"
  [[ -d "$TARGET_HOME" ]] || die "not a directory: $TARGET_HOME"
  [[ -f "$PROFILE" ]] || die "missing $PROFILE"
  [[ -f "$BASHRC" ]] || die "missing $BASHRC"

  if grep -qF "$MARKER" "$PROFILE" 2>/dev/null \
    || { grep -qF "export ETC_PROFILE_SOURCED=1" "$PROFILE" 2>/dev/null \
      && grep -qF "~/.bashrc can" "$PROFILE" 2>/dev/null; }; then
    echo "fix-profilerc: ${PROFILE} already has the profile coordination block"
  else
    insert_profile_marker "$PROFILE"
    echo "fix-profilerc: updated ${PROFILE}"
  fi

  if grep -qF "$MARKER" "$BASHRC" 2>/dev/null \
    || grep -qF "Non-login interactive shells never run /etc/profile" "$BASHRC" 2>/dev/null; then
    echo "fix-profilerc: ${BASHRC} already has the /etc/profile.d block"
  else
    append_bashrc_block "$BASHRC"
    echo "fix-profilerc: updated ${BASHRC}"
  fi

  echo "fix-profilerc: done (open a new shell or: source ~/.bashrc)"
}

main "$@"
