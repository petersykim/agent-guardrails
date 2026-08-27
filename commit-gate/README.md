# block-unreviewed-commit.sh

**An agent reviewing its own work will approve its own shortcuts, comment and all.**

A PreToolUse hook that blocks `git commit` until an independent review has
actually run against the diff you are committing. Not a review the same agent
claims it did. A receipt, matched to the staged content.

## Install

```bash
cp block-unreviewed-commit.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/block-unreviewed-commit.sh
```

Wire it into `PreToolUse` with a Bash matcher, alongside your other guards.

## How it works

The reviewer writes a receipt naming the exact staged tree it looked at. When a
commit is attempted, the hook compares the receipt against what is actually
staged. Stale receipt, missing receipt, or a diff that moved since the review
means the commit does not happen.

Docs-only diffs pass automatically. Prose does not need a code review, and
gating it just teaches people to bypass the gate.

## What to change

The receipt path and the repo root at the top of the script. The docs-only
detection, if your layout differs.

## The failure it prevents

A shortcut with a comment next to it explaining why the shortcut was necessary,
where the explanation is false and nobody checked. Self-review cannot catch
that, because the same reasoning that produced the shortcut produced the
comment.

MIT.
