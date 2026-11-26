#!/usr/bin/env bash
# Scenario evals: runs the skills in a real agent (Claude Code, headless) against a fixture repo
# and checks what they write. Each scenario gets a fresh HOME and a fresh repo, so your own
# ~/.agents/viva-log.md is never touched.
#
# Usage: scripts/run-evals.sh [scenario ...]     (default: every directory under evals/)
# Env:   EVAL_MODEL (default sonnet), EVAL_BUDGET_USD per call (default 1),
#        EVAL_MAX_TOTAL_USD cap for the whole run (default 5; no call starts once it is spent),
#        EVAL_PERMISSION_MODE (default acceptEdits), KEEP=1 keeps temp dirs.
# Needs: the claude CLI, jq and ANTHROPIC_API_KEY (each scenario replaces HOME, so a stored sign-in
#        isn't seen). Costs real usage; not run in CI by default.
# A scenario is evals/<name>/ with 1.txt, 2.txt ... (one user turn each) and expect.json. It may also
# have fixture-repo.sh (its own fixture instead of evals/fixture-repo.sh) and bin/ (stub commands put
# first on PATH, e.g. a fake gh; the agent may then run `gh`).
# Exit 0 when every scenario passes, 1 otherwise, 2 on bad usage.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root="$here/.."
command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 2; }
[[ -n ${ANTHROPIC_API_KEY:-} ]] || { echo "set ANTHROPIC_API_KEY: each scenario uses a throwaway HOME, so a stored sign-in isn't seen" >&2; exit 2; }
model="${EVAL_MODEL:-sonnet}"
budget="${EVAL_BUDGET_USD:-1}"
mode="${EVAL_PERMISSION_MODE:-acceptEdits}"
cap="${EVAL_MAX_TOTAL_USD:-5}"
num='^[0-9]+([.][0-9]+)?$'
[[ $budget =~ $num && $cap =~ $num ]] || { echo "EVAL_BUDGET_USD and EVAL_MAX_TOTAL_USD must be plain numbers" >&2; exit 2; }
cd "$root/evals" || exit 2
scenarios=("$@")
if [[ ${#scenarios[@]} -eq 0 ]]; then
  for d in */; do [[ -f $d/expect.json ]] && scenarios+=("${d%/}"); done
fi
[[ ${#scenarios[@]} -gt 0 ]] || { echo "no scenarios found in evals/" >&2; exit 2; }

failed=0; total=0
for name in "${scenarios[@]}"; do
  [[ -f $name/expect.json && -f $name/1.txt ]] || { echo "no scenario: $name" >&2; exit 2; }
  home=$(mktemp -d); work=$(mktemp -d)
  # The fixture uses the throwaway HOME too, so your git config (signing, hooks) doesn't apply.
  fixture=fixture-repo.sh; [[ -f $name/fixture-repo.sh ]] && fixture="$name/fixture-repo.sh"
  HOME="$home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null env -u XDG_CONFIG_HOME bash "$fixture" "$work" \
    || { echo "fixture failed for $name (left in $work, HOME $home)" >&2; exit 2; }
  printf '.claude/\n' >> "$work/.git/info/exclude"
  if ! { mkdir -p "$work/.claude/skills" "$home/.agents" && cp -r "$root/skills/." "$work/.claude/skills/"; }; then
    echo "FAIL: $name (couldn't copy the skills into $work; no agent calls made)" >&2; failed=1; continue
  fi
  tools="Read,Write,Edit,Glob,Grep,Bash(git *),Bash(date *),Bash(python3 *)"; stubs=""
  [[ -d $name/bin ]] && { stubs="$PWD/$name/bin"; tools+=",Bash(gh *)"; }
  sid=""; turn=1; cost=0; turn_failed=0; out_dir="$home/.eval"; mkdir -p "$out_dir"
  while [[ -f $name/$turn.txt ]]; do
    # Run-wide cap: no call starts once it is spent, and each call is also capped at what is left.
    left=$(awk -v c="$cap" -v t="$total" 'BEGIN { printf "%.4f", c - t }')
    if awk -v l="$left" 'BEGIN { exit !(l <= 0) }'; then
      echo "  cost cap reached: \$$total of \$$cap spent; not starting turn $turn of $name" >&2
      turn_failed=1; break
    fi
    call_budget=$(awk -v b="$budget" -v l="$left" 'BEGIN { print (l < b ? l : b) }')
    args=(-p "$(cat "$name/$turn.txt")" --output-format json --model "$model" --max-turns 25
          --max-budget-usd "$call_budget" --permission-mode "$mode" --add-dir "$home"
          --allowedTools "$tools"
          --append-system-prompt "This is a scripted test run. Your home directory is $home. Create or change files only with the Write and Edit tools (use the absolute path $home/.agents/viva-log.md for the log, never ~), and keep Bash to single git, date or python3 commands.")
    [[ -n $sid ]] && args+=(--resume "$sid")
    (cd "$work" && HOME="$home" PATH="${stubs:+$stubs:}$PATH" env -u CLAUDE_CONFIG_DIR claude "${args[@]}" < /dev/null \
       > "$out_dir/turn$turn.json" 2> "$out_dir/turn$turn.err")
    rc=$?
    # The log as it stood after this turn, so a check can see that earlier lines weren't touched.
    cp "$home/.agents/viva-log.md" "$out_dir/log-after-turn$turn.md" 2>/dev/null || : > "$out_dir/log-after-turn$turn.md"
    step=$(jq -r '.total_cost_usd // 0' "$out_dir/turn$turn.json" 2>/dev/null || echo 0)
    [[ $step =~ $num ]] || step=0
    cost=$(awk -v a="$cost" -v b="$step" 'BEGIN { print a + b }'); total=$(awk -v a="$total" -v b="$step" 'BEGIN { print a + b }')
    sid=$(jq -r '.session_id // empty' "$out_dir/turn$turn.json" 2>/dev/null)
    if [[ $rc -ne 0 || -z $sid ]]; then
      who="with no session"; [[ -n $sid ]] && who="(session $sid)"
      echo "  turn $turn: claude exited $rc $who; see $out_dir/turn$turn.err. Stopping this scenario." >&2
      turn_failed=1; break
    fi
    turn=$((turn + 1))
  done
  # A failed turn fails the scenario even if what was written so far passes the checks.
  if python3 "$here/check-eval.py" "$root/skills/viva/SKILL.md" "$name/expect.json" "$home" "$out_dir" \
     && [[ $turn_failed -eq 0 ]]; then
    printf 'ok: %s ($%.2f)\n' "$name" "$cost"
  else
    printf 'FAIL: %s ($%.2f; transcripts in %s, repo in %s)\n' "$name" "$cost" "$out_dir" "$work"; failed=1
    continue   # keep this scenario's temp dirs for inspection
  fi
  [[ ${KEEP:-} == 1 ]] || rm -rf "$home" "$work"
done
exit $failed
