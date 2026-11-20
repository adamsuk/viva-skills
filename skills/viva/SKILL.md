---
name: viva
description: After a change I made (or an agent made for me), ask one small scenario question about what the change actually does, capture my confidence, then reveal the answer and the key lines. Use when I say viva, check my last commit, quiz me on this change, or want to practice understanding a recent diff.
license: MIT
metadata:
  version: "0.1.0"
  author: adamsuk
  source: https://github.com/adamsuk/viva-skills
compatibility: Requires git. Works in Claude Code, Grok, Codex, Cursor, and other Agent Skills compatible agents.
---

# Viva — one scenario question on your change

You are helping the user check their own understanding of a recent change. This is practice, not a gate. N/A or "skip" is always fine.

## Steps

1. **Get the target**
   - Prefer the last commit the user made, or the current unstaged/staged diff if they say so.
   - If they point at a specific commit, PR, file, or range, use that.
   - Read the diff and the relevant surrounding code (use git, file reads, or whatever the agent provides). Keep the scope small.

2. **Generate one scenario question**
   - Concrete situation that exercises the change.
   - Asks what happens and why, not trivia, function names, or pure recall.
   - Open-book is fine; the point is whether the user can reason about the behaviour.
   - Keep it short.

3. **Ask and wait**
   - Present the question.
   - Ask for a confidence rating (1–5 or high/medium/low).
   - Wait for the answer. Do not give hints or the answer yet.

4. **Grade and reveal**
   - Grade as understood / partial / missed (wording does not matter; mental model does).
   - Show the key lines that decide the outcome.
   - Give the correct reasoning in a few sentences.
   - Note whether confidence matched reality (especially confident-wrong cases).

5. **Optional log**
   - If the user asks, append a one-line entry to `viva-log.md` in the current directory (or a path they specify): date, short topic, confidence, grade.
   - Otherwise leave it in the chat.

## Rules

- One question only. If they want another, ask.
- Soft and private by default. Do not post to PRs or shared surfaces unless explicitly asked.
- If the change is trivial or empty, say so and stop.
- Treat user and agent-generated code the same: the goal is the human's understanding.

This skill implements the personal practice loop from the Viva research project. See https://github.com/adamsuk/viva for context and evidence labels.
