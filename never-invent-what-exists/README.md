# never-invent-what-exists

A checklist file that stops a coding agent from turning a small fix into a
pile of unrequested new code. Before writing any script, helper, check, or
dependency, the agent runs five lookups (grep the repo, check shared
tooling, check for an existing local install, check the task runner's
scripts, check the doc tree) and only builds new if all five come up
empty. It exists because a three-line calendar fix once grew a new
property, a new button, a new gate, and generated files that collided and
wiped a production calendar in one night, none of it requested.

## Install

1. Open `never-invent-what-exists.md` and copy the block between the two
   fenced lines (starts at `## NEVER INVENT WHAT ALREADY EXISTS`, ends
   after the "safety vest" line).
2. Paste it into your agent's system instructions file: `CLAUDE.md`,
   `AGENTS.md`, a system prompt, wherever your agent reads standing rules
   from.
3. Replace the two placeholders described in "What to change" below with
   your project's real locations.
4. Save. The next time the agent is about to write a new file or install
   a dependency, the checklist runs first.

## What to change

- Step 2's shared tooling location: point it at wherever your team keeps
  reusable code so the agent checks there before writing something new.
- Step 4's task runner: swap `package.json` scripts for whatever your
  stack uses (Makefile, justfile, composer.json, Rakefile).
- Step 5 can point directly at a docs folder path if you have one.

Everything else, the grep-first order, the "found something or just want
to build" question, and the smallest-diff rule, works unchanged in any
repo.
