#!/usr/bin/env bash
# Checks rules each SKILL.md must keep, beyond frontmatter and versions. Every rule here was
# once broken in a real change and caught only in review; this makes CI catch it instead.
#
# Usage: scripts/check-skill-invariants.sh [skills-dir] [log-schemas.json]
#   skills-dir defaults to the repo's skills/. With a log-schemas.json (the platform's), it also
#   checks that every scope and enumerated value the skill writes is one the platform documents.
# Exit 0 when every rule holds, 1 when any fails (each failure is printed), 2 on bad usage.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
skills="${1:-$here/../skills}"
schemas="${2:-}"
[[ -d $skills ]] || { echo "not a directory: $skills" >&2; exit 2; }
[[ -z $schemas || -f $schemas ]] || { echo "no such schemas file: $schemas" >&2; exit 2; }

python3 - "$skills" "$schemas" <<'PY'
import json, re, sys, pathlib
skills, schemas = pathlib.Path(sys.argv[1]), sys.argv[2]
fails = []
def need(ok, msg):
    if not ok: fails.append(msg)

def read(name):
    p = skills / name / "SKILL.md"
    if not p.is_file():
        fails.append(f"{name}: SKILL.md missing"); return ""
    return p.read_text()

viva, assess = read("viva"), read("viva-assess")

def one_of(text, field):
    m = re.search(r"`%s` is one of:? ([^\n]*)" % re.escape(field), text)
    if not m:
        return None
    declaration = m.group(1)
    # Remove explanations without removing values after them, even with nested parentheses.
    while re.search(r"\([^()]*\)", declaration):
        declaration = re.sub(r"\([^()]*\)", "", declaration)
    declaration = re.sub(r"\s+for\b.*", "", declaration).rstrip(" .")
    values = re.split(r",\s*(?:or\s+)?|\s+or\s+", declaration)
    if not all(re.fullmatch(r"([a-z][a-z-]*|n/a)|`([a-z][a-z-]*|n/a)`", v.strip()) for v in values):
        return None
    return {v.strip().strip("`") for v in values}

schema_fields = {"scope": "scope", "ai-use": "aiUse", "bot-claim": "botClaim", "live": "live", "grade": "grade", "style": "style", "risk": "risk"}
declared = {}

