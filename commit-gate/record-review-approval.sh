#!/usr/bin/env bash
# Call this from your review step once it approves the currently staged changes:
# a CI job, a second model pass, or a person running it by hand after reading the diff.
# Writes the artifact that block-unreviewed-commit.sh checks for before allowing a commit.
set -euo pipefail

REVIEW_ARTIFACT_PATH="${REVIEW_ARTIFACT_PATH:-.review-approved}"
REVIEW_VERDICT_LINE="${REVIEW_VERDICT_LINE:-VERDICT=APPROVED}"

repo_root=$(git rev-parse --show-toplevel)
artifact="$REVIEW_ARTIFACT_PATH"
[[ "$artifact" = /* ]] || artifact="$repo_root/$artifact"

tree=$(cd "$repo_root" && git write-tree)

{
  echo "TREE=$tree"
  echo "$REVIEW_VERDICT_LINE"
  echo "REVIEWED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$artifact"

echo "wrote review artifact for tree $tree to $artifact"
