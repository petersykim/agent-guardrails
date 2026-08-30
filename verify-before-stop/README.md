# verify-before-stop.sh

A Claude Code Stop hook that won't let an agent end its turn on a bare claim of "done." Before the stop is allowed, it checks that a git diff exists against the files the task claimed to touch, that a named test command actually ran and exited 0, and that any file the task claims to have written is present on disk (optionally containing a required string). Any check fails, and the hook blocks the stop and hands back the specific unmet claim instead of a generic retry.

## Install

Uses `jq` to parse the hook payload when it's available and falls back to a plain grep parse when it isn't, so there is no hard dependency.

1. Copy `verify-before-stop.sh` into your hooks directory, for example `$HOME/.claude/hooks/verify-before-stop.sh`, and make it executable: `chmod +x verify-before-stop.sh`.
2. Wire it into the `Stop` event in your project or user `settings.json`:

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

3. Set the environment variables that define the current deliverable, either in the shell that launches Claude Code or in an `env` block in `settings.json`:

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

Every variable is optional and independent. Leave one unset to skip that check; leave all four unset and the hook always allows the stop.

## What to change

- `VERIFY_TEST_CMD`: point it at your own project's test runner, not a placeholder.
- `VERIFY_DIFF_PATHS`: list the files the current task is actually supposed to change.
- `VERIFY_DELIVERABLE_FILES` and `VERIFY_DELIVERABLE_GREP`: list the files the task is supposed to produce, and, if useful, a string that must appear inside them.
- The script only reads environment variables, the hook's own JSON payload, and the git working tree. It carries no private paths, tokens, or hostnames, so it runs unchanged in any repo where git and bash are available.
