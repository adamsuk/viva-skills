#!/usr/bin/env bash
# Builds a small git repo in $1 whose last commit adds a bounded retry, for the scenarios to ask about.
set -euo pipefail
cd "$1"
git init -q -b main .
git config user.name "Eval User"; git config user.email eval@example.invalid
cat > fetch.py <<'PY'
import time

def fetch(url, get):
    return get(url)
PY
git add . && git commit -qm "fetch: first version"
cat > fetch.py <<'PY'
import time

MAX_ATTEMPTS = 3


def fetch(url, get, sleep=time.sleep):
    """Call get(url), retrying on TimeoutError up to MAX_ATTEMPTS times in total."""
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            return get(url)
        except TimeoutError:
            if attempt == MAX_ATTEMPTS:
                raise
            sleep(0.5 * 2 ** (attempt - 1))
PY
git add . && git commit -qm "fetch: retry timeouts with backoff, at most 3 attempts"
