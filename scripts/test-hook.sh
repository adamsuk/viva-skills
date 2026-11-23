#!/usr/bin/env bash
# Tests for hooks/post-commit and scripts/install-hook.sh. Local temp repos only.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
installer="$here/install-hook.sh"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
unset VIVA_REMIND VIVA_REMIND_EVERY
# Keep the user's own git config (core.hooksPath, signing) out of the tests.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

fail() { printf 'FAIL: %s: %s\n' "$tname" "$1" >&2; exit 1; }
newrepo() { local d="$ROOT/$1"; rm -rf "$d"; git init -q "$d"; printf '%s' "$d"; }
commit() { (cd "$1" && git commit -q --allow-empty -m c 2>&1); }

tname="installs and reminds on every 3rd commit by default"
r=$(newrepo default); (cd "$r" && bash "$installer" >/dev/null)
[[ -x $r/.git/hooks/post-commit ]] || fail "hook not installed"
o1=$(commit "$r"); o2=$(commit "$r"); o3=$(commit "$r"); o4=$(commit "$r")
[[ -z $o1 && -z $o2 && -z $o4 ]] || fail "reminded early: [$o1][$o2][$o4]"
[[ $o3 == "viva: run /viva on this commit? (VIVA_REMIND=off to silence)" ]] || fail "third commit: [$o3]"
printf 'ok: %s\n' "$tname"

tname="VIVA_REMIND_EVERY changes the interval; bad values fall back to 3"
r=$(newrepo every); (cd "$r" && bash "$installer" >/dev/null)
o=$(VIVA_REMIND_EVERY=1 commit "$r"); [[ -n $o ]] || fail "every=1 did not remind"
o=$(VIVA_REMIND_EVERY=abc commit "$r"); [[ -z $o ]] || fail "bad value reminded at once: [$o]"
printf 'ok: %s\n' "$tname"

tname="VIVA_REMIND=off is silent"
r=$(newrepo off); (cd "$r" && bash "$installer" >/dev/null)
for _ in 1 2 3 4 5 6; do o=$(VIVA_REMIND=off commit "$r"); [[ -z $o ]] || fail "printed: [$o]"; done
printf 'ok: %s\n' "$tname"

tname="never fails a commit, even when the counter can't be written"
r=$(newrepo ro); (cd "$r" && bash "$installer" >/dev/null)
mkdir "$r/.git/viva-remind-count"   # a directory where the counter file should be
for _ in 1 2 3; do
  err=$( (cd "$r" && git commit -q --allow-empty -m c) 2>&1 >/dev/null) || fail "commit failed"
  [[ -z $err ]] || fail "hook printed an error: $err"
done
(cd "$r" && sh .git/hooks/post-commit >/dev/null; echo "rc=$?") | grep -qx 'rc=0' || fail "hook exit not 0"
printf 'ok: %s\n' "$tname"

tname="refuses to overwrite another hook unless --force"
r=$(newrepo other); printf '#!/bin/sh\necho mine\n' > "$r/.git/hooks/post-commit"
status=0; (cd "$r" && bash "$installer" >/dev/null 2>&1) || status=$?
[[ $status -eq 1 ]] || fail "expected 1, got $status"
grep -qx 'echo mine' "$r/.git/hooks/post-commit" || fail "existing hook was changed"
(cd "$r" && bash "$installer" --force >/dev/null) || fail "--force failed"
grep -qF 'viva-skills post-commit reminder' "$r/.git/hooks/post-commit" || fail "--force did not install"
printf 'ok: %s\n' "$tname"

tname="--uninstall removes only the viva hook"
r=$(newrepo un); (cd "$r" && bash "$installer" >/dev/null && bash "$installer" --uninstall >/dev/null)
[[ ! -e $r/.git/hooks/post-commit ]] || fail "hook still there"
printf '#!/bin/sh\necho mine\n' > "$r/.git/hooks/post-commit"
status=0; (cd "$r" && bash "$installer" --uninstall >/dev/null 2>&1) || status=$?
[[ $status -eq 1 && -e $r/.git/hooks/post-commit ]] || fail "removed someone else's hook (status $status)"
printf 'ok: %s\n' "$tname"

