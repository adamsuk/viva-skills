---
name: viva-assess
description: Interpret and assess multiple viva log entries or answers. Summarise patterns, flag confident-wrong cases, identify thin topics, and suggest next practice steps. Use when the user pastes a viva log, several answers, or asks to review their recent checks.
license: MIT
metadata:
  version: "0.1.3"
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
   - Otherwise tell the user they can open the personal map on the viva platform (https://adamsuk.github.io/viva) where the log is stored in the browser (IndexedDB) on that device, and ask them to paste an export or the relevant lines.
   - Prefer the platform schema (fetch https://adamsuk.github.io/viva/log-schemas.json if needed). Free-form answers with topics and confidence are also fine.

2. **Parse and group**
   - Prefer the versioned schema. Fall back to treating each line as topic + confidence + grade if the format is loose.
   - Group by topic. Note skill versions if present.

3. **Assess**
   - Flag confident-wrong (high confidence + missed/partial that is clearly wrong).
   - Identify thin topics: repeated partial/miss, or single high-confidence miss.
   - Note solid areas (recent understood with matching or lower confidence).
   - Separate mechanism / observed / hazard claims when the original questions did.

4. **Report**
   - Short summary: N checks, M topics, K thin.
   - List thin topics with the strongest signal and one concrete next step (hand-code the next change in that area, ask why, pair, or do another viva).
   - List solid topics briefly.
   - Do not invent metrics or claim this proves understanding. A model can answer most of these questions; the value is the human's practice.
   - If the source was the local file or browser map, mention it so the user knows the history is accumulating there.

5. **Stay private**
   - Do not post, share, or store the answers beyond the local file, browser map, or conversation unless the user explicitly asks.

## Rules

- Soft and private. Never frame as a performance review or a gate.
- One clear next step per thin area is better than a long list.
- If the log mixes versions, say so and still summarise.
- Cite the platform schema URL when relevant.
- Prefer the local device log so more checks improve the picture over time. Browser map or paste is the fallback.

This skill sits alongside the single-check `viva` skill. See https://github.com/adamsuk/viva for the research and the personal map.
