#!/usr/bin/env bash
# block-unreviewed-commit.sh — PreToolUse(Bash) HARD interlock. (Fable, 2026-08-10,
# Peter's order after the chrome betrayal + six-hunter audit: no diff of mine or any
# spawn's ever lands on the author's word again.)
#
# Blocks `git commit` in any repo under ~/projects unless a FRESH review receipt
# exists whose staged-diff hash matches the diff being committed. The receipt can
# only be produced by review-receipt.sh, which requires an independent reviewer
# report (the crime-list hunt, reference/code-review-crime-list.md) with an explicit
# VERDICT: PASS over that exact diff. An author cannot fake the receipt without a
# report file; the report file itself is visible in the transcript.
#
# Exit 0 = allow. Exit 2 = block (stderr shown to the model, routed via quiet-hook).
# Fail-open on parse errors — better to miss than to block legit work on a hook bug.
set -uo pipefail

STATE="$HOME/.claude/orchestrator/state"
RECEIPT_MAX_AGE=1800   # 30 min — a stale review is no review

payload="$(cat 2>/dev/null || true)"
CMD="$(printf '%s' "$payload" | python3 -c '
import sys,json
try:
    d=json.load(sys.stdin)
    if (d.get("tool_name") or "") != "Bash": print(""); raise SystemExit
    print(d.get("tool_input",{}).get("command",""))
except Exception:
    print("")' 2>/dev/null || true)"
[ -z "$CMD" ] && exit 0

# Only fire on actual git commit invocations (not grep/echo/heredoc text mentioning
# them). Strip heredoc bodies first — document content piped through a heredoc must
# not trip the gate (false positive caught live 2026-08-10, first night).
CMD_CODE="$(printf '%s' "$CMD" | python3 -c '
import sys,re
t=sys.stdin.read()
t=re.sub(r"<<-?\x27?\"?(\w+)\x27?\"?.*?\n\1\b", "", t, flags=re.S)
print(t)' 2>/dev/null || printf '%s' "$CMD")"
IS_COMMIT=0; IS_MERGE=0
printf '%s' "$CMD_CODE" | grep -qE '(^|[;&|]|&&|\|\|)[[:space:]]*git([[:space:]]+-C[[:space:]]+[^ ]+)?[[:space:]]+commit\b' && IS_COMMIT=1
# Merge-class commands can land unreviewed wip/* work on main without ever
# saying "git commit" — catch them too (wip exemption below still applies).
# `git merge --squash` is allowed: it only stages the diff, and the commit
# that follows goes through the normal receipt path.
# `--ff-only` pull/merge is allowed (2026-08-14): a fast-forward can only move
# the branch to commits that ALREADY exist on the remote, which got there
# through this same gate — it cannot land unreviewed local work. Blocking it
# forced a deploy-side update-ref bypass that left the live worktree stale
# (the founding incident, same day).
if printf '%s' "$CMD_CODE" | grep -qE '(^|[;&|]|&&|\|\|)[[:space:]]*git([[:space:]]+-C[[:space:]]+[^ ]+)?[[:space:]]+(merge|cherry-pick|rebase|pull)\b' \
   && ! printf '%s' "$CMD_CODE" | grep -qE 'merge[^;&|]*--squash' \
   && ! printf '%s' "$CMD_CODE" | grep -qE 'pull[^;&|]*--ff-only' \
   && ! printf '%s' "$CMD_CODE" | grep -qE 'merge[^;&|]*--ff-only[^;&|]*\borigin/'; then
  IS_MERGE=1
fi
[ "$IS_COMMIT" -eq 0 ] && [ "$IS_MERGE" -eq 0 ] && exit 0

# Resolve the repo the commit targets: -C path wins, then a leading/compound
# `cd <path> && ... git commit` (found live 2026-08-20: an agent in job-hunter
# ran `cd /private/tmp/<worktree> && git commit`; the gate hashed job-hunter's
# EMPTY tree, matched an empty-tree receipt, and waved the real diff through),
# else cwd from payload, else $PWD.
REPO_DIR="$(printf '%s' "$CMD" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^ ]+)[[:space:]]+commit.*/\1/p' | head -1)"
if [ -z "$REPO_DIR" ]; then
  REPO_DIR="$(printf '%s' "$CMD" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^ ;&|]+).*git[[:space:]]+commit.*/\1/p' | head -1)"
fi
if [ -z "$REPO_DIR" ]; then
  REPO_DIR="$(printf '%s' "$payload" | python3 -c '
import sys,json
try: print(json.load(sys.stdin).get("cwd") or "")
except Exception: print("")' 2>/dev/null || true)"
fi
[ -z "$REPO_DIR" ] && REPO_DIR="$PWD"
REPO_DIR="${REPO_DIR/#\~/$HOME}"

