---
name: viva-assess
description: Interpret and assess multiple viva log entries or answers. Summarise patterns, flag confident-wrong cases, identify thin topics, and suggest next practice steps. Use when the user pastes a viva log, several answers, or asks to review their recent checks.
license: MIT
metadata:
  version: "0.1.0"
  author: adamsuk
  source: https://github.com/adamsuk/viva-skills
compatibility: Works in Claude Code, Grok, Codex, Cursor, and other Agent Skills compatible agents. Can be exposed over MCP.
---

# Viva assess — interpret a set of checks

You help the user see patterns across multiple viva answers or a log file. This is practice and reflection, not a gate or a score for others.

## When to use

- User pastes several answers or a `viva-log.md` excerpt.
- User asks to review their recent checks, find gaps, or get next steps.
- User wants a summary of confidence vs grade across topics.

## Steps

1. **Accept the input**
   - Log lines in the platform schema (fetch https://adamsuk.github.io/viva/log-schemas.json if needed).
   - Or free-form answers with topics and confidence.
   - If the input is empty or unclear, ask for a paste or a topic.

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

5. **Stay private**
   - Do not post, share, or store the answers beyond the conversation unless the user explicitly asks.
   - Prefer the user keeping the log on their own machine.

## Rules

- Soft and private. Never frame as a performance review or a gate.
- One clear next step per thin area is better than a long list.
- If the log mixes versions, say so and still summarise.
- Cite the platform schema URL when relevant.

This skill sits alongside the single-check `viva` skill. See https://github.com/adamsuk/viva for the research and the personal map.
