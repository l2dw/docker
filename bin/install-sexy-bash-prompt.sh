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

sudo mv ~/.bash_prompt /etc/profile.d/zz-bash_prompt.sh
sed -i -e /.bash_prompt/d ~/.bashrc

## Configure prompt for: ubuntu@pivot.ocrx.arbutus-cloud
sudo sed -i 's/\\h/\\H/g' /etc/profile.d/zz-bash_prompt.sh
