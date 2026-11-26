---
name: viva-assess
description: Interpret and assess multiple viva log entries or answers. Summarise patterns, flag confident-wrong cases, identify thin topics, and suggest next practice steps. Use when the user pastes a viva log, several answers, or asks to review their recent checks.
license: MIT
metadata:
  version: "0.4.2"
  author: adamsuk
  source: https://github.com/adamsuk/viva-skills
compatibility: Works in Claude Code, Grok, Codex, Cursor, and other Agent Skills compatible agents. Can be exposed over MCP.
---

# Viva assess — interpret a set of checks

You help the user see patterns across multiple viva answers or a log file. This is practice and reflection, not a gate or a score for others. More accumulated checks give a better picture.

## When to use

- User pastes several answers or a `viva-log.md` excerpt.
- User asks to review their recent checks, find gaps, or get next steps.
- User wants a summary of confidence vs grade across topics.

## Steps

1. **Find the input**
   - Prefer the local file `~/.agents/viva-log.md` if it exists and the agent has filesystem access.
   - If the user provides a path, file, or paste, use that instead.
   - Otherwise tell the user they can open the personal map on the viva platform (https://adamsuk.github.io/viva) where the log is kept in that browser on that device, and ask them to paste an export or the relevant lines.
   - Prefer the platform schema (fetch https://adamsuk.github.io/viva/log-schemas.json if needed). Free-form answers with topics and confidence are also fine.

2. **Parse and group**
   - Prefer the versioned schema. Fall back to treating each line as topic + confidence + grade if the format is loose.
   - If two lines share timestamp, repo, branch-or-pr, commit-or-ref, topic (ignoring case and spacing) and scope, the later one is a correction (for example a dispute that stood after logging): use only the last.
   - Group by topic. Note skill versions if present.
   - Topics are free text, so the same area can appear under different wordings (`webhook retry`, `retry policy for webhooks`). Treat clearly identical areas as one topic, and say in the report which wordings you merged, so the user can check it. When unsure, keep them apart.
   - Lines from skill 0.4.x and later carry an 11th field, `ai-use` (`hand`, `explained`, `generated-then-understood`, `delegated`, `agent`, `unknown`). Older lines have none: treat them as `unknown`.
   - Lines from skill 0.5.x add a 12th field, `bot-claim` (`held`, `partly`, `wrong`, `n/a`): for a `review-comment` check, whether the bot's claim held. Older lines have none: treat them as `n/a`.
   - Lines from skill 0.6.x add a 13th field, `bot`: which bot made a checked review comment (`n/a` for other scopes). Older review-comment lines have none: treat the bot as `unknown`.

3. **Assess**
   - Leave `disputed` checks out of every signal below: the question was faulty, not the user.
   - Flag confident-wrong (high confidence + missed/partial that is clearly wrong).
   - Identify thin topics: repeated partial/miss, or single high-confidence miss.
   - Note solid areas (recent understood with matching or lower confidence).
   - Separate mechanism / observed / hazard claims when the original questions did.
   - **Does confidence separate knowing from guessing?** Count understood checks per confidence band: high (4–5, or "high"), mid (3, or "medium"), low (1–2, or "low"). Skip any band with fewer than 3 checks. If both high and low have enough, say in one sentence whether high-confidence checks were understood more often than low ones, with the counts (for example "high: 7 of 9 understood; low: 2 of 5"). If they weren't, say confidence isn't yet telling guesses from knowledge, so it is worth pausing on a confident answer before relying on it.
   - **Drift.** Leave `practice` checks out: they are old PRs, not recent work. With 10 or more counted checks in date order, compare the latest 5 with all the earlier ones on three things: the understood rate, the share at high confidence, and the share of `delegated` or `agent` changes (counting only checks that record `ai-use`, and only when each side has at least 3 of them, so older lines without the field can't fake a rise). If one moved the wrong way by 20 points or more (understood down, or delegated/agent up, or high confidence up while understood fell), say so in one line with both numbers, as a nudge to slow down on the next change. Otherwise say nothing about drift. Five checks is a small sample: never call it a trend or a decline in the user.
   - If any `review-comment` line records `bot-claim`, give one line with how many of the checked bot comments held, partly held, or were wrong, leaving out disputed checks; if more than one bot appears, give the counts per bot. If most were wrong, say the bot's comments deserve a quick check before anyone acts on them. Catching a wrong claim counts as understanding, not a miss.
   - If any line records `ai-use`, compare grades by it (counts only). If delegated or agent-built changes were understood less often than the rest, say so in one line and suggest asking the agent why, or generating then making sure the user could rewrite it, on the next change. This is the pattern the research found matters most; it is a nudge, not a verdict.

4. **Report**
   - Short summary: N checks, M topics, K thin (and D disputed, if any).
   - The confidence sentence and any drift line, if step 3 produced them.
   - If there are disputed checks, list them on one line as a question-quality note (several in one topic suggest the questions there need work), never as a gap.
   - List thin topics with the strongest signal and one concrete next step (hand-code the next change in that area, ask why, pair, or do another viva).
   - List solid topics briefly.
   - Do not invent metrics or claim this proves understanding. A model can answer most of these questions; the value is the human's practice.
   - Always mention the source (local file, browser map, or paste).
   - **Required:** End the report with this exact sentence (or equivalent that includes the full URL): "You can also open the personal map at https://adamsuk.github.io/viva and drop the same log file (or paste an export) to see the interactive topic view."

4a. **Experiment 1 (only if asked)**
   - If the user asks about the experiment or their practice runs, read `~/.agents/viva-experiment.md` (one line per practice PR: `date | repo | pr-N | think-or-recall | grade | confidence | size | days-since-merge | kind`; older lines have only the first six fields, so treat the last three as `unknown`). If a repo and PR appear more than once, the last line is a correction: use only that one.
   - Report the counts of think, recall and mixed (and skips), and how many of the 20 are done (a skipped think-or-recall doesn't count). Leaving `disputed` grades out, give the understood count within each of think, recall and mixed, and say whether the understood rate differs between think and recall, with the counts. Skip any group with fewer than 3. Don't draw a conclusion the numbers don't support: a small sample is a sketch, not a result.
   - Where lines have them, give the understood count (disputed left out) by `size` (S, M, L), by days since merge (under 7, 7 to 30, over 30) and by `kind`, under the same rule of at least 3 per group. Leave `unknown` and `skip` out of these groups and say how many were left out. If older lines lack the fields, say the user can fill them in with "/viva practice fill".
   - Offer to format it as a row for the Log table in Viva's EXPERIMENTS.md, but don't post or commit it.

5. **Stay private**
   - Do not post, share, or store the answers beyond the local file, browser map, or conversation unless the user explicitly asks.

## Rules

- Soft and private. Never frame as a performance review or a gate.
- One clear next step per thin area is better than a long list.
- If the log mixes versions, say so and still summarise.
- Cite the platform schema URL when relevant.
- Prefer the local device log so more checks improve the picture over time. Browser map or paste is the fallback.
- The personal map URL must appear in every report. Do not omit it.

This skill sits alongside the single-check `viva` skill. See https://github.com/adamsuk/viva for the research and the personal map.
