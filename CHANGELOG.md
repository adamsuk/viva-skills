# Changelog

All notable changes to the viva skills are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each section is the date the change merged (YYYY-MM-DD, Europe/London). Skill versions are in each `SKILL.md` (`metadata.version`).

## 2026-11-23

### Changed

- `viva` 0.3.4 says what it keeps before the first question on a device: the fields of the log line, that it stays in `~/.agents/viva-log.md` and is never sent anywhere, why, how long, and that "no log" skips it. Both skills now say the personal map keeps a pasted log "in that browser on that device" instead of naming IndexedDB (`viva-assess` 0.1.6). Why: the guide's Best practice is to say what is collected, why, and for how long before the first question, and the map keeps the log in local storage ([adamsuk/software-factory#460](https://github.com/adamsuk/software-factory/issues/460), [#3](https://github.com/adamsuk/viva-skills/pull/3)).
- The README says what the skills actually do with your answers: one line per check in `~/.agents/viva-log.md` on your device, never posted or shared unless you ask, and a new What is stored section lists the fields, where they live, why, and how to delete them. It said the default was a private GitHub gist, which contradicted both skills. Why: the research is Strong that monitoring without a clear, transparent purpose goes with worse attitudes, and the guide recommends saying what is collected before collecting it ([adamsuk/software-factory#457](https://github.com/adamsuk/software-factory/issues/457), [#2](https://github.com/adamsuk/viva-skills/pull/2)).

### Added

- Factory onboarding: `scripts/validate-skills.sh` checks every `SKILL.md` (frontmatter, `name` matches the folder, `metadata.version` is X.Y.Z, and every "currently X.Y.Z" and example log line in the body matches it), with tests in `scripts/test-validate-skills.sh`. A `test` workflow pinned by SHA runs both on every pull request, plus the changelog check, a size-label caller, `.github/factory.yml`, `AGENTS.md`, `CODEOWNERS`, and issue and pull-request templates. Why: nothing checked the skills, so a version mismatch between a skill and the log it writes could ship unnoticed, and the factory had no test command to gate changes here ([adamsuk/software-factory#456](https://github.com/adamsuk/software-factory/issues/456), [#1](https://github.com/adamsuk/viva-skills/pull/1)).
- State as of onboarding: `viva` 0.3.3, `viva-assess` 0.1.5.
