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
    return set(re.findall(r"`?([a-z][a-z-]*|n/a)`?(?=[,.;\s(]|$)", m.group(1).split("(")[0])) if m else None

if viva:
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
    need("Never rewrite or reformat earlier lines" in viva, "viva: the never-rewrite rule is missing")
    need("Nothing is posted, shared or sent anywhere" in viva, "viva: the first-run privacy line is missing")
    need("practice, not a gate" in viva.lower(), "viva: 'practice, not a gate' is missing")
    # 4. The before-you-post step is never offered for someone else's change or a practice run.
    s7 = re.search(r"7\. \*\*Before you post.*?(?=\n## )", viva, re.S)
    need(s7, "viva: step 7 (Before you post) not found")
    if s7:
        for sc in ("review", "review-comment", "practice"):
            need(f"`{sc}`" in s7.group(0), f"viva: step 7 doesn't exclude the `{sc}` scope")
        need("Never commit, amend, push, edit a PR, or post" in s7.group(0), "viva: step 7 lost its never-post rule")
        need("`unknown`" in s7.group(0), "viva: step 7 doesn't say what to do when ai-use is `unknown`")
    # 5. Triggers: asking for a PR description must not start a quiz unless it says "own words".
    desc = re.search(r"^description: (.*)$", viva, re.M)
    if desc:
        for m in re.finditer(r"PR description", desc.group(1)):
            need("own words" in desc.group(1)[m.start():m.start() + 40] or "own words" in desc.group(1)[max(0, m.start() - 40):m.start()],
                 "viva: a PR-description trigger without 'in my own words' would start a quiz")
    # 6. Practice mode never diffs a merged PR against the current base, and writes its own file.
    pm = re.search(r"\*\*Practice mode\*\*.*?(?=\n2\. \*\*)", viva, re.S)
    need(pm, "viva: the Practice mode section is missing")
    if pm:
        need("Never diff against `git merge-base`" in pm.group(0), "viva: practice mode doesn't forbid diffing against merge-base")
        need("viva-experiment.md" in pm.group(0), "viva: practice mode doesn't name its experiment file")
        need("append a corrected line" in pm.group(0), "viva: practice mode has no correction rule for the experiment file")
    # 7. Every scope the step-1 list offers is one the log line accepts, and the other way round.
    scopes = one_of(viva, "scope")
    need(scopes, "viva: the `scope` value list is missing")
    if scopes:
        for sc in scopes:
            step1 = viva.split("2. **Get the target")[0].lower()
            need(f"**{sc.replace('-', ' ')}" in step1 or f"`{sc}`" in step1,
                 f"viva: scope `{sc}` is in the log list but not offered in step 1")

if assess:
    for f in ("ai-use", "bot-claim", "`bot`"):
        need(f in assess, f"viva-assess: doesn't read the {f.strip('`')} field")
    need(re.search(r"later one is a correction|last line", assess), "viva-assess: doesn't apply correction lines (last line per check wins)")
    need(re.search(r"Drift\.\*\* Leave `practice` checks out", assess), "viva-assess: drift doesn't leave out practice checks")
    need("https://adamsuk.github.io/viva" in assess, "viva-assess: the personal map URL is missing")

# 8. With the platform's schemas: every value the skill writes is one the platform documents.
if schemas and viva:
    data = json.loads(pathlib.Path(schemas).read_text())
    latest = data["schemas"][-1]
    doc = {f["name"]: f.get("description", "") for f in latest["fields"]}
    for field, schema_field in (("scope", "scope"), ("ai-use", "aiUse"), ("bot-claim", "botClaim")):
        vals = one_of(viva, field) or set()
        for v in vals:
            need(re.search(r"(^|[\s|:])%s($|[\s|,;])" % re.escape(v), doc.get(schema_field, "")),
                 f"viva: `{field}` value `{v}` isn't in the platform's {latest['version']} schema ({schema_field})")

for f in fails: print(f"FAIL: {f}")
print(f"ok: skill invariants" if not fails else f"{len(fails)} invariant(s) broken", file=sys.stderr if fails else sys.stdout)
sys.exit(1 if fails else 0)
PY
