#!/usr/bin/env bash
# Install sexy-bash-prompt
#
# When run from ssh without a TTY (e.g. ssh host make setup), upstream install.bash
# may print "cannot set terminal process group" / "no job control". Running make install
# inside `script` allocates a pseudo-TTY and avoids that noise on Linux/glibc.

# https://github.com/twolfson/sexy-bash-prompt
set -euo pipefail
cd /tmp
[[ -d sexy-bash-prompt ]] || git clone --depth 1 --config core.autocrlf=false https://github.com/twolfson/sexy-bash-prompt
cd sexy-bash-prompt
if command -v script >/dev/null 2>&1 && script -q -c "true" /dev/null 2>/dev/null; then
  # Allocates a PTY so install.bash does not complain about job control without a TTY.
  script -q -c "make install" /dev/null
else
  make install
fi

if [ ! -f "${HOME}/.bash_prompt" ]; then
  echo "install-sexy-bash-prompt: ${HOME}/.bash_prompt not found after install" >&2
  exit 1
fi

sed -i 's/\\h/\\H/g' "${HOME}/.bash_prompt"

if sudo -n true 2>/dev/null; then
  sudo cp "${HOME}/.bash_prompt" /etc/profile.d/zz-bash_prompt.sh
  echo "install-sexy-bash-prompt: installed system-wide in /etc/profile.d/zz-bash_prompt.sh"
else
  BASHRC="${HOME}/.bashrc"
  if [ -f "${BASHRC}" ] && ! grep -qF 'bash_prompt' "${BASHRC}"; then
    cat >> "${BASHRC}" << 'EOF'

# sexy-bash-prompt (user install; no passwordless sudo for system-wide profile.d)
[ -r ~/.bash_prompt ] && . ~/.bash_prompt
EOF
    echo "install-sexy-bash-prompt: hooked ~/.bash_prompt in ~/.bashrc"
  else
    echo "install-sexy-bash-prompt: ~/.bash_prompt updated; ensure ~/.bashrc sources it" >&2
  fi
fi
