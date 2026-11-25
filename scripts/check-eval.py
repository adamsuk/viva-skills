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

exp = lines(home / ".agents/viva-experiment.md")
if len(exp) != expect.get("experiment_lines", 0):
    fails.append(f"expected {expect.get('experiment_lines', 0)} experiment line(s), found {len(exp)}")

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