tname="a damaged counter or a huge interval never errors"
r=$(newrepo damaged); (cd "$r" && bash "$installer" >/dev/null)
for bad in 08 007 99999999999999999999 abc ""; do
  printf '%s' "$bad" > "$r/.git/viva-remind-count"
  out=$( (cd "$r" && sh .git/hooks/post-commit) 2>&1; echo "rc=$?")
  [[ $out == "rc=0" ]] || fail "counter [$bad]: $out"
done
out=$( (cd "$r" && VIVA_REMIND_EVERY=99999999999999999999 sh .git/hooks/post-commit) 2>&1; echo "rc=$?")
[[ $out == "rc=0" ]] || fail "huge interval: $out"
printf 'ok: %s\n' "$tname"

tname="--force replaces a symlinked hook without writing through it"
r=$(newrepo link); mkdir -p "$r/tools"; printf '#!/bin/sh\necho tracked\n' > "$r/tools/hook.sh"
ln -s ../../tools/hook.sh "$r/.git/hooks/post-commit"
status=0; (cd "$r" && bash "$installer" >/dev/null 2>&1) || status=$?
[[ $status -eq 1 ]] || fail "symlink without --force: $status"
(cd "$r" && bash "$installer" --force >/dev/null) || fail "--force failed"
[[ ! -L $r/.git/hooks/post-commit ]] || fail "hook is still a symlink"
grep -qx 'echo tracked' "$r/tools/hook.sh" || fail "symlink target was overwritten"
printf 'ok: %s\n' "$tname"

tname="a shared core.hooksPath needs --force"
r=$(newrepo shared); mkdir -p "$ROOT/global-hooks"
(cd "$r" && git config core.hooksPath "$ROOT/global-hooks")
status=0; err=$( (cd "$r" && bash "$installer") 2>&1 >/dev/null) || status=$?
[[ $status -eq 1 ]] || fail "expected 1, got $status"
grep -qF 'every repository' <<< "$err" || fail "no explanation: $err"
[[ ! -e $ROOT/global-hooks/post-commit ]] || fail "installed anyway"
r2=$(newrepo shared2); (cd "$r2" && git config core.hooksPath "$ROOT/not-yet-there")
(cd "$r2" && bash "$installer" >/dev/null 2>&1) || true
(cd "$r2" && bash "$installer" --uninstall >/dev/null 2>&1) || true
[[ ! -e $ROOT/not-yet-there ]] || fail "refusing or uninstalling created the hooks dir"
(cd "$r" && bash "$installer" --force | grep -qF 'shared via core.hooksPath') || fail "--force gave no notice"
[[ -x $ROOT/global-hooks/post-commit ]] || fail "--force did not install"
printf 'ok: %s\n' "$tname"

tname="a repo-local core.hooksPath is fine without --force"
r=$(newrepo local); (cd "$r" && git config core.hooksPath .githooks && bash "$installer" >/dev/null) || fail "refused a repo-local hooksPath"
[[ -x $r/.githooks/post-commit ]] || fail "not installed in .githooks"
printf 'ok: %s\n' "$tname"

tname="bad usage and outside a repo"
status=0; bash "$installer" --nope >/dev/null 2>&1 || status=$?; [[ $status -eq 2 ]] || fail "bad flag: $status"
mkdir -p "$ROOT/plain"; status=0; (cd "$ROOT/plain" && GIT_CEILING_DIRECTORIES="$ROOT" bash "$installer" >/dev/null 2>&1) || status=$?
[[ $status -eq 2 ]] || fail "outside repo: $status"
printf 'ok: %s\n' "$tname"

printf 'ok: hook\n'
