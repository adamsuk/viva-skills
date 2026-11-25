# AGENTS.md: viva-skills

Repo-specific rules for agents working here. They add to the software factory's
shared rules (adamsuk/software-factory `AGENTS.md`); where the two conflict, the
stricter one wins.

## What this repo is

Provider-agnostic [Agent Skills](https://agentskills.io): `skills/viva` (one
scenario question on a recent change, with confidence, graded and logged) and
`skills/viva-assess` (interpret a set of checks). Each skill is a folder with a
`SKILL.md` (YAML frontmatter plus instructions). The research and the personal
map live in [adamsuk/viva](https://github.com/adamsuk/viva).

## Test

```bash
bash scripts/test-validate-skills.sh && bash scripts/validate-skills.sh && bash scripts/test-check-log-contract.sh && bash scripts/test-hook.sh && bash scripts/test-check-skill-invariants.sh && bash scripts/check-skill-invariants.sh
```

CI also checks every example log line against the live
[log-schemas.json](https://adamsuk.github.io/viva/log-schemas.json) with
`scripts/check-log-contract.sh`. If you change the line a skill writes, the platform
needs the matching schema first (adamsuk/viva `src/viva/log-schemas.ts`), or CI fails.

That is `agents.test_command` in `.github/factory.yml` and what `test.yml`
runs. `validate-skills.sh` checks frontmatter, that `name` matches the folder,
and that every "currently X.Y.Z" and example log line in a body matches
`metadata.version`.

## Rules for skill changes

- Bump `metadata.version` in every skill you change and update every
  "currently X.Y.Z" and example log line in that body to match. Minor means the
  log line's format changed (its fields, so a new schema version); everything
  else is a patch, including wording, behaviour and changes to the values
  written into existing fields. The platform matches log lines by `major.minor`, so a
  minor bump without a new schema breaks the contract check and the map.
- The log format belongs to the platform. A change to the line a skill writes
  needs a new schema version in adamsuk/viva (`src/viva/log-schemas.ts`) first;
  the skill then moves to the minor version that schema covers.
- Private and soft by default: the log stays on the user's device; nothing is
  posted, shared or sent anywhere unless the user asks. Practice, never a gate.
- Never add anything that scores or ranks a named person.
- `VERSION` is the repository release (git tag) version, not a skill version.

## Changelog

Every PR adds a dated entry (`## YYYY-MM-DD`, Europe/London) to `CHANGELOG.md`
under Added, Changed or Removed: what changed, why, and the PR link. Apply the
`skip-changelog` label only when nothing is worth logging.
