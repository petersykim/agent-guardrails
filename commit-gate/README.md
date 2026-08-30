# block-unreviewed-commit.sh

An agent reviewing its own work will approve its own shortcuts, including the comment explaining why the shortcut was fine. This hook blocks `git commit` until a review artifact exists that is fresh, carries an approval line, and matches the tree currently staged for commit. The review artifact can come from anything: a second model pass, a CI check, or a human sign-off file. Docs-only diffs (matched by an extension pattern) skip the gate.

## Install

1. Copy both scripts into your hooks directory and make them executable:
   ```bash
   cp block-unreviewed-commit.sh record-review-approval.sh /path/to/your/hooks/
   chmod +x /path/to/your/hooks/block-unreviewed-commit.sh /path/to/your/hooks/record-review-approval.sh
   ```
2. Wire `block-unreviewed-commit.sh` into your agent's `PreToolUse` hooks with a matcher on the `Bash` tool. In Claude Code's `settings.json`:
   ```json
   "PreToolUse": [
     {
       "matcher": "Bash",
       "hooks": [
         { "type": "command", "command": "/path/to/your/hooks/block-unreviewed-commit.sh" }
       ]
     }
   ]
   ```
3. Have your review step call `record-review-approval.sh` once it approves the staged changes, before the commit runs. This could be the last step of a CI job, a second model invocation, or a person running it by hand after reading the diff.
4. Try a commit without running the review step first. It should be blocked with a message explaining why. Run `record-review-approval.sh`, then commit again. It should go through.

## What to change

- `REVIEW_ARTIFACT_PATH` (default `.review-approved`, relative to the repo root): where the review artifact lives. Point it at wherever your review step already writes its output, or leave the default and have your review step write there.
- `REVIEW_MAX_AGE_SECONDS` (default `1800`): how old a review artifact can be before it counts as stale. Lower this if your reviews and commits should happen close together.
- `REVIEW_VERDICT_LINE` (default `VERDICT=APPROVED`): the exact line that must appear in the artifact for it to count as an approval. Change it if your review step wants a different verdict, or to encode different verdict levels.
- `DOCS_ONLY_REGEX` (default matches `.md`, `.txt`, `.rst`, `.adoc`): file extensions that are exempt from the gate. Widen or narrow it to match what your project treats as prose.

Set any of these as environment variables before the hook runs, or edit the defaults directly at the top of each script.

## How it works

`record-review-approval.sh` writes a small text file recording the hash of the tree it reviewed (`git write-tree`), the verdict line, and a timestamp. `block-unreviewed-commit.sh` runs before every `git commit`, computes the hash of what is staged right now, and refuses the commit unless the artifact exists, is younger than the age limit, contains the required verdict line, and was written for the exact tree being committed. Stage one more file after the review runs and the hash no longer matches, so the gate blocks again until review runs on the new diff.

## The failure this prevents

A shortcut with a comment next to it explaining why the shortcut was fine, where the explanation is wrong and nobody independent checked it. An agent reviewing its own diff has no way to catch that, because the same reasoning that produced the shortcut also produced the comment defending it.

MIT.
