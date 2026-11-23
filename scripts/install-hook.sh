#!/usr/bin/env bash
# Installs (or removes) the viva post-commit reminder in the current git repo.
#
# Usage: scripts/install-hook.sh [--force | --uninstall]
#   (no flag)    install hooks/post-commit; refuse if another post-commit hook exists
#   --force      replace an existing post-commit hook
#   --uninstall  remove the hook, only if it is the viva reminder
#
# Run it from inside the repository you want reminders in. Exit 0 on success,
# 1 when it refuses, 2 on bad usage or outside a git repo.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
src="$here/../hooks/post-commit"
marker="viva-skills post-commit reminder"

mode=install
case "${1:-}" in
  "") ;;
  --force) mode=force ;;
  --uninstall) mode=uninstall ;;
  *) echo "usage: scripts/install-hook.sh [--force | --uninstall]" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo "usage: scripts/install-hook.sh [--force | --uninstall]" >&2; exit 2; }

hooks=$(git rev-parse --git-path hooks 2>/dev/null) || { echo "not inside a git repository" >&2; exit 2; }
dest="$hooks/post-commit"
ours() { [[ -f $dest ]] && grep -qF "$marker" "$dest"; }

if [[ $mode == uninstall ]]; then
  if ours; then rm -f "$dest"; echo "removed the viva reminder from $dest"; exit 0; fi
  [[ -e $dest ]] && { echo "$dest is not the viva reminder; left it alone" >&2; exit 1; }
  echo "no viva reminder installed"; exit 0
fi

if [[ -e $dest ]] && ! ours && [[ $mode != force ]]; then
  echo "$dest already exists and is not the viva reminder; use --force to replace it" >&2
  exit 1
fi

mkdir -p "$hooks"
cp "$src" "$dest"
chmod +x "$dest"
echo "installed the viva reminder at $dest (VIVA_REMIND=off to silence, --uninstall to remove)"
