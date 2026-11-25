#!/usr/bin/env bash
# Tests for scripts/check-skill-invariants.sh: the real skills pass, and each rule fails, with
# its own message, when a copy of the skills is broken the way a real change once broke it.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
script="$here/check-skill-invariants.sh"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
fail() { printf 'FAIL: %s: %s\n' "$tname" "$1" >&2; exit 1; }

cat > "$ROOT/schemas.json" << 'JSON'
{"schemas": [{"version": "0.6.0", "skillVersions": "0.6.x", "fields": [
  {"name": "scope", "description": "session | checkout | last-commit | uncommitted | named | review-comment | review | practice"},
  {"name": "aiUse", "description": "How the change was made: hand | explained | generated-then-understood | delegated | agent | unknown"},
  {"name": "botClaim", "description": "For scope review-comment, whether the bot's claim held: held | partly | wrong | n/a"}
]}]}
JSON

tname="the repo's own skills keep every rule"
out=$(bash "$script" "$here/../skills" "$ROOT/schemas.json" 2>&1) || fail "$out"
printf 'ok: %s\n' "$tname"

# broken <name> <file> <python expression on s> <expected message>
broken() {
  tname=$1; local d="$ROOT/case"; rm -rf "$d"; cp -r "$here/../skills" "$d"
  python3 - "$d/$2" "$3" <<'PY'
import sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read(); t = eval(expr)
assert t != s, "mutation did nothing"
open(p, "w").write(t)
PY
  local status=0 out; out=$(bash "$script" "$d" "$ROOT/schemas.json" 2>&1) || status=$?
  [[ $status -eq 1 ]] || fail "expected exit 1, got $status: $out"
  grep -qF -- "$4" <<< "$out" || fail "expected '$4' in: $out"
  printf 'ok: %s\n' "$tname"
}

broken "step 7 offered for practice runs" viva/SKILL.md \
  's.replace("`review`, `review-comment` or `practice` scopes", "`review` or `review-comment` scopes")' \
  "step 7 doesn't exclude the \`practice\` scope"
broken "a correction that drops the bot field" viva/SKILL.md \
  's.replace("ai-use, bot-claim, bot)", "ai-use, bot-claim)")' \
  "Corrections rule doesn't say to copy \`bot\`"
broken "a bare PR-description trigger" viva/SKILL.md \
  's.replace("help me write my PR description in my own words", "write my PR description")' \
  "would start a quiz"
broken "practice diffing a merged PR against merge-base" viva/SKILL.md \
  's.replace("Never diff against `git merge-base`", "Diff against `git merge-base`")' \
  "doesn't forbid diffing against merge-base"
broken "an example with a field the format doesn't have" viva/SKILL.md \
  's.replace("| n/a | n/a`", "| n/a | n/a | extra`", 1)' \
  "fields but the Example has"
broken "the never-rewrite rule removed" viva/SKILL.md \
  's.replace("Never rewrite or reformat earlier lines", "Tidy earlier lines")' \
  "never-rewrite rule is missing"
broken "a scope the platform doesn't document" viva/SKILL.md \
  's.replace("review, practice.", "review, practice, pairing.")' \
  "\`pairing\` isn't in the platform's 0.6.0 schema"
broken "viva-assess counting superseded lines" viva-assess/SKILL.md \
  's.replace("the later one is a correction", "the later one is another check").replace("use only the last", "count both").replace("the last line is a correction", "count each line")' \
  "doesn't apply correction lines"
broken "viva-assess drift including practice" viva-assess/SKILL.md \
  's.replace("**Drift.** Leave `practice` checks out: they are old PRs, not recent work. ", "**Drift.** ")' \
  "drift doesn't leave out practice checks"

tname="bad usage"
status=0; bash "$script" "$ROOT/nope" >/dev/null 2>&1 || status=$?; [[ $status -eq 2 ]] || fail "missing dir: $status"
status=0; bash "$script" "$here/../skills" "$ROOT/nope.json" >/dev/null 2>&1 || status=$?; [[ $status -eq 2 ]] || fail "missing schemas: $status"
printf 'ok: %s\n' "$tname"

printf 'ok: check-skill-invariants\n'
