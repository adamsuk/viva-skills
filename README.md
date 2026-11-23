# viva-skills

Provider-agnostic [Agent Skills](https://agentskills.io) for deliberate practice and comprehension checks, inspired by the [Viva](https://github.com/adamsuk/viva) research project.

Skills follow the open standard (SKILL.md with YAML frontmatter) and work across Claude Code, Grok, Codex, Cursor, Gemini CLI, and other compatible agents.

## Skills

- **viva** — One small scenario question about your recent change (or a pointed-to diff/commit), with a confidence rating. Practice, not a gate.
- **viva-assess** — Interpret and assess multiple answers or a log excerpt. Flags confident-wrong cases, thin topics, and suggests next practice steps.

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

/viva-assess
# or
Review these viva answers / this log
```

The single-check skill asks one scenario question, takes your answer + confidence, then shows the key lines and grades the response. It then appends one line to `~/.agents/viva-log.md` on your device, so the history builds up across sessions and repositories. If the agent has no filesystem access, it prints the line instead, and you can keep it in the personal map in your browser. Say "no log" to skip logging.

The assess skill summarises a set of answers or a log excerpt and suggests next steps. It reads the same local file first, or a paste.

### What is stored

Private by default: nothing is posted, shared or sent anywhere unless you ask.

- **What**: one line per check: date and time, skill version, repository, branch or PR, commit, a short topic, your confidence, the grade, the scope the question covered, and whether the behaviour was live.
- **Where**: `~/.agents/viva-log.md` on your device, or the personal map's storage in your browser if you put it there.
- **Why**: so you can see your own solid and thin areas over time on the [personal map](https://adamsuk.github.io/viva).
- **How long**: until you delete it. Delete the file (`rm ~/.agents/viva-log.md`), or press Forget this log on the personal map.

See the [Viva research](https://github.com/adamsuk/viva) for the evidence behind the approach and the full process model. The personal map on the site is the local viewer for the log.

## Contributing

PRs welcome for additional skills or improvements. Keep skills pure (instructions + optional scripts/references), privacy-first, and soft (practice, not hard gates).

## License

MIT
