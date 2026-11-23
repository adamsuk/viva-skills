#!/usr/bin/env bash
# Validates every skills/<name>/SKILL.md (Agent Skills format).
#
# Usage: scripts/validate-skills.sh [skills-dir]   (default: skills)
#
# Checks, per SKILL.md:
#   - YAML frontmatter between the first two '---' lines
#   - name: present and equal to the folder name
#   - description: present and non-empty
#   - metadata.version: present and X.Y.Z
#   - every "currently X.Y.Z" in the body equals metadata.version
#   - every example log line ("YYYY-MM-DD HH:MM | X.Y.Z | ...") uses metadata.version
# And, when <skills-dir>/../VERSION exists (the repo release version), that it is X.Y.Z.
#
# Exit 0 when every skill passes, 1 with one "file: problem" line per failure,
# 2 on bad usage. Needs only Bash and Python 3 (stdlib).
set -euo pipefail

dir=${1:-skills}
[[ $# -le 1 ]] || { echo "usage: scripts/validate-skills.sh [skills-dir]" >&2; exit 2; }
[[ -d $dir ]] || { echo "not a directory: $dir" >&2; exit 2; }

python3 - "$dir" << 'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
CURRENTLY = re.compile(r"currently\s+v?(\d+\.\d+\.\d+)", re.I)
LOG_LINE = re.compile(r"\b\d{4}-\d\d-\d\d \d\d:\d\d \| (\d+\.\d+\.\d+) \|")
problems = []


def frontmatter(text):
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None, text
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return lines[1:i], "\n".join(lines[i + 1:])
    return None, text


def fields(lines):
    """Top-level keys plus metadata.* keys from simple YAML (no external parser)."""
    out = {}
    section = None
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^(\s*)([A-Za-z0-9_.-]+):\s*(.*)$", line)
        if not m:
            continue
        indent, key, value = m.groups()
        value = value.strip().strip('"').strip("'")
        if indent == "":
            section = key if value == "" else None
            out[key] = value
        elif section:
            out[f"{section}.{key}"] = value
    return out


skills = sorted(p for p in root.glob("*/SKILL.md"))
if not skills:
    problems.append(f"{root}: no */SKILL.md found")

for path in skills:
    text = path.read_text(encoding="utf-8")
    fm, body = frontmatter(text)
    if fm is None:
        problems.append(f"{path}: missing frontmatter")
        continue
    f = fields(fm)
    folder = path.parent.name
    if not f.get("name"):
        problems.append(f"{path}: frontmatter has no name")
    elif f["name"] != folder:
        problems.append(f"{path}: name '{f['name']}' does not match folder '{folder}'")
    if not f.get("description"):
        problems.append(f"{path}: frontmatter has no description")
    version = f.get("metadata.version", "")
    if not version:
        problems.append(f"{path}: frontmatter has no metadata.version")
        continue
    if not SEMVER.match(version):
        problems.append(f"{path}: metadata.version '{version}' is not X.Y.Z")
        continue
    for m in CURRENTLY.finditer(body):
        if m.group(1) != version:
            problems.append(f"{path}: body says currently {m.group(1)}, metadata.version is {version}")
    for m in LOG_LINE.finditer(body):
        if m.group(1) != version:
            problems.append(f"{path}: example log line uses {m.group(1)}, metadata.version is {version}")

version_file = root.resolve().parent / "VERSION"
if version_file.is_file():
    release = version_file.read_text(encoding="utf-8").strip()
    if not SEMVER.match(release):
        problems.append(f"{version_file.name}: '{release}' is not X.Y.Z")

for p in problems:
    print(p)
sys.exit(1 if problems else 0)
PY