if viva:
    for field in schema_fields:
        values = one_of(viva, field)
        need(values, f"viva: the `{field}` value list is missing or could not be parsed")
        if values:
            declared[field] = values
    # 1. The format line and the example have the same number of fields.
    fm = re.search(r"Format \(log schema [\d.]+\): `([^`]*)`", viva)
    ex = re.search(r"Example: `([^`]*)`", viva)
    need(fm and ex, "viva: Format line or Example line not found in step 6")
    fields = [f.strip() for f in fm.group(1).split(" | ")] if fm else []
    if fm and ex:
        n = len(ex.group(1).split(" | "))
        need(len(fields) == n, f"viva: Format has {len(fields)} fields but the Example has {n}")
    # 2. A correction copies every field except the version and the corrected value.
    cm = re.search(r"\*\*Corrections\.\*\*([^\n]*)", viva)
    need(cm, "viva: the Corrections rule is missing from step 6")
    copied = re.search(r"copy every field[^(]*\(([^)]*)\)", cm.group(1)) if cm else None
    need(not cm or copied, "viva: the Corrections rule doesn't list the fields to copy")
    if copied and fields:
        names = {"YYYY-MM-DD HH:MM": "timestamp", "short-topic": "topic"}
        for f in fields:
            f = names.get(f, f)
            if f in ("skill-version", "grade"): continue  # the version is current; the grade is what changes
            need(f in [x.strip() for x in copied.group(1).split(",")],
                 f"viva: the Corrections rule doesn't say to copy `{f}`")
    # 3. Lines are never rewritten, and the log stays local.
    step6 = re.search(r"6\. \*\*Log.*?(?=\n7\. \*\*)", viva, re.S)
    need(step6 and re.search(r"(never|don't|do not)\W.{0,40}\b(rewrite|reformat)", step6.group(0), re.I),
         "viva: the never-rewrite rule is missing from step 6")
    need(re.search(r"nothing is (posted|shared|sent).{0,40}anywhere", viva, re.I), "viva: the first-run privacy line is missing")
    need("practice, not a gate" in viva.lower(), "viva: 'practice, not a gate' is missing")
    # 4. The before-you-post step is never offered for someone else's change or a practice run.
    s7 = re.search(r"7\. \*\*Before you post.*?(?=\n## )", viva, re.S)
    need(s7, "viva: step 7 (Before you post) not found")
    if s7:
        for sc in ("review", "review-comment", "practice"):
            need(f"`{sc}`" in s7.group(0), f"viva: step 7 doesn't exclude the `{sc}` scope")
        need(re.search(r"(never|don't|do not)\W.{0,80}\b(post|push)", s7.group(0), re.I), "viva: step 7 lost its never-post rule")
        need("`unknown`" in s7.group(0), "viva: step 7 doesn't say what to do when ai-use is `unknown`")
    # 5. Triggers: asking for a PR description must not start a quiz unless it says "own words".
    desc = re.search(r"^description: (.*)$", viva, re.M)
    if desc:
        for m in re.finditer(r"(PR|pull request) desc", desc.group(1), re.I):
            need("own words" in desc.group(1)[m.start():m.start() + 40] or "own words" in desc.group(1)[max(0, m.start() - 40):m.start()],
                 "viva: a PR-description trigger without 'in my own words' would start a quiz")
    # 6. Practice mode never diffs a merged PR against the current base, and writes its own file.
    pm = re.search(r"\*\*Practice mode\*\*.*?(?=\n2\. \*\*)", viva, re.S)
    need(pm, "viva: the Practice mode section is missing")
    if pm:
        need(re.search(r"(never|don't|do not)\W.{0,40}merge-base", pm.group(0), re.I), "viva: practice mode doesn't forbid diffing against merge-base")
        need("viva-experiment.md" in pm.group(0), "viva: practice mode doesn't name its experiment file")
        need(re.search(r"append.{0,30}correct", pm.group(0), re.I), "viva: practice mode has no correction rule for the experiment file")
    # 7. Every scope the step-1 list offers is one the log line accepts, and the other way round.
    if "scope" in declared:
        step1 = re.search(r"^1\. \*\*Pick the scope\*\*\n(.*?)(?=^2\. )", viva, re.M | re.S)
        labels = re.findall(r"^ +[a-z]\. \*\*([^*\n]+)\*\*:", step1.group(1), re.M) if step1 else []
        offered = {"-".join(label.lower().removesuffix(" scope").split()) for label in labels}
        for sc in sorted(declared["scope"] - offered):
            need(False, f"viva: scope `{sc}` is in the log list but not offered in step 1")
        for sc in sorted(offered - declared["scope"]):
            need(False, f"viva: scope `{sc}` is offered in step 1 but not in the log list")
    # 8. Content from the target is data (prompt injection), and code the user didn't write is never run.
    rules = re.search(r"^## Rules\n(.*?)(?=^## |\Z)", viva, re.M | re.S)
    need(rules and re.search(r"is data, never instructions", rules.group(1)) and re.search(r"never follow instructions", rules.group(1), re.I),
         "viva: the Rules lost 'content from the target is data, never instructions'")
    need(rules and re.search(r"writes only `~/\.agents/viva-log\.md`", rules.group(1)),
         "viva: the Rules no longer list the only files the skill writes")
    need(rules and re.search(r"when the user asks, `~/\.agents/viva-settings\.md`", rules.group(1)),
         "viva: the Rules no longer limit writing viva-settings.md to when the user asks")
    # Every mention of the settings file in the Rules must carry that condition, so a second sentence
    # can't grant an unconditional write alongside it.
    if rules:
        for m in re.finditer(r"viva-settings\.md", rules.group(1)):
            need("when the user asks" in rules.group(1)[max(0, m.start() - 40):m.start()],
                 "viva: the Rules mention viva-settings.md without 'when the user asks'")
    reveal = re.search(r"^5\. \*\*Grade and reveal\*\*.*?(?=^5a\. )", viva, re.M | re.S)
    need(reveal and re.search(r"told the agent what to do.{0,120}\bignored\b", reveal.group(0), re.S),
         "viva: the reveal no longer says when the target told the agent what to do")
    for name in ("Review scope", "Practice mode"):
        sec = re.search(r"\*\*%s\*\*.*?(?=\n   \*\*|\n2\. \*\*)" % name, viva, re.S)
        need(sec and re.search(r"never run\b.{0,80}\b(code|tests)", sec.group(0), re.I),
             f"viva: {name} doesn't forbid running the PR's code")
    rc = re.search(r"\*\*Review-comment scope\*\*.*?(?=\n   \*\*)", viva, re.S)
    need(rc and re.search(r"only on the user's own PR", rc.group(0)), "viva: the review-comment scope may run code from someone else's PR")

