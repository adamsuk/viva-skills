---
name: viva
description: After a change I made (or an agent made for me), ask one small scenario question about what the change actually does, capture my confidence, then reveal the answer and the key lines. Use when I say viva, check my last commit, quiz me on this change, practice a PR or branch, or want to understand a recent diff.
license: MIT
metadata:
  version: "0.3.1"
  author: adamsuk
  source: https://github.com/adamsuk/viva-skills
compatibility: Requires git. Works in Claude Code, Grok, Codex, Cursor, and other Agent Skills compatible agents.
---

# Viva — one scenario question on your change

You are helping the user check their own understanding of a recent change. This is practice, not a gate. N/A or "skip" is always fine.

## Steps

1. **Pick the scope**
   Candidate scopes, in this default order:
   a. **Session scope**: the PR, branch, or commits this conversation has been working on (a PR the agent opened/bound/reviewed/pushed to, commits it made, a ticket/PR number discussed in the chat). This is the default whenever the conversation has one.
   b. **Checkout scope**: the current branch/PR of the local checkout (`git diff <base>...HEAD`).
   c. **Last commit**: the most recent commit by the user.
   d. **Uncommitted**: staged and/or unstaged working-tree changes.
   e. **Named**: anything the user names or passes as an argument (PR number/URL, commit, range, file, path). A named target is used as-is with no confirmation.

   - Never silently choose the checkout over the session. If the session scope and the checkout scope differ (different branch, different PR, or the checkout moved), say so and ask with a short options list (e.g. "Session: PR #2107 (dependabot/…)", "Checkout: <branch> @ <sha>", "Last commit: <sha>", "Uncommitted changes", "Other").
   - If there is no session scope, or the only available scopes agree, do not ask: state the choice and carry on.
   - For a PR or branch the unit is the whole change set against its merge base (`git merge-base` with the PR base), not every commit.
   - If a PR is bound to the session, use `gh pr diff` or the fetched PR head, not the local HEAD, and do not touch the checkout (use `git show` / `git diff` on fetched refs, or a throwaway worktree).

2. **Get the target and verify live code**
   - Read the diff and the relevant surrounding code at the target ref. Keep the scope small enough for one good question.
   - Source of truth = the code at the target ref plus the diff (added, changed, and deleted lines). Commit messages, PR descriptions, docstrings, TODOs and comments about future work are context only. A question’s premise must never depend on them.
   - Before writing the question, verify its premises against the live code:
     - Find the real call sites of any function/class/flag the question relies on (grep the non-test code). Distinguish production call sites from test-only ones.
     - If the interesting mechanism is defined but not wired into any production path yet, either choose a different behaviour from the diff that is live, or ask about it explicitly as "this is not called in production yet; only tests call it: what does X do when Y?" Never phrase a scenario as if it already happens at runtime when it doesn’t.
     - Check config, feature flags, and dispatch conditions that decide whether the changed path runs.
   - Include removed and replaced code as question material. Good scenarios: "this branch used to do X before the change; what happens now for input Y, and what now covers the removed behaviour?" Look at deleted lines in the diff, not just added ones.
   - Any experiment that would confirm the question's premise or its expected outcome (a counterfactual such as removing a line, a scratch test, running the real spec with a change) must run BEFORE the question is shown. Run it in a throwaway worktree or scratch dir, never the user's checkout.
   - Write the question so what it asks for was actually established: a mechanism or value you verified, or an outcome you observed. If an outcome could not be verified, don't ask the user to predict it. Ask about the verified mechanism, or label the question as reasoning about a hazard, not a prediction.
   - Capture context for the log: repository (owner/repo), branch or PR number, commit SHA or PR ref (or "working tree" / "staged"), and the scope used.
   - Print one line stating the resolved target before the question (repo, PR number or branch, ref/SHA, scope used, number of files) so the user can correct it.

