# verify-before-stop.sh

A Claude Code Stop-hook that will not let an agent end its turn on a bare claim of "done." Before the session is allowed to close, it checks that a diff actually exists against the files the task claimed to touch, that a named test command actually ran and exited 0, and that any file the task claimed to write is actually present on disk with the expected content. If any check fails, the hook blocks the stop and hands the agent back the specific claim that was not verified, instead of a generic retry.

## Install

1. Copy `verify-before-stop.sh` into your hooks directory, for example `$HOME/.claude/hooks/verify-before-stop.sh`, and make it executable: `chmod +x verify-before-stop.sh`.
2. In your project or user `settings.json`, wire it into the `Stop` event:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/verify-before-stop.sh"
          }
        ]
      }
    ]
  }
}
```

3. Set the environment variables that define your deliverable, either in the shell that launches Claude Code or in an `env` block in `settings.json`:

```json
{
  "env": {
    "VERIFY_TEST_CMD": "npm test",
    "VERIFY_DIFF_PATHS": "src/app.ts src/app.test.ts",
    "VERIFY_DELIVERABLE_FILES": "dist/app.js",
    "VERIFY_DELIVERABLE_GREP": "export function run"
  }
}
```

Every variable is optional and independent. Leave a variable unset to skip that check entirely; leave all four unset and the hook always allows the stop.

## What to change

- `VERIFY_TEST_CMD`: point it at your own project's test runner, not a placeholder.
- `VERIFY_DIFF_PATHS`: list the files the current task is actually supposed to change.
- `VERIFY_DELIVERABLE_FILES` and `VERIFY_DELIVERABLE_GREP`: list the files the task is supposed to produce, and, if useful, a string that must appear inside them.
- The script only reads environment variables and the git working tree, so it has no private paths, tokens, or hostnames to scrub. It runs anywhere a git repo and bash are available.
