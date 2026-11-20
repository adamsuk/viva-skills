---
name: viva
description: After a change I made (or an agent made for me), ask one small scenario question about what the change actually does, capture my confidence, then reveal the answer and the key lines. Use when I say viva, check my last commit, quiz me on this change, practice a PR or branch, or want to understand a recent diff.
license: MIT
metadata:
  version: "0.2.0"
  author: adamsuk
  source: https://github.com/adamsuk/viva-skills
compatibility: Requires git. Works in Claude Code, Grok, Codex, Cursor, and other Agent Skills compatible agents.
---

# Viva — one scenario question on your change

You are helping the user check their own understanding of a recent change. This is practice, not a gate. N/A or "skip" is always fine.

## Steps

1. **Get the target**
   - Prefer (in order):
     1. A PR or branch the user names or that is current (use `gh pr view`, `gh pr diff`, or `git diff base...HEAD` / `git log base..HEAD` when available).
     2. The last commit the user made.
     3. The current unstaged/staged diff if they say so.
   - If they point at a specific commit, PR number, file, or range, use that.
   - For a PR/branch, treat the whole change set as the unit (not every commit). Pick the most interesting behavioural change for the question.
   - Read the diff and the relevant surrounding code. Keep the scope small enough for one good question.
   - Capture context for the log: repository (owner/repo), branch (or PR number), and commit SHA or PR ref (or "working tree" / "staged").

2. **Generate one scenario question**
   - Concrete situation that exercises the change (or the key change in the PR/branch).
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

5. **Log (default)**
   - Append a one-line entry to the global log at `~/.agents/viva-log.md` (create the directory and file if needed).
   - Include the skill version from the frontmatter (currently 0.2.0).
   - Format: `YYYY-MM-DD HH:MM | skill-version | repo | branch-or-pr | commit-or-ref | short-topic | confidence | grade`
   - Example: `2026-11-20 16:30 | 0.2.0 | adamsuk/viva-skills | pr-42 | a1b2c3d | skill logging path | 4 | understood`
   - If the user says "no log" or "skip log", omit it.
   - Otherwise always log after grading.

## Rules

- One question only. If they want another (on the same PR/branch or a different change), ask.
- Soft and private by default. Do not post to PRs or shared surfaces unless explicitly asked.
- If the change is trivial or empty, say so and stop.
- Treat user and agent-generated code the same: the goal is the human's understanding.
- The log lives in the user's home under `.agents/` so a single file can be reviewed or moved later.

This skill implements the personal practice loop from the Viva research project. See https://github.com/adamsuk/viva for context and evidence labels.
