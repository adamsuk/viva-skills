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
tname="an impossible date fails"; setup "${good/2026-11-25 10:30/2026-99-99 99:99}"; run
[[ $status -eq 1 ]] && grep -q "bad timestamp" <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"
tname="an empty later turn fails"; setup "$good"; : > "$ROOT/h/.eval/turn2.json"; run
[[ $status -eq 1 ]] && grep -q "turn2.json is missing or not JSON" <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"

# The runner, with a stand-in for the claude CLI (no agent, no cost).
mkdir -p "$ROOT/bin"
cat > "$ROOT/bin/claude" <<'SH'
#!/usr/bin/env bash
# Turn 1 succeeds. A resumed turn exits 1 if STUB_FAIL_RESUME is set, but still writes valid JSON.
if [[ " $* " == *" --resume "* && -n ${STUB_FAIL_RESUME:-} ]]; then
  echo '{"session_id": "s1", "is_error": false, "result": "", "total_cost_usd": 0}'; exit 1
fi
echo '{"session_id": "s1", "is_error": false, "result": "ok", "total_cost_usd": 0}'
SH
chmod +x "$ROOT/bin/claude"
runner() { status=0; out=$(PATH="$ROOT/bin:$PATH" TMPDIR="$ROOT" "$@" bash "$here/run-evals.sh" no-log 2>&1) || status=$?; }
tname="the runner passes a scenario whose turns succeed"; runner env; [[ $status -eq 0 ]] && grep -q "^ok: no-log" <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"
tname="a failed turn fails the scenario even when the checks pass"; runner env STUB_FAIL_RESUME=1
[[ $status -eq 1 ]] && grep -q "^FAIL: no-log" <<< "$out" || fail "$out"; printf 'ok: %s\n' "$tname"
printf 'ok: check-eval\n'
