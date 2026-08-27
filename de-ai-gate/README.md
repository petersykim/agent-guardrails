# _gates.mjs

**Asking a model to stop using em dashes does not work. This does.**

One JavaScript file, no dependencies. It catches the tells of machine prose
mechanically, before a draft ever reaches a human for review.

## The three gates

**`deAiViolations(text)`** flags the punctuation nobody types by hand: em
dashes, arrows, smart quotes, the ellipsis character, emoji, hashtags. Each is
a plain regex. A hashtag has to start with a letter, so `#1` in ordinary copy
still passes.

**`groundingViolations(text, allowed)`** takes a set of numbers you have
actually verified and refuses any figure in the draft that is not among them.
Numbers under 10 are ignored as ordinary prose. This is what stops an invented
statistic from reaching a reader.

**`momentViolations(text)`** catches the explaining reflex, which is the
subtler tell: "which means", "turns out", a final sentence hanging off
"because", and the "not A, it is B" reversal that model output reaches for by
default.

## Install

```bash
cp _gates.mjs your-project/
node --test _gates.test.mjs     # the tests ship with it
```

```js
import { deAiViolations, groundingViolations } from './_gates.mjs';

const problems = [
  ...deAiViolations(draft),
  ...groundingViolations(draft, myVerifiedNumbers),
];
if (problems.length) reject(problems);
```

## Why regex and not a model

Every check here runs on a string. Nothing asks the model to grade its own
homework, because a check the writer can reason its way past is not a check.

## What to change

The `BANNED` array, to match the tells you care about. The number allowlist,
to point at your own source of truth. No paths, no secrets, nothing
site-specific in the file.

MIT.
