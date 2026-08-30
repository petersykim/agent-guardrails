#!/usr/bin/env bash
# PreToolUse hook: blocks `git commit` unless a fresh, matching review artifact exists.
# See README.md for what each variable below means and how to point this at your own review step.
set -euo pipefail

REVIEW_ARTIFACT_PATH="${REVIEW_ARTIFACT_PATH:-.review-approved}"
REVIEW_MAX_AGE_SECONDS="${REVIEW_MAX_AGE_SECONDS:-1800}"
REVIEW_VERDICT_LINE="${REVIEW_VERDICT_LINE:-VERDICT=APPROVED}"
DOCS_ONLY_REGEX="${DOCS_ONLY_REGEX:-\.(md|txt|rst|adoc)$}"

input="$(cat)"

command=$(printf '%s' "$input" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed -E 's/.*"command"[[:space:]]*:[[:space:]]*"([^"]*)"/\1/')

if [[ -z "$command" ]]; then
  exit 0
fi

if ! printf '%s' "$command" | grep -Eq '(^|[;&|]|&&|\|\|)[[:space:]]*git[[:space:]]+commit'; then
  exit 0
fi

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root"

staged_files=$(git diff --cached --name-only)
if [[ -z "$staged_files" ]]; then
  exit 0
fi

if ! printf '%s\n' "$staged_files" | grep -Evq "$DOCS_ONLY_REGEX"; then
  exit 0
fi

artifact="$REVIEW_ARTIFACT_PATH"
[[ "$artifact" = /* ]] || artifact="$repo_root/$artifact"

fail() {
  echo "commit blocked: $1" >&2
  echo "expected a fresh review artifact at $artifact" >&2
  echo "run your review step (see README.md), then commit again" >&2
  exit 2
}

[[ -f "$artifact" ]] || fail "no review artifact found"

mtime=$(stat -f %m "$artifact" 2>/dev/null || stat -c %Y "$artifact" 2>/dev/null) || fail "could not read artifact timestamp"
now=$(date +%s)
age=$(( now - mtime ))
(( age <= REVIEW_MAX_AGE_SECONDS )) || fail "review artifact is $age seconds old, older than REVIEW_MAX_AGE_SECONDS=$REVIEW_MAX_AGE_SECONDS"

grep -qF "$REVIEW_VERDICT_LINE" "$artifact" || fail "artifact missing required line: $REVIEW_VERDICT_LINE"

current_tree=$(git write-tree)
artifact_tree=$(grep -E '^TREE=' "$artifact" | head -n1 | cut -d= -f2-)
[[ -n "$artifact_tree" ]] || fail "artifact missing TREE= line"
[[ "$artifact_tree" == "$current_tree" ]] || fail "artifact was written for a different tree than what is staged now"

exit 0
