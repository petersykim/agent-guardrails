# agent-guardrails

Working files that make a coding agent physically unable to do the things you
keep asking it not to do.

A rule in a prompt is a suggestion the model can reason its way past under
pressure. Every file here is a hook or a gate instead: it runs outside the
model, on the tool call or the commit, and it does not negotiate.

All of it is in daily use. Take any of it.

| | What it does |
|---|---|
| [block-rm](block-rm/) | Blocks deletes outside tmp and routes them to trash. Catches `find -delete`, chained commands, and quoted remote calls. |
| [de-ai-gate](de-ai-gate/) | Regex gates that catch em dashes, smart quotes, invented numbers, and the machine explaining reflex before a draft reaches a human. |
| [commit-gate](commit-gate/) | Blocks `git commit` until an independent review has run against the actual staged diff. Docs-only changes pass. |
| [session-letter](session-letter/) | A template an agent fills in before its context clears, for whoever wakes up next. |
| [x-browser](x-browser/) | Reads X through your own logged-in Chrome over the DevTools protocol instead of paying per API call. |

Each folder has its own README with install steps and what to change.

Most of these are for Claude Code's PreToolUse hooks, but the pattern moves to
any agent runtime that lets something run before a tool call.

MIT.
