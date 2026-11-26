# Scenario evals

These run the skills in a real agent (Claude Code, headless) and check what they write. CI's
invariant checks (`scripts/check-skill-invariants.sh`, from #25) cover the instructions; these cover the
behaviour.

```bash
bash scripts/run-evals.sh                 # every scenario
bash scripts/run-evals.sh review-comment  # one
```

Each scenario gets a throwaway git repo (`evals/fixture-repo.sh`: a bounded-retry commit) and a
throwaway HOME, so your own `~/.agents/viva-log.md` is never touched. The skills are copied into
the repo's `.claude/skills/`. Turns run in order with `claude -p` and `--resume`; then
`scripts/check-eval.py` checks the log lines against the skill's own format line (field count,
skill version, timestamp, grade, and the fields in `expect.json`), the experiment file, and what
the agent said.

- Needs the `claude` CLI and `jq`. Each scenario overrides HOME, so a sign-in stored under `~/.claude` may not carry over: set `ANTHROPIC_API_KEY`. The runner unsets `CLAUDE_CONFIG_DIR`, so your own skills, settings and hooks stay out of the run. It costs real usage: about
  $0.20–0.30 per scenario with the default model (`EVAL_MODEL=sonnet`).
- `EVAL_BUDGET_USD` caps each call (default 1). `EVAL_PERMISSION_MODE` defaults to `acceptEdits`;
  the agent may use Write/Edit and single `git`, `date` or `python3` commands. `python3` can still reach outside the temp dirs by absolute path; run evals only on skills you trust.
- `KEEP=1` keeps every scenario's temp dirs; a failing scenario always keeps its own and prints where.
- A turn that fails (non-zero exit or no session) fails its scenario, even if what was written so far passes the checks.
- `bash scripts/test-check-eval.sh` tests the checker and the runner offline, with a stand-in for `claude`: no agent, no cost. Run it after changing either.

## Scenarios

| Scenario | Turns | Checks |
|---|---|---|
| `last-commit` | `/viva check my last commit`, then an answer with confidence and "by hand" | first-run notice names the log; one 13-field line, current version, scope last-commit, ai-use hand, bot fields n/a, live partly-live or hazard (`fetch` has no caller) |
| `no-log` | the same, answering with "no log" | nothing written |
| `review-comment` | a CodeRabbit comment whose claim is wrong, then a correct rejection | one line with scope review-comment, bot-claim wrong, bot coderabbit, grade understood |

Add one by creating `evals/<name>/` with `1.txt`, `2.txt`, … (one user turn each) and an
`expect.json` (`lines`, `fields`, `experiment_lines`, `said_turn1`).
