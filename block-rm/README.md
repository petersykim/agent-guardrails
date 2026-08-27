# block-rm.sh

**Your coding agent can delete your files. This hook makes it physically unable to.**

A PreToolUse hook for Claude Code. It reads every Bash command before it runs,
and any delete targeting something outside a tmp directory gets blocked and
sent to `trash` instead, where it is recoverable.

Telling an agent not to delete things is a rule it can talk itself out of under
pressure. This one it cannot.

## Install

```bash
brew install trash                      # or your system's recoverable-delete tool
cp block-rm.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/block-rm.sh
```

Merge `settings.snippet.json` into `~/.claude/settings.json` under the `hooks`
key. If you already have a `PreToolUse` Bash matcher, add this command into it
rather than duplicating the matcher block. Restart your session.

About five minutes end to end.

## What it catches

| Form | Example |
|---|---|
| The plain one, outside tmp | `rm -rf build/` |
| find, doing the same job | `find . -name '*.log' -delete` |
| Hidden behind a harmless first command | `ls -la && rm important.txt` |
| Inside a quoted remote call | `ssh host 'rm -rf /var/www'` |

Passes straight through: `docker rm`, `docker rmi`, and anything under `/tmp`,
`/private/tmp`, `/var/folders`, or `$TMPDIR`.

Fails open on a parse error, deliberately. Missing an edge case is cheaper than
blocking legitimate work.

## What to change

The script path in `settings.snippet.json`, to wherever you put it. If your OS
has no `trash`, swap the message text and the tool it points at for whatever
recoverable delete you use.

MIT.
