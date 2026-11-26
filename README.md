# viva-skills

Provider-agnostic [Agent Skills](https://agentskills.io) for deliberate practice and comprehension checks, inspired by the [Viva](https://github.com/adamsuk/viva) research project.

Skills follow the open standard (SKILL.md with YAML frontmatter) and work across Claude Code, Grok, Codex, Cursor, Gemini CLI, and other compatible agents.

## Skills

- **viva** — One small scenario question about your recent change (or a pointed-to diff/commit), with a confidence rating. Practice, not a gate.
  - **Dispute a question**: if the question itself was wrong, say "dispute"; the agent re-checks the code and, if you're right, logs it as `disputed` so it never counts against you.
  - **Check a bot review comment**: point it at a CodeRabbit (or other bot) comment before you forward or act on it; it verifies the claim, then asks whether you could defend or refute it. The verdict and the bot's name are logged as `bot-claim` and `bot`, so viva-assess and the map can show how often each bot's comments held.
  - **Before you approve**: reviewing someone else's or an agent's PR? Ask for one question on it first; anything you couldn't explain is worth asking the author about before approving. Logged with scope `review`.
  - **Re-checks what you missed**: when your log shows a topic you missed a week or more ago and the change touches it, the question is a re-check on that area.
  - **Before you post**: optionally helps you write the PR description in your own words (why, what, and the decision you're least sure of) and suggests an `Assisted-by` trailer from how the change was made. Nothing is posted or committed without you.
  - **Practice mode**: `/viva practice [N]` works through your own past merged PRs one at a time, one question each, and asks whether you had to think or just recalled. The answer goes to a separate local file, `~/.agents/viva-experiment.md`, for Viva's experiment 1, with the PR's rough size (S, M, L), days since merge and the kind of change (no file names or code). `/viva practice fill` adds those to earlier lines. `viva-assess` summarises it.
  - **How the change was made**: it records `ai-use` (by hand, asked AI why, generated then understood, delegated, built by an agent) so the map can show whether how you use AI tracks your understanding.
- **viva-assess** — Interpret and assess multiple answers or a log excerpt. Flags confident-wrong cases, thin topics, and suggests next practice steps. Leaves disputed checks out, compares grades by how the change was made, says whether your sure answers were understood more often than unsure ones, and flags it when your latest checks slipped against earlier ones.

## Installation

### Recommended: skills CLI (works for most agents)

```bash
npx skills add adamsuk/viva-skills --skill viva
npx skills add adamsuk/viva-skills --skill viva-assess
```

Add `--global` / `-g` for user-level install, or run from a project root for project-level.

For multiple agents at once, or to list available skills:

```bash
npx skills add adamsuk/viva-skills --list
npx skills add adamsuk/viva-skills --skill viva --agent claude-code --agent codex -g
```

### Manual / agent-specific

Clone or download the skill folder and place it in the agent's skills directory:

| Agent | Personal | Project |
|-------|----------|---------|
| Claude Code | `~/.claude/skills/<skill>/` | `.claude/skills/<skill>/` |
| Grok | `~/.grok/skills/<skill>/` or `~/.agents/skills/<skill>/` or `~/.claude/skills/<skill>/` | `.grok/skills/<skill>/` or `.claude/skills/<skill>/` |
| Codex | `~/.agents/skills/<skill>/` | `.agents/skills/<skill>/` |
| Cursor | `~/.agents/skills/<skill>/` or `~/.cursor/skills/<skill>/` | `.agents/skills/<skill>/` |

Grok also reads Claude Code skills with no extra setup.

After placing the folder, start a new agent session. Invoke with `/viva`, `/viva-assess`, or a matching phrase.

### MCP

These skills can be served over MCP using the Skills extension (SEP-2640) or a host such as [Skills Over MCP](https://skillsovermcp.com/). Point an MCP client at a server that exposes this repo's `skills/` directory. The platform site lists the same install commands and a stable schema URL.

### Versioning

- Each skill has its own `metadata.version` in its SKILL.md. The log line a skill writes carries that version, and the platform's [log-schemas.json](https://adamsuk.github.io/viva/log-schemas.json) says which skill versions each log format covers.
- The repository release version is in `VERSION`. Each release is tagged `v<VERSION>` on `main` (for example `v0.6.4`).
- To pin a release: `npx skills add adamsuk/viva-skills --skill viva --ref v0.6.4` (if your CLI supports `--ref`), or clone that tag.
- Update with `npx skills update viva` or by re-installing.

### Releasing

1. In the release pull request, bump `metadata.version` in each changed skill, set `VERSION` to the new release, and add a CHANGELOG entry.
2. After it merges, the maintainer updates local `main` and tags it: `git checkout main && git pull --ff-only origin main && git tag v$(cat VERSION) && git push origin v$(cat VERSION)`. `--ff-only` stops if local `main` has diverged, so the tag never lands on a stale commit.

`scripts/validate-skills.sh` checks that `VERSION` is X.Y.Z.

## Usage

After install:

```
/viva
# or
Check my understanding of the last commit

/viva-assess
# or
Review these viva answers / this log
```

The single-check skill asks one scenario question, takes your answer + confidence, then shows the key lines and grades the response. It then appends one line to `~/.agents/viva-log.md` on your device, so the history builds up across sessions and repositories. If the agent has no filesystem access, it prints the line instead, and you can keep it in the personal map in your browser. Say "no log" to skip logging.

The assess skill summarises a set of answers or a log excerpt and suggests next steps. It reads the same local file first, or a paste.

### Optional: a reminder after commits

A check only helps if it happens. If you want a nudge, install the post-commit reminder in a repository you work in. After every third commit it prints one line, `viva: run /viva on this commit?`, and does nothing else: it never blocks a commit, never logs anything, and never uses the network.

```bash
git clone https://github.com/adamsuk/viva-skills ~/viva-skills   # once
cd /path/to/your/repo && bash ~/viva-skills/scripts/install-hook.sh
```

- `VIVA_REMIND=off` silences it; `VIVA_REMIND_EVERY=5` reminds every fifth commit instead.
- It won't replace an existing post-commit hook unless you pass `--force`.
- If your git config sets a shared `core.hooksPath` (for example a global one), the hook would run in every repository using that directory, so the installer refuses unless you pass `--force`.
- `bash ~/viva-skills/scripts/install-hook.sh --uninstall` removes it (and only it).

### What is stored

Private by default: nothing is posted, shared or sent anywhere unless you ask.

- **What**: one line per check: date and time, skill version, repository, branch or PR, commit, a short topic, your confidence, the grade, the scope the question covered, and whether the behaviour was live, and how the change was made (by hand, with AI, or by an agent).
- **Where**: `~/.agents/viva-log.md` on your device, or the personal map's storage in your browser if you put it there.
- **Why**: so you can see your own solid and thin areas over time on the [personal map](https://adamsuk.github.io/viva).
- **How long**: until you delete it. Delete the file (`rm ~/.agents/viva-log.md`), or press Forget this log on the personal map.

See the [Viva research](https://github.com/adamsuk/viva) for the evidence behind the approach and the full process model. The personal map on the site is the local viewer for the log.

## Contributing

PRs welcome for additional skills or improvements. Keep skills pure (instructions + optional scripts/references), privacy-first, and soft (practice, not hard gates).

Scenario evals in [`evals/`](evals/README.md) run the skills in a real agent against a fixture repo (`bash scripts/run-evals.sh`). They cost real usage, so they are not part of the push checks: the **Evals** workflow runs them on demand (Actions, "Run workflow") and only when the repository has an `ANTHROPIC_API_KEY` secret.

## License

MIT
