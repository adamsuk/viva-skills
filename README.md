# viva-skills

Provider-agnostic [Agent Skills](https://agentskills.io) for deliberate practice and comprehension checks, inspired by the [Viva](https://github.com/adamsuk/viva) research project.

Skills follow the open standard (SKILL.md with YAML frontmatter) and work across Claude Code, Grok, Codex, Cursor, Gemini CLI, and other compatible agents.

## Skills

- **viva** — One small scenario question about your recent change (or a pointed-to diff/commit), with a confidence rating. Practice, not a gate.

## Installation

### Recommended: skills CLI (works for most agents)

```bash
npx skills add adamsuk/viva-skills --skill viva
```

Add `--global` / `-g` for user-level install, or run from a project root for project-level.

For multiple agents at once, or to list available skills:

```bash
npx skills add adamsuk/viva-skills --list
npx skills add adamsuk/viva-skills --skill viva --agent claude-code --agent codex -g
```

### Manual / agent-specific

Clone or download the `skills/viva` folder and place it in the agent's skills directory:

| Agent | Personal | Project |
|-------|----------|---------|
| Claude Code | `~/.claude/skills/viva/` | `.claude/skills/viva/` |
| Grok | `~/.grok/skills/viva/` or `~/.agents/skills/viva/` or `~/.claude/skills/viva/` | `.grok/skills/viva/` or `.claude/skills/viva/` |
| Codex | `~/.agents/skills/viva/` | `.agents/skills/viva/` |
| Cursor | `~/.agents/skills/viva/` or `~/.cursor/skills/viva/` | `.agents/skills/viva/` |

Grok also reads Claude Code skills with no extra setup.

After placing the folder, start a new agent session. Invoke with `/viva` or a matching phrase ("check my last commit", "viva this change").

### Versioning

- Skills include a `metadata.version` field in SKILL.md.
- This repo uses git tags (e.g. `v0.1.0`) for releases.
- To pin a version: `npx skills add adamsuk/viva-skills --skill viva --ref v0.1.0` (if supported) or clone a tag.
- Update with `npx skills update viva` or by re-installing.

## Usage

After install:

```
/viva
# or
Check my understanding of the last commit
```

The skill asks one scenario question, takes your answer + confidence, then shows the key lines and grades the response. Optional local log.

See the [Viva research](https://github.com/adamsuk/viva) for the evidence behind the approach and the full process model.

## Contributing

PRs welcome for additional skills or improvements. Keep skills pure (instructions + optional scripts/references), privacy-first, and soft (practice, not hard gates).

## License

MIT
