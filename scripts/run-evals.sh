#!/usr/bin/env bash
# Scenario evals: runs the skills in a real agent (Claude Code, headless) against a fixture repo
# and checks what they write. Each scenario gets a fresh HOME and a fresh repo, so your own
# ~/.agents/viva-log.md is never touched.
#
# Usage: scripts/run-evals.sh [scenario ...]     (default: every directory under evals/)
# Env:   EVAL_MODEL (default sonnet), EVAL_BUDGET_USD per call (default 1),
#        EVAL_PERMISSION_MODE (default acceptEdits), KEEP=1 keeps temp dirs.
# Needs: the claude CLI, signed in or with ANTHROPIC_API_KEY. Costs real usage; not run in CI by default.
# A scenario is evals/<name>/ with 1.txt, 2.txt ... (one user turn each) and expect.json.
# Exit 0 when every scenario passes, 1 otherwise, 2 on bad usage.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root="$here/.."
command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 2; }
model="${EVAL_MODEL:-sonnet}"
budget="${EVAL_BUDGET_USD:-1}"
mode="${EVAL_PERMISSION_MODE:-acceptEdits}"
cd "$root/evals" || exit 2
scenarios=("$@")
[[ ${#scenarios[@]} -gt 0 ]] || mapfile -t scenarios < <(find . -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

failed=0
for name in "${scenarios[@]}"; do
  [[ -f $name/expect.json && -f $name/1.txt ]] || { echo "no scenario: $name" >&2; exit 2; }
  home=$(mktemp -d); work=$(mktemp -d)
  bash fixture-repo.sh "$work"
  mkdir -p "$work/.claude/skills" "$home/.agents" && cp -r "$root/skills/." "$work/.claude/skills/"
  sid=""; turn=1; cost=0; out_dir="$home/.eval"; mkdir -p "$out_dir"
  while [[ -f $name/$turn.txt ]]; do
    args=(-p "$(cat "$name/$turn.txt")" --output-format json --model "$model" --max-turns 25
          --max-budget-usd "$budget" --permission-mode "$mode" --add-dir "$home"
          --allowedTools "Read,Write,Edit,Glob,Grep,Bash(git *),Bash(ls *),Bash(date *),Bash(python3 *)"
          --append-system-prompt "This is a scripted test run. Your home directory is $home. Create or change files only with the Write and Edit tools (use the absolute path $home/.agents/viva-log.md for the log, never ~), and keep Bash to single git, date or python3 commands.")
    [[ -n $sid ]] && args+=(--resume "$sid")
    (cd "$work" && HOME="$home" claude "${args[@]}" < /dev/null > "$out_dir/turn$turn.json" 2> "$out_dir/turn$turn.err")
    sid=$(jq -r '.session_id // empty' "$out_dir/turn$turn.json")
    cost=$(jq -r --arg c "$cost" '($c|tonumber) + (.total_cost_usd // 0)' "$out_dir/turn$turn.json")
    turn=$((turn + 1))
  done
  if python3 "$here/check-eval.py" "$root/skills/viva/SKILL.md" "$name/expect.json" "$home" "$out_dir"; then
    printf 'ok: %s ($%.2f)\n' "$name" "$cost"
  else
    printf 'FAIL: %s ($%.2f; transcripts in %s)\n' "$name" "$cost" "$out_dir"; failed=1; KEEP=1
  fi
  [[ ${KEEP:-} == 1 ]] || rm -rf "$home" "$work"
done
exit $failed
