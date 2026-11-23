#!/usr/bin/env bash
# Checks that every example log line in skills/*/SKILL.md would parse on the
# Viva platform: a schema in log-schemas.json covers the line's version (its
# exact `version`, or a `skillVersions` of `X.Y.Z` or `major.minor.x`), and the
# line has exactly that schema's number of fields.
#
# Usage: scripts/check-log-contract.sh <log-schemas.json> [skills-dir]
#   CI passes the live file from https://adamsuk.github.io/viva/log-schemas.json;
#   tests pass a fixture.
#
# Exit 0 when every example line passes, 1 with one "file:line: problem" per
# failure, 2 on bad usage or an unreadable schemas file. Bash and Python 3 only.
set -euo pipefail

[[ $# -ge 1 && $# -le 2 ]] || { echo "usage: scripts/check-log-contract.sh <log-schemas.json> [skills-dir]" >&2; exit 2; }
schemas=$1
dir=${2:-skills}
[[ -f $schemas ]] || { echo "no schemas file: $schemas" >&2; exit 2; }
[[ -d $dir ]] || { echo "not a directory: $dir" >&2; exit 2; }

python3 - "$schemas" "$dir" << 'PY'
import json
import pathlib
import re
import sys

schemas_path, root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
try:
    data = json.loads(schemas_path.read_text(encoding="utf-8"))
    schemas = data["schemas"]
    if not all(isinstance(s["version"], str) and isinstance(s["fields"], list) for s in schemas):
        raise TypeError("each schema needs a version string and a fields list")
except (ValueError, KeyError, TypeError) as e:
    print(f"{schemas_path}: not a log-schemas file ({e})", file=sys.stderr)
    sys.exit(2)

LINE = re.compile(r"`(\d{4}-\d\d-\d\d \d\d:\d\d \| [^`]*)`")


def covers(pattern, version):
    if pattern == version:
        return True
    m = re.fullmatch(r"(\d+)\.(\d+)\.x", pattern or "")
    return bool(m) and re.fullmatch(rf"{m[1]}\.{m[2]}\.\d+", version) is not None


def schema_for(version):
    for s in schemas:
        if s["version"] == version:
            return s
    for s in schemas:
        if covers(s.get("skillVersions", ""), version):
            return s
    return None


problems, checked = [], 0
for path in sorted(root.glob("*/SKILL.md")):
    for n, text in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
        for m in LINE.finditer(text):
            checked += 1
            parts = [p.strip() for p in m[1].split(" | ")]
            version = parts[1]
            schema = schema_for(version)
            if schema is None:
                problems.append(f"{path}:{n}: no schema covers version {version}")
            elif len(parts) != len(schema["fields"]):
                problems.append(
                    f"{path}:{n}: {len(parts)} fields, schema {schema['version']} has {len(schema['fields'])}"
                )

for p in problems:
    print(p)
if not problems:
    print(f"ok: {checked} example log line(s) match {schemas_path.name}")
sys.exit(1 if problems else 0)
PY
