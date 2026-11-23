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
common=$(git rev-parse --git-common-dir)
dest="$hooks/post-commit"
# Ours only if the marker is on its own comment line near the top, as the shipped hook has it.
ours() { [[ -f $dest && ! -L $dest ]] && head -n 3 "$dest" | grep -qxF "# $marker (installed by scripts/install-hook.sh)."; }

# A global or shared core.hooksPath would put the hook in every repository using that
# directory, not just this one. Refuse unless --force, and say where it would go.
# Resolve a path without creating it: walk up to the nearest existing parent, resolve
# that, then apply the missing part lexically (dirs that don't exist can't be symlinks).
# If the missing part had . or .., resolve the result again, since it may now name an
# existing directory or symlink.
abs() {
  local p=$1 tail="" base c dots=0
  while [[ ! -d $p && $p != / && $p != . ]]; do tail="$(basename "$p")/$tail"; p=$(dirname "$p"); done
  base=$(cd "$p" 2>/dev/null && pwd -P || printf '%s' "$p")
  local IFS=/
  for c in $tail; do
    case $c in
      '' | .) dots=1 ;;
      ..) dots=1; base=$(dirname "$base") ;;
      *) base="${base%/}/$c" ;;
    esac
  done
  if [[ $dots -eq 1 ]]; then abs "$base"; else printf '%s' "$base"; fi
}
# Inside this repository's git dir or its working tree (e.g. a repo-local .githooks) is fine.
top=$(git rev-parse --show-toplevel 2>/dev/null || true)
shared=1
case "$(abs "$hooks")/" in "$(abs "$common")"/*) shared=0 ;; esac
if [[ -n $top ]]; then case "$(abs "$hooks")/" in "$(abs "$top")"/*) shared=0 ;; esac; fi

# With core.hooksPath pointing at this checkout's own hooks/ dir, the destination IS the
# shipped hook: it is already installed, and removing it would delete the source.
same=0; [[ -e $dest && $src -ef $dest ]] && same=1

if [[ $mode == uninstall ]]; then
  [[ $same -eq 1 ]] && { echo "$dest is viva-skills' own hooks/post-commit, not an installed copy; unset core.hooksPath instead" >&2; exit 1; }
  if ours; then rm -f "$dest"; echo "removed the viva reminder from $dest"; exit 0; fi
  [[ -e $dest || -L $dest ]] && { echo "$dest is not the viva reminder; left it alone" >&2; exit 1; }
  echo "no viva reminder installed"; exit 0
fi

if [[ $shared -eq 1 && $mode != force ]]; then
  echo "core.hooksPath points outside this repository ($hooks), so the reminder would run in every repository that uses it; use --force if you want that" >&2
  exit 1
fi

if [[ ( -e $dest || -L $dest ) ]] && ! ours && [[ $mode != force ]]; then
  echo "$dest already exists and is not the viva reminder; use --force to replace it" >&2
  exit 1
fi

if [[ $same -eq 1 ]]; then echo "the viva reminder is already in place at $dest (core.hooksPath uses this checkout's hooks/)"; exit 0; fi
mkdir -p "$hooks"
rm -f "$dest"   # replace a symlink itself, never write through it
cp "$src" "$dest"
chmod +x "$dest"
echo "installed the viva reminder at $dest (VIVA_REMIND=off to silence, --uninstall to remove)"
[[ $shared -eq 1 ]] && echo "note: $hooks is shared via core.hooksPath, so the reminder runs in every repository that uses it"
exit 0
