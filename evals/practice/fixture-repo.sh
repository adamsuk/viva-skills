#!/usr/bin/env bash
# The shared fixture, reshaped so the retry arrived as a merged PR: main is the first commit plus a
# merge commit that brings in feature/retry (PR #7 in the stub gh).
set -euo pipefail
bash "$(dirname "$0")/../fixture-repo.sh" "$1"
cd "$1"
git branch feature/retry
git reset -q --hard HEAD~1
git merge -q --no-ff -m "Merge pull request #7 from eval-user/feature/retry" feature/retry
