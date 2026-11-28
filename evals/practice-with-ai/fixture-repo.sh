#!/usr/bin/env bash
# The practice fixture (PR #7 merged), plus a first practice pass already done: one practice log line
# and one `aid none` experiment line for pr-7, written into the throwaway HOME.
set -euo pipefail
here="$(dirname "$0")"
bash "$here/../practice/fixture-repo.sh" "$1"
ver=$(sed -n 's/^  version: "\(.*\)"$/\1/p' "$here/../../skills/viva/SKILL.md")
sha=$(git -C "$1" rev-parse --short HEAD)
mkdir -p "$HOME/.agents"
printf '%s\n' "2026-11-21 10:30 | $ver | eval-user/fixture | pr-7 | $sha | retry bound | 4 | understood | practice | live | hand | n/a | n/a | scenario | n/a" > "$HOME/.agents/viva-log.md"
printf '%s\n' "# viva experiment 1: think or recall" "2026-11-21 10:30 | eval-user/fixture | pr-7 | think | understood | 4 | S | 1 | backend | none" > "$HOME/.agents/viva-experiment.md"
