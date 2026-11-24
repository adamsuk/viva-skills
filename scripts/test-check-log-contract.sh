#!/usr/bin/env bash
# Tests for scripts/check-log-contract.sh. No network: uses a fixture schemas file.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/check-log-contract.sh"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

fail() { printf 'FAIL: %s: %s\n' "$tname" "$1" >&2; exit 1; }
run() { status=0; out=$(bash "$script" "$@" 2>&1) || status=$?; }

# Three formats: 0.3.1 (10 fields) covers 0.3.x; 0.4.0 (11) covers 0.4.x; 0.5.0 (12) covers 0.5.x.
cat > "$ROOT/schemas.json" << 'JSON'
{"schemas": [
  {"version": "0.3.1", "skillVersions": "0.3.x", "fields": [1,2,3,4,5,6,7,8,9,10]},
  {"version": "0.4.0", "skillVersions": "0.4.x", "fields": [1,2,3,4,5,6,7,8,9,10,11]},
  {"version": "0.5.0", "skillVersions": "0.5.x", "fields": [1,2,3,4,5,6,7,8,9,10,11,12]}
]}
JSON

L10='2026-11-20 17:25 | VER | o/r | pr-1 | abc | topic | 4 | understood | session | live'
# skill <dir> <body line>
skill() { mkdir -p "$1/demo"; printf -- '---\nname: demo\n---\n\nExample: `%s`\n' "$2" > "$1/demo/SKILL.md"; }
case_dir() { d="$ROOT/$1"; rm -rf "$d"; mkdir -p "$d"; printf '%s' "$d"; }

tname="exact version, right field count"
d=$(case_dir exact); skill "$d" "${L10/VER/0.3.1}"
run "$ROOT/schemas.json" "$d"; [[ $status -eq 0 ]] || fail "exit $status: $out"
printf 'ok: %s\n' "$tname"

tname="major.minor.x range covers a later patch"
d=$(case_dir range); skill "$d" "${L10/VER/0.4.7} | delegated"
run "$ROOT/schemas.json" "$d"; [[ $status -eq 0 ]] || fail "exit $status: $out"
printf 'ok: %s\n' "$tname"

tname="a 12-field 0.5.x line matches schema 0.5.0"
d=$(case_dir v05); skill "$d" "${L10/VER/0.5.2} | hand | n/a"
run "$ROOT/schemas.json" "$d"; [[ $status -eq 0 ]] || fail "exit $status: $out"
printf 'ok: %s\n' "$tname"

tname="no schema covers the version"
d=$(case_dir uncovered); skill "$d" "${L10/VER/0.6.0}"
run "$ROOT/schemas.json" "$d"; [[ $status -eq 1 ]] || fail "exit $status"
grep -qF 'demo/SKILL.md:5: no schema covers version 0.6.0' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="wrong field count for the covering schema"
d=$(case_dir count); skill "$d" "${L10/VER/0.4.1}"
run "$ROOT/schemas.json" "$d"; [[ $status -eq 1 ]] || fail "exit $status"
grep -qF '10 fields, schema 0.4.0 has 11' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="an example line outside inline code is still checked"
d=$(case_dir plain); mkdir -p "$d/demo"
printf -- '---\nname: demo\n---\n\n```\n%s\n```\n' "${L10/VER/0.6.0}" > "$d/demo/SKILL.md"
run "$ROOT/schemas.json" "$d"; [[ $status -eq 1 ]] || fail "exit $status: $out"
grep -qF 'no schema covers version 0.6.0' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="finding no example lines fails"
d=$(case_dir none); mkdir -p "$d/demo"; printf -- '---\nname: demo\n---\n\nNo examples here.\n' > "$d/demo/SKILL.md"
run "$ROOT/schemas.json" "$d"; [[ $status -eq 1 ]] || fail "exit $status: $out"
grep -qF 'no example log lines found' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="a trailing empty field counts as a field"
d=$(case_dir trailing); skill "$d" "${L10/VER/0.3.1} | "
run "$ROOT/schemas.json" "$d"; [[ $status -eq 1 ]] || fail "exit $status: $out"
grep -qF '11 fields, schema 0.3.1 has 10' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="an unreadable schemas file exits 2"
if [[ $EUID -eq 0 ]]; then
  # root can read a mode-000 file, so this case only runs as a normal user (as in CI).
  printf 'skip: %s (running as root)\n' "$tname"
else
  cp "$ROOT/schemas.json" "$ROOT/locked.json"; chmod 000 "$ROOT/locked.json"
  run "$ROOT/locked.json" "$here/../skills"; chmod 600 "$ROOT/locked.json"
  [[ $status -eq 2 ]] || fail "exit $status: $out"
  grep -qF 'cannot read' <<< "$out" || fail "$out"
  printf 'ok: %s\n' "$tname"
fi

tname="the repo's own skills pass against the fixture"
run "$ROOT/schemas.json" "$here/../skills"; [[ $status -eq 0 ]] || fail "exit $status: $out"
printf 'ok: %s\n' "$tname"

tname="bad usage and a bad schemas file"
run; [[ $status -eq 2 ]] || fail "no args: exit $status"
run "$ROOT/missing.json"; [[ $status -eq 2 ]] || fail "missing file: exit $status"
printf '{"nope": 1}\n' > "$ROOT/bad.json"
run "$ROOT/bad.json" "$here/../skills"; [[ $status -eq 2 ]] || fail "bad json: exit $status"
printf 'ok: %s\n' "$tname"

printf 'ok: check-log-contract\n'
