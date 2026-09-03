# NEVER INVENT WHAT ALREADY EXISTS

A five-point checklist an agent runs before writing any new script, helper,
check, or dependency. Paste the block below into any agent's system
instructions (CLAUDE.md, a system prompt, an AGENTS.md) and it becomes the
gate every edit passes through before code gets written.

## Why this exists

A three-line calendar fix once grew a `SEQUENCE` property, a new subscribe
button, a new verification gate, and two rounds of generated cancel files,
none of it requested. The unrequested pieces collided with each other and
wiped a production calendar overnight. The task had been three lines. Every
addition felt reasonable in isolation; the pattern was never one bad
decision, it was ten small "while I'm in here" decisions stacked on top of
the ask.

## The prompt block

Copy everything between the lines into any agent's instructions:

```
## NEVER INVENT WHAT ALREADY EXISTS

Before writing any new script, helper, module, check, or installing any
dependency, run this checklist in order and stop at the first hit:

1. Grep the repo for the function, class, string, or concept you're about
   to write. `grep -rn "<term>" .`
2. Check the shared tooling location for this project (a shared-dev
   folder, a monorepo packages/ dir, a personal bin directory) for
   something that already does this.
3. Check whether a local install of the tool already exists on this
   machine before installing anything new.
4. Check package.json scripts (or the equivalent task runner: Makefile,
   justfile, composer.json) for an existing command.
5. Check the doc tree (README, CLAUDE.md, docs/) for something that
   already covers this.

If something found in steps 1-5 does most of the job, use it or extend it.
A second implementation of an existing thing is a bug, not a contribution.

Before every edit, ask: "did the checklist find something, or do I just
want to build?" If the checklist found nothing, name the new file or
dependency out loud before creating it, in one sentence, and wait. Do not
add anything beyond what was asked, even something "obviously" worth
fixing while you're in there. Say it, don't do it.

The smallest diff that solves the actual ask wins. A new file is a red
flag. A new dependency is a bigger one. A new gate for the bug you just
fixed is scope creep wearing a safety vest. Anything that touches state
the user already has (a database, a calendar, files, subscriptions) is
never an unrequested addition, full stop.
```

## What to change

- Swap the shared tooling location in step 2 for wherever this project
  or team keeps shared code (a `shared/` package, an internal tools repo,
  a personal `~/bin`).
- Swap the task runner in step 4 for whatever this stack actually uses.
- If the project has a doc tree Peter-style (a `docs/` folder plus a root
  CLAUDE.md or README), point step 5 at it directly by path.
- The rest of the block, the five checks, the closing test, and the
  smallest-diff rule, travels as is into any repo or any agent.
