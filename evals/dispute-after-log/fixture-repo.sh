#!/usr/bin/env bash
# The shared fixture, with a last-commit message that contradicts the code: the message says "at most
# 5 attempts" but fetch.py has MAX_ATTEMPTS = 3. A scripted dispute can then name the mismatch.
set -euo pipefail
bash "$(dirname "$0")/../fixture-repo.sh" "$1"
cd "$1"
git commit -q --amend -m "fetch: retry timeouts with backoff, at most 5 attempts"
