# Changelog

All notable changes to the viva skills are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each section is the date the change merged (YYYY-MM-DD, Europe/London). Skill versions are in each `SKILL.md` (`metadata.version`).

## 2026-11-23

### Added

- Factory onboarding: `scripts/validate-skills.sh` checks every `SKILL.md` (frontmatter, `name` matches the folder, `metadata.version` is X.Y.Z, and every "currently X.Y.Z" and example log line in the body matches it), with tests in `scripts/test-validate-skills.sh`. A `test` workflow pinned by SHA runs both on every pull request, plus the changelog check, a size-label caller, `.github/factory.yml`, `AGENTS.md`, `CODEOWNERS`, and issue and pull-request templates. Why: nothing checked the skills, so a version mismatch between a skill and the log it writes could ship unnoticed, and the factory had no test command to gate changes here ([adamsuk/software-factory#456](https://github.com/adamsuk/software-factory/issues/456), [#1](https://github.com/adamsuk/viva-skills/pull/1)).
- State as of onboarding: `viva` 0.3.3, `viva-assess` 0.1.5.