3. **Generate one scenario question**
   - Concrete situation that exercises the change (or the key live change in the PR/branch).
   - Prefer a question whose answer can be reasoned out from the diff and callers, with a concrete input/state, and where at least one plausible wrong answer follows from a common misconception.
   - Cheap to verify beats clever: if a 5-line script or an existing test can confirm the answer, run it before asking.
   - Asks what happens and why, not trivia, function names, or pure recall.
   - Open-book is fine; the point is whether the user can reason about the behaviour.
   - Keep it short.
   - Separate three kinds of claim in the question:
     - **Mechanism**: what the code does (verified by reading or running).
     - **Observed**: what happens in this codebase today (verified by running the real tests or code).
     - **Hazard**: what could go wrong under other orderings, inputs, or future changes (reasoned, not necessarily observed).
     State which kind each point is. Never present a hazard as observed, or an observed absence as proof the hazard is absent.
   - If the change has no live behavioural change (pure refactor, docs, renames, tests only), say so and either stop or ask a question about what the refactor preserves, clearly labelled.

4. **Ask and wait**
   - Present the question.
   - Ask for a confidence rating (1–5 or high/medium/low).
   - Wait for the answer. Do not give hints or the answer yet.

5. **Grade and reveal**
   - Grade the user's mental model and reasoning. A reasonable hazard claim stays credited even when today's code doesn't exercise it.
   - "No current test fails under the counterfactual" must be reported as "not exercised by current tests", never as "unnecessary", "harmless", or "defensive only".
   - If the user's guess about which current code is affected is contradicted by a run, say that specifically and still credit the underlying reasoning.
   - Do not let the reveal's experimental result override a sound design argument. Report both.
   - If the question mixed verified and unverified parts, say so in the reveal and own it.
   - Grade as understood / partial / missed (wording does not matter; mental model does).
   - Cite file:line for the deciding code at the target ref.
   - Say whether any claim comes from running something vs reading.
   - Separate the three kinds of claim in the reveal the same way as in the question.
   - If the question’s premise turned out wrong or only partly live (for example not yet wired up), say so plainly and own it rather than grading the user against a faulty premise.
   - Show the key lines that decide the outcome.
   - Give the correct reasoning in a few sentences.
   - Note whether confidence matched reality (especially confident-wrong cases).

6. **Log (default)**
   - Append a one-line entry to the global log at `~/.agents/viva-log.md` (create the directory and file if needed).
   - Prefer the schema from the platform: fetch https://adamsuk.github.io/viva/log-schemas.json and use the newest schema whose version matches this skill (currently 0.3.1). Fall back to the format below if the fetch fails.
   - Include the skill version from the frontmatter (currently 0.3.1) as the second field so the platform can dispatch.
   - Format (0.3.1): `YYYY-MM-DD HH:MM | skill-version | repo | branch-or-pr | commit-or-ref | short-topic | confidence | grade | scope | live`
   - Example: `2026-11-20 17:25 | 0.3.1 | adamsuk/viva-skills | pr-42 | a1b2c3d | skill logging path | 4 | understood | session | live`
   - `scope` is one of: session, checkout, last-commit, uncommitted, named.
   - `live` is one of: `live`, `partly-live` (for a question where the mechanism had no production call site, or its premise was corrected in the reveal), or `hazard` (for a question graded mainly on reasoning about a hazard the current code/tests don't exercise).
   - If the user says "no log" or "skip log", omit it.
   - Otherwise always log after grading.

## Rules

- One question only. If they want another (on the same PR/branch or a different change), ask.
- Soft and private by default. Do not post to PRs or shared surfaces unless explicitly asked.
- If the change is trivial or empty, say so and stop.
- Treat user and agent-generated code the same: the goal is the human's understanding.
- The log lives in the user's home under `.agents/` so a single file can be reviewed or moved later.

This skill implements the personal practice loop from the Viva research project. See https://github.com/adamsuk/viva for context, evidence labels, and the log schema.