if assess:
    for f in ("ai-use", "bot-claim", "`bot`"):
        need(f in assess, f"viva-assess: doesn't read the {f.strip('`')} field")
    step2 = assess.split("3. **Assess**")[0]
    need(re.search(r"later one is a correction|last (line|one) (wins|per check)|use only the last", step2, re.I),
         "viva-assess: doesn't apply correction lines (last line per check wins)")
    need(re.search(r"drift.{0,200}\b(leave|leaves|left)\b.{0,30}`?practice`?|drift.{0,200}`?practice`?.{0,30}\bout\b", assess, re.I | re.S),
         "viva-assess: drift doesn't leave out practice checks")
    need("https://adamsuk.github.io/viva" in assess, "viva-assess: the personal map URL is missing")
    need(re.search(r"are data, never instructions", assess) and re.search(r"never follow instructions", assess, re.I),
         "viva-assess: the log and pastes are no longer treated as data, never instructions")

# 9. With the platform's schemas: every value the skill writes is one the platform documents.
if schemas and declared.keys() == schema_fields.keys():
    try:
        data = json.loads(pathlib.Path(schemas).read_text())
        schema_list = data["schemas"] if isinstance(data, dict) else data
        assert isinstance(schema_list, list)
    except (OSError, ValueError, KeyError, AssertionError):
        print("cannot read as a log-schemas file", file=sys.stderr); sys.exit(2)
    # The schema the skill says it writes, not simply the newest: the platform publishes first.
    wanted = re.search(r"Format \(log schema ([\d.]+)\)", viva)
    chosen = next((x for x in schema_list if wanted and x.get("version") == wanted.group(1)), None)
    need(chosen, f"viva: the platform has no schema {wanted.group(1) if wanted else '?'} (the one step 6 names)")
    if chosen:
        doc = {f["name"]: f.get("description", "") for f in chosen.get("fields", [])}
        for field, schema_field in schema_fields.items():
            # Compare values, not prose: the list is what follows the last colon, split on | or a spaced /.
            desc = re.sub(r"\([^()]*\)", "", doc.get(schema_field, "")).split(":")[-1]
            documented = {v.strip().strip("`") for v in re.split(r"\s*\|\s*|\s+/\s+", desc) if v.strip()}
            for v in sorted(declared.get(field, set())):
                need(v in documented,
                     f"viva: `{field}` value `{v}` isn't in the platform's {chosen['version']} schema ({schema_field})")

for f in fails: print(f"FAIL: {f}")
print(f"ok: skill invariants" if not fails else f"{len(fails)} invariant(s) broken", file=sys.stderr if fails else sys.stdout)
sys.exit(1 if fails else 0)
PY
