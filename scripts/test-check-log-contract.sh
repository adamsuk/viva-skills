#!/usr/bin/env bash
# Tests for scripts/check-log-contract.sh. No network: uses a fixture schemas file.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/check-log-contract.sh"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

fail() { printf 'FAIL: %s: %s\n' "$tname" "$1" >&2; exit 1; }
run() { status=0; out=$(bash "$script" "$@" 2>&1) || status=$?; }

# Two formats: 0.3.1 (10 fields) covers 0.3.x; 0.4.0 (11 fields) covers 0.4.x.
cat > "$ROOT/schemas.json" << 'JSON'
{"schemas": [
  {"version": "0.3.1", "skillVersions": "0.3.x", "fields": [1,2,3,4,5,6,7,8,9,10]},
  {"version": "0.4.0", "skillVersions": "0.4.x", "fields": [1,2,3,4,5,6,7,8,9,10,11]}
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

tname="no schema covers the version"
d=$(case_dir uncovered); skill "$d" "${L10/VER/0.5.0}"
run "$ROOT/schemas.json" "$d"; [[ $status -eq 1 ]] || fail "exit $status"
grep -qF 'demo/SKILL.md:5: no schema covers version 0.5.0' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

tname="wrong field count for the covering schema"
d=$(case_dir count); skill "$d" "${L10/VER/0.4.1}"
run "$ROOT/schemas.json" "$d"; [[ $status -eq 1 ]] || fail "exit $status"
grep -qF '10 fields, schema 0.4.0 has 11' <<< "$out" || fail "$out"
printf 'ok: %s\n' "$tname"

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
