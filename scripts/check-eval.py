"""Checks one eval scenario's results: the log lines viva wrote, the experiment file, what it said.

Usage: check-eval.py <viva SKILL.md> <expect.json> <eval HOME> <transcript dir>
"""
import datetime, json, pathlib, re, sys

skill, expect_path, home, out = (pathlib.Path(a) for a in sys.argv[1:5])
expect = json.loads(expect_path.read_text())
text = skill.read_text()
version = re.search(r'version: "([\d.]+)"', text).group(1)
fmt = re.search(r"Format \(log schema [\d.]+\): `([^`]*)`", text).group(1).split(" | ")
names = [{"YYYY-MM-DD HH:MM": "timestamp", "short-topic": "topic"}.get(f, f) for f in fmt]
fails = []

def turn(i):
    t = out / f"turn{i}.json"
    try:
        return json.loads(t.read_text())
    except (OSError, ValueError):
        fails.append(f"turn{i}.json is missing or not JSON (see turn{i}.err)")
        return {}

def lines(p):
    return [l for l in p.read_text().splitlines() if l.strip() and not l.startswith("#")] if p.exists() else []

log = lines(home / ".agents/viva-log.md")
if len(log) != expect["lines"]:
    fails.append(f"expected {expect['lines']} log line(s), found {len(log)}: {log}")
for raw in log:
    parts = [p.strip() for p in raw.split(" | ")]
    if len(parts) != len(names):
        fails.append(f"log line has {len(parts)} fields, format has {len(names)}: {raw}")
        continue
    row = dict(zip(names, parts))
    if row["skill-version"] != version:
        fails.append(f"skill version {row['skill-version']}, expected {version}")
    try:
        if not re.fullmatch(r"\d{4}-\d\d-\d\d \d\d:\d\d", row["timestamp"]):
            raise ValueError
        datetime.datetime.strptime(row["timestamp"], "%Y-%m-%d %H:%M")
    except ValueError:
        fails.append(f"bad timestamp {row['timestamp']!r}")
    if row["grade"] not in ("understood", "partial", "missed", "disputed"):
        fails.append(f"bad grade {row['grade']!r}")
    for field, allowed in expect.get("fields", {}).items():
        if row.get(field) not in allowed:
            fails.append(f"{field} = {row.get(field)!r}, expected one of {allowed}")

corr = expect.get("correction")
if corr:
    # The check was logged after turn N and disputed later: that line must be byte-for-byte unchanged,
    # with one correction line after it. Same check, same fields, grade disputed.
    before = lines(out / f"log-after-turn{corr['after_turn']}.md")
    if len(before) != 1:
        fails.append(f"expected 1 log line after turn {corr['after_turn']}, found {len(before)}")
    elif log[:1] != before:
        fails.append(f"the original log line was changed: {before[0]!r} is now {log[:1]!r}")
    elif len(log) == 2 and all(len(r.split(" | ")) == len(names) for r in log):
        old, new = (dict(zip(names, [p.strip() for p in r.split(" | ")])) for r in log)
        if old["grade"] == "disputed":
            fails.append("the original line already says disputed; the dispute came after it")
        if new["grade"] != "disputed":
            fails.append(f"the correction's grade is {new['grade']!r}, expected 'disputed'")
        for f in names:
            if f not in ("skill-version", "grade") and old[f] != new[f]:
                fails.append(f"the correction changed {f}: {old[f]!r} became {new[f]!r}")

exp = lines(home / ".agents/viva-experiment.md")
if len(exp) != expect.get("experiment_lines", 0):
    fails.append(f"expected {expect.get('experiment_lines', 0)} experiment line(s), found {len(exp)}")
if "experiment_fields" in expect:
    # timestamp | repo | pr-N | think-or-recall | grade | confidence | size | days-since-merge | kind,
    # tied to the practice log line.
    enames = ["timestamp", "repo", "branch-or-pr", "think-or-recall", "grade", "confidence",
              "size", "days-since-merge", "kind"]
    for raw in exp:
        parts = [p.strip() for p in raw.split(" | ")]
        if len(parts) != len(enames):
            fails.append(f"experiment line has {len(parts)} fields, expected {len(enames)}: {raw}")
            continue
        row = dict(zip(enames, parts))
        if row["size"] not in ("S", "M", "L", "unknown"):
            fails.append(f"experiment size {row['size']!r} isn't S, M, L or unknown")
        if row["kind"] not in ("backend", "frontend", "setup", "refactor", "other", "skip"):
            fails.append(f"experiment kind {row['kind']!r} isn't one of the fixed kinds or skip")
        if expect.get("experiment_days_known") and not row["days-since-merge"].isdigit():
            fails.append(f"experiment days-since-merge {row['days-since-merge']!r}: the scenario gives mergedAt, so it must be a number")
        elif not re.fullmatch(r"\d+|unknown", row["days-since-merge"]):
            fails.append(f"experiment days-since-merge {row['days-since-merge']!r} isn't a whole number or unknown")
        for field, allowed in expect["experiment_fields"].items():
            if row[field] not in allowed:
                fails.append(f"experiment {field} = {row[field]!r}, expected one of {allowed}")
        for raw_log in log:
            lp = [p.strip() for p in raw_log.split(" | ")]
            if len(lp) == len(names):
                lrow = dict(zip(names, lp))
                for f in ("timestamp", "repo", "branch-or-pr", "grade", "confidence"):
                    if lrow[f] != row[f]:
                        fails.append(f"experiment {f} {row[f]!r} doesn't match the log line's {lrow[f]!r}")

for i, needles in ((1, expect.get("said_turn1", [])),):
    said = turn(i).get("result", "") if needles else ""
    for n in needles:
        if n not in said:
            fails.append(f"turn {i} didn't mention {n!r}")

for t in sorted(out.glob("turn*.json")):
    d = turn(t.stem[4:])
    if d.get("is_error"):
        fails.append(f"{t.name}: the agent run ended in an error ({d.get('subtype')}: {str(d.get('result', ''))[:120]})")

for f in fails:
    print(f"  - {f}")
sys.exit(1 if fails else 0)
