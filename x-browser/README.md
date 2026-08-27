# xscan.py and xlike.py

**Reading X through the API costs money per call. Your own browser is already logged in and reads it free.**

Two Python scripts that drive Chrome over the DevTools Protocol instead of
hitting the API. `xscan.py` scrolls a search or profile page and pulls the
posts out of the DOM. `xlike.py` clicks like on a post.

No API key, no per-read billing, no rate-limit ceiling beyond what a person
scrolling would hit.

## Install

```bash
pip install websocket-client
```

Start Chrome with a debug port open, using a copy of your real profile so the
session is already authenticated:

```bash
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug
```

Then:

```bash
python3 xscan.py "https://x.com/search?q=your+query" --limit 40
python3 xlike.py https://x.com/someone/status/123456
```

## Why the browser and not the API

The API charges per read and returns a subset of what the page shows. The
browser sees exactly what a person sees, including the posts the API omits, and
the cost is zero. For reads this is strictly better. For writes the API is
still the right tool, and these scripts do not write.

## What to change

`PORT` at the top of each file if you use a different debug port. The selectors
are standard X test IDs and have been stable, but they are the part that will
break first if the site changes.

Read-only by design. `xlike.py` is the one action it takes, and it takes it on
one post you name explicitly.

MIT.