# Scope: only Peter's project repos (and the orchestrator itself is exempt —
# guardrail plumbing must stay repairable; Peter's repos are the protected asset).
TOP="$(git -C "$REPO_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$TOP" ] && exit 0
# Worktrees escape a path check on TOP alone (/tmp worktrees of ~/projects
# repos committed unreviewed, found live 2026-08-19). The git COMMON dir
# always lives in the main repo — scope on it too, so every worktree of a
# protected repo is protected no matter where it sits on disk.
COMMON="$(git -C "$REPO_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
case "$TOP:$COMMON" in
  "$HOME"/projects/*|*":$HOME"/projects/*) : ;;
  *) exit 0 ;;
esac

REPO_NAME="$(basename "$(dirname "${COMMON:-$TOP/.git}")")"
RECEIPT="$STATE/REVIEW-RECEIPT.$REPO_NAME"

# WIP-BRANCH EXEMPTION (Peter, 2026-08-13: "always spawn asking for tight
# commits — otherwise on a long spawning session a disruption loses all work").
# Commits on a branch named wip/* or agent/* need no receipt: they are the
# durability mechanism for long builds. The review law is intact because
# landing that work on main/master (merge or direct commit) still produces a
# commit THERE, and this gate demands a fresh matching receipt for it.
CUR_BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
# Mid-rebase HEAD is detached ("HEAD"), which defeated the exemption for a
# wip/* branch being rebased (found 2026-08-17: builder couldn't even
# --continue/--abort). Git records the real branch across the whole rebase
# in rebase-merge/head-name (or rebase-apply/head-name) — use it as the
# fallback so the exemption follows the branch, not the detached state.
if [ "$CUR_BRANCH" = "HEAD" ]; then
  GDIR="$(git -C "$REPO_DIR" rev-parse --git-dir 2>/dev/null || true)"
  for RB in rebase-merge rebase-apply; do
    if [ -n "$GDIR" ] && [ -f "$GDIR/$RB/head-name" ]; then
      CUR_BRANCH="$(sed 's|^refs/heads/||' "$GDIR/$RB/head-name")"
      break
    fi
  done
fi
case "$CUR_BRANCH" in
  wip/*|agent/*) exit 0 ;;
esac

# Merge-class command on a protected branch: the only sanctioned route for
# landing wip work is squash -> review -> receipted commit.
if [ "$IS_MERGE" -eq 1 ]; then
  echo "BLOCKED: git merge/cherry-pick/rebase/pull onto '$CUR_BRANCH' would land commits without a review receipt." >&2
  echo "Sanctioned route: git merge --squash <wip-branch>  (stages the diff, no commit)," >&2
  echo "then independent crime-list review + review-receipt.sh, then git commit as normal." >&2
  exit 2
fi

# DOCS EXEMPTION (Peter, 2026-08-11: "documentation should be exceptions to
# review"). A commit whose staged files are ALL documentation (.md anywhere,
# or anything under docs/) needs no review receipt. One code file in the
# diff and the full gate applies.
STAGED_FILES="$(git -C "$TOP" diff --cached --name-only)"
if [ -n "$STAGED_FILES" ]; then
  DOCS_ONLY=1
  while IFS= read -r f; do
    case "$f" in
      *.md|docs/*|*/docs/*) : ;;
      *) DOCS_ONLY=0; break ;;
    esac
  done <<EOF_FILES
$STAGED_FILES
EOF_FILES
  [ "$DOCS_ONLY" -eq 1 ] && exit 0
fi

# Hash of the exact diff about to be committed (staged; falls back to worktree for -a).
STAGED_HASH="$(git -C "$TOP" diff --cached | shasum -a 256 | awk '{print $1}')"
WORKTREE_HASH="$(git -C "$TOP" diff HEAD | shasum -a 256 | awk '{print $1}')"

fail() {
  echo "BLOCKED: git commit in $REPO_NAME without a fresh matching review receipt." >&2
  echo "$1" >&2
  echo "" >&2
  echo "DOCS ARE EXEMPT. If every staged file is *.md or under docs/, this gate" >&2
  echo "does NOT fire and NO review is needed. These staged files are what made" >&2
  echo "the gate apply — if any is incidental, unstage it and commit the docs alone:" >&2
  git -C "$TOP" diff --cached --name-only | while IFS= read -r f; do
    case "$f" in
      *.md|docs/*|*/docs/*) : ;;
      *) echo "    $f" >&2 ;;
    esac
  done
  echo "" >&2
  echo "Otherwise: run the independent crime-list review" >&2
  echo "(reference/code-review-crime-list.md) on the staged diff, save the" >&2
  echo "reviewer's report with 'VERDICT: PASS', then:" >&2
  echo "  bash ~/.claude/orchestrator/scripts/review-receipt.sh $REPO_NAME <report-file>" >&2
  exit 2
}

[ -f "$RECEIPT" ] || fail "No receipt at $RECEIPT."

AGE=$(( $(date +%s) - $(stat -f %m "$RECEIPT" 2>/dev/null || echo 0) ))
[ "$AGE" -le "$RECEIPT_MAX_AGE" ] || fail "Receipt is ${AGE}s old (max ${RECEIPT_MAX_AGE}s). Re-review the current diff."

RECEIPT_STAGED="$(sed -n 's/^diff_sha256=//p' "$RECEIPT" | head -1)"
RECEIPT_WORKTREE="$(sed -n 's/^worktree_sha256=//p' "$RECEIPT" | head -1)"
if [ "$RECEIPT_STAGED" != "$STAGED_HASH" ] && [ "$RECEIPT_WORKTREE" != "$WORKTREE_HASH" ]; then
  fail "Receipt hash does not match the diff being committed — the diff changed after review."
fi

# Receipt is single-use: consumed on a successful pass so the next commit needs its own review.
rm -f "$RECEIPT" 2>/dev/null || true
exit 0
