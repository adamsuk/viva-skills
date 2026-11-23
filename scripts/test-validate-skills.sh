#!/usr/bin/env bash
# Tests for scripts/validate-skills.sh. No network; works in a temp dir.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/validate-skills.sh"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

fail() { printf 'FAIL: %s: %s\n' "$tname" "$1" >&2; exit 1; }

# skill <dir> <folder> <frontmatter> <body>
skill() {
  mkdir -p "$1/$2"
  printf -- '---\n%s\n---\n\n%s\n' "$3" "$4" > "$1/$2/SKILL.md"
}

GOOD_FM='name: demo
description: Does a thing.
metadata:
  version: "1.2.3"
  author: someone'
GOOD_BODY='Use the schema (currently 1.2.3).
Example: `2026-11-20 17:25 | 1.2.3 | o/r | pr-1 | abc | topic | 4 | understood | session | live`'

run() {
  status=0
  out=$(bash "$script" "$@" 2>&1) || status=$?
}

case_dir() { d="$ROOT/$1"; rm -rf "$d"; mkdir -p "$d"; printf '%s' "$d"; }

tname="a valid skill passes"
d=$(case_dir ok); skill "$d" demo "$GOOD_FM" "$GOOD_BODY"
run "$d"; [[ $status -eq 0 ]] || fail "exit $status: $out"
printf 'ok: %s\n' "$tname"

tname="the repo's own skills pass"
run "$here/../skills"; [[ $status -eq 0 ]] || fail "exit $status: $out"
printf 'ok: %s\n' "$tname"

tname="missing frontmatter"
d=$(case_dir nofm); mkdir -p "$d/demo"; printf '# Demo\n' > "$d/demo/SKILL.md"
run "$d"; [[ $status -eq 1 ]] || fail "exit $status"; grep -qF 'demo/SKILL.md: missing frontmatter' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="name missing or not the folder"
d=$(case_dir noname); skill "$d" demo "${GOOD_FM/name: demo/}" "$GOOD_BODY"
run "$d"; [[ $status -eq 1 ]] || fail "exit $status"; grep -qF 'has no name' <<< "$out" || fail "$out"
d=$(case_dir badname); skill "$d" other "$GOOD_FM" "$GOOD_BODY"
run "$d"; [[ $status -eq 1 ]] || fail "exit $status"; grep -qF "name 'demo' does not match folder 'other'" <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="description missing"
d=$(case_dir nodesc); skill "$d" demo "${GOOD_FM/description: Does a thing./}" "$GOOD_BODY"
run "$d"; [[ $status -eq 1 ]] || fail "exit $status"; grep -qF 'has no description' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="metadata.version missing or not X.Y.Z"
d=$(case_dir nover); skill "$d" demo "${GOOD_FM/  version: \"1.2.3\"/}" "$GOOD_BODY"
run "$d"; [[ $status -eq 1 ]] || fail "exit $status"; grep -qF 'has no metadata.version' <<< "$out" || fail "$out"
d=$(case_dir badver); skill "$d" demo "${GOOD_FM/1.2.3/1.2}" "$GOOD_BODY"
run "$d"; [[ $status -eq 1 ]] || fail "exit $status"; grep -qF "metadata.version '1.2' is not X.Y.Z" <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="body 'currently' disagrees with metadata.version"
d=$(case_dir cur); skill "$d" demo "$GOOD_FM" "${GOOD_BODY/currently 1.2.3/currently 1.2.2}"
run "$d"; [[ $status -eq 1 ]] || fail "exit $status"; grep -qF 'body says currently 1.2.2, metadata.version is 1.2.3' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="example log line disagrees with metadata.version"
d=$(case_dir logv); skill "$d" demo "$GOOD_FM" "${GOOD_BODY/| 1.2.3 |/| 1.2.0 |}"
run "$d"; [[ $status -eq 1 ]] || fail "exit $status"; grep -qF 'example log line uses 1.2.0' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="no skills, bad usage"
d=$(case_dir empty)
run "$d"; [[ $status -eq 1 ]] || fail "empty dir: exit $status"
run "$ROOT/does-not-exist"; [[ $status -eq 2 ]] || fail "missing dir: exit $status"
run a b; [[ $status -eq 2 ]] || fail "two args: exit $status"
printf 'ok: %s\n' "$tname"

printf 'ok: validate-skills\n'
