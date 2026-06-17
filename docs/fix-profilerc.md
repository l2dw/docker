# fix-profilerc: `/etc/profile` and `/etc/profile.d` for interactive bash

The script [`bin/fix-profilerc.sh`](../bin/fix-profilerc.sh) updates a user’s `~/.profile` and `~/.bashrc` so that environment from `/etc/profile` and scripts under `/etc/profile.d` apply reliably in **all** common interactive bash sessions—not only login shells.

## Why this exists

- **`/etc/profile.d/*.sh`** is sourced from **`/etc/profile`**. Bash runs `/etc/profile` for **login** shells (SSH, `bash -l`, console login), not for typical **non-login** interactive shells (most terminal emulators, many IDE terminals).
- On login, Debian/Ubuntu **`~/.profile`** sources **`~/.bashrc`**, which sets **`PS1`** and can **overwrite** prompts already set from `/etc/profile.d` (for example a custom prompt in `/etc/profile.d/z01-bash_prompt.sh`).

So without coordination, users can see missing PATH or profile.d behavior in GUI terminals, or a wrong prompt after login.

## What the fix does

1. **`~/.profile`**
   Exports `ETC_PROFILE_SOURCED=1` after bash has already run `/etc/profile`. That flag tells `~/.bashrc` that a full `/etc/profile` run is not needed again for this session.

2. **`~/.bashrc` (end of file)**
   - If `ETC_PROFILE_SOURCED` is unset (non-login shell): source **`/etc/profile`** once so PATH and `/etc/profile.d` run.
   - If `ETC_PROFILE_SOURCED` is set (login shell): re-source **`/etc/profile.d/*.sh`** so entries such as prompt scripts apply **after** the default `PS1` lines in `~/.bashrc`.

The embedded marker **`FIX_PROFILERC_V1`** identifies blocks applied by this script; the script also detects equivalent hand-edited blocks so it stays idempotent.

## Usage

From the repo (or any path to the script):

```bash
chmod +x /infra/bin/fix-profilerc.sh   # once, if needed
/infra/bin/fix-profilerc.sh            # current user ($HOME)
```

Target another home directory (e.g. another account):

```bash
sudo -u ubuntu env HOME=/home/ubuntu /infra/bin/fix-profilerc.sh /home/ubuntu
```

Open a **new** terminal tab or run `source ~/.bashrc` to pick up changes.

## Requirements and limits

- **`~/.profile`** must contain the standard Debian/Ubuntu anchor line:
  `# the files are located in the bash-doc package.`
  The script inserts the new block immediately after that line. If your distro uses a different template, extend the script or apply the same logic by hand.
- Only **`~/.profile`** and **`~/.bashrc`** are modified; **`/etc/profile`** is not edited.
- Re-running the script is safe: it skips work when the fix is already present.

## Verification

After applying and opening a new interactive shell:

- Non-login: `echo "$ETC_PROFILE_SOURCED"` is typically `1`, and variables or prompts from `/etc/profile.d` should appear as expected.
- Optional: `type` or `declare -f` for a function defined in a profile.d script (e.g. prompt helpers) should succeed.

For deeper behavior, see `man bash` (sections on **INVOCATION** and startup files).
