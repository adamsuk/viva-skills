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
  {"name": "botClaim", "description": "For scope review-comment, whether the bot's claim held: held | partly | wrong | n/a"},
  {"name": "live", "description": "live | partly-live | hazard"},
  {"name": "grade", "description": "understood / partial / missed / disputed (or free text)"}
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
broken "a logged scope absent from the step-1 offers" viva/SKILL.md \
  's.replace("   h. **Practice**:", "   - **Practice**:")' \
  "scope \`practice\` is in the log list but not offered in step 1"
broken "an offered scope absent from the log list" viva/SKILL.md \
  's.replace("review, practice.", "review.")' \
  "scope \`practice\` is offered in step 1 but not in the log list"
broken "an invalid bot-claim fallback after an explanation" viva/SKILL.md \
  's.replace("), or `n/a` for every other scope", "), or `not-applicable` for every other scope")' \
  "\`bot-claim\` value \`not-applicable\` isn't in the platform's 0.6.0 schema"
broken "a missing scope declaration" viva/SKILL.md \
  's.replace("`scope` is one of:", "`scope` can be:")' \
  "the \`scope\` value list is missing"
broken "a missing ai-use declaration" viva/SKILL.md \
  's.replace("`ai-use` is one of:", "`ai-use` can be:")' \
  "the \`ai-use\` value list is missing"
broken "an empty bot-claim declaration" viva/SKILL.md \
  's.replace(next(line for line in s.splitlines() if "`bot-claim` is one of:" in line), "   - `bot-claim` is one of: (no values).")' \
  "the \`bot-claim\` value list is missing"
broken "viva-assess counting superseded lines" viva-assess/SKILL.md \
  's.replace("the later one is a correction", "the later one is another check").replace("use only the last", "count both")' \
  "doesn't apply correction lines"
broken "viva-assess drift including practice" viva-assess/SKILL.md \
  's.replace("**Drift.** Leave `practice` checks out: they are old PRs, not recent work. ", "**Drift.** ")' \
  "drift doesn't leave out practice checks"

broken "a live value the platform doesn't document" viva/SKILL.md \
  's.replace("`live` is one of: `live`, `partly-live`", "`live` is one of: `live`, `flaky`, `partly-live`")' \
  "\`live\` value \`flaky\`"
broken "a grade the platform doesn't document" viva/SKILL.md \
  's.replace("`grade` is one of: understood, partial, missed, disputed", "`grade` is one of: understood, great, partial, missed, disputed")' \
  "\`grade\` value \`great\`"
broken "a value that only appears in the description's prose" viva/SKILL.md \
  's.replace("`ai-use` is one of: `hand`,", "`ai-use` is one of: `change`, `hand`,")' \
  "\`ai-use\` value \`change\`"

# allowed <name> <file> <python expression>: a reasonable rewording still passes
allowed() {
  tname=$1; local d="$ROOT/case"; rm -rf "$d"; cp -r "$here/../skills" "$d"
  python3 - "$d/$2" "$3" <<'PY'
import sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read(); t = eval(expr)
assert t != s, "rewording did nothing"
open(p, "w").write(t)
PY
  out=$(bash "$script" "$d" "$ROOT/schemas.json" 2>&1) || fail "rewording rejected: $out"
  printf 'ok: %s\n' "$tname"
}
allowed "rewording: Oxford comma in the privacy line" viva/SKILL.md 's.replace("Nothing is posted, shared or sent anywhere", "Nothing is posted, shared, or sent anywhere")'
allowed "rewording: do not diff against merge-base" viva/SKILL.md 's.replace("Never diff against `git merge-base`", "Do not diff against `git merge-base`")'
allowed "rewording: never rewrite, reformat or delete" viva/SKILL.md 's.replace("Never rewrite or reformat earlier lines", "Never rewrite, reformat or delete earlier lines")'

tname="the schema step 6 names is used, not the newest"
python3 - "$ROOT/schemas.json" "$ROOT/newer.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); new = json.loads(json.dumps(d["schemas"][0]))
new["version"], new["skillVersions"] = "0.7.0", "0.7.x"
for f in new["fields"]:
    if f["name"] == "aiUse": f["description"] = "How: by-hand | with-ai"
d["schemas"].append(new); json.dump(d, open(sys.argv[2], "w"))
PY
out=$(bash "$script" "$here/../skills" "$ROOT/newer.json" 2>&1) || fail "$out"
printf 'ok: %s\n' "$tname"

tname="a malformed schemas file is bad usage"
printf 'not json' > "$ROOT/bad.json"
status=0; bash "$script" "$here/../skills" "$ROOT/bad.json" >/dev/null 2>&1 || status=$?; [[ $status -eq 2 ]] || fail "exit $status"
printf 'ok: %s\n' "$tname"

tname="bad usage"
status=0; bash "$script" "$ROOT/nope" >/dev/null 2>&1 || status=$?; [[ $status -eq 2 ]] || fail "missing dir: $status"
status=0; bash "$script" "$here/../skills" "$ROOT/nope.json" >/dev/null 2>&1 || status=$?; [[ $status -eq 2 ]] || fail "missing schemas: $status"
printf 'ok: %s\n' "$tname"

printf 'ok: check-skill-invariants\n'
