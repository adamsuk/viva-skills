#!/usr/bin/env bash
# Offline tests for scripts/check-eval.py: no agent, just fake results in a temp HOME.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
skill="$here/../skills/viva/SKILL.md"
ver=$(sed -n 's/^  version: "\(.*\)"/\1/p' "$skill")
ROOT=$(mktemp -d); trap 'rm -rf "$ROOT"' EXIT
fail() { printf 'FAIL: %s: %s\n' "$tname" "$1" >&2; exit 1; }
cat > "$ROOT/expect.json" <<'J'
{"lines": 1, "fields": {"scope": ["review-comment"], "bot-claim": ["wrong"], "bot": ["coderabbit"]}, "said_turn1": ["viva-log.md"]}
J
setup() { rm -rf "$ROOT/h"; mkdir -p "$ROOT/h/.agents" "$ROOT/h/.eval"; printf '%s\n' "$1" > "$ROOT/h/.agents/viva-log.md"
  printf '{"result": "%s", "is_error": false}\n' "${2:-kept in ~/.agents/viva-log.md}" > "$ROOT/h/.eval/turn1.json"; }
run() { status=0; out=$(python3 "$here/check-eval.py" "$skill" "$ROOT/expect.json" "$ROOT/h" "$ROOT/h/.eval" 2>&1) || status=$?; }
good="2026-11-25 10:30 | $ver | o/r | pr-1 | abc | retry bound | 4 | understood | review-comment | live | unknown | wrong | coderabbit"

tname="a correct line passes"; setup "$good"; run; [[ $status -eq 0 ]] || fail "$out"; printf 'ok: %s\n' "$tname"
tname="a line without the time fails"; setup "${good/10:30 /}"; run
[[ $status -eq 1 ]] && grep -q "bad timestamp" <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"
tname="a wrong verdict fails"; setup "${good/| wrong |/| held |}"; run
[[ $status -eq 1 ]] && grep -q "bot-claim" <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"
tname="an old skill version fails"; setup "${good/| $ver |/| 0.0.1 |}"; run
[[ $status -eq 1 ]] && grep -q "skill version" <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"
tname="a missing field fails"; setup "${good% | coderabbit}"; run
[[ $status -eq 1 ]] && grep -q "fields, format has" <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"
tname="no first-run notice fails"; setup "$good" "hello"; run
[[ $status -eq 1 ]] && grep -q "didn't mention" <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"
tname="a crashed turn is reported, not a traceback"; setup "$good"; printf 'not json' > "$ROOT/h/.eval/turn1.json"; run
[[ $status -eq 1 ]] && grep -q "turn1.json is missing or not JSON" <<< "$out" && ! grep -q Traceback <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"
printf 'ok: check-eval\n'
