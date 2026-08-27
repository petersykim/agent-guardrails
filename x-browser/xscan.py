"""Scan X search results through Peter's cloned Chrome over raw CDP. Costs $0.

Reads are the expensive side of the X API ($0.005 per post, $0.010 per user;
2026-08-25 cost ~$50). This does the reading in the logged-in browser instead,
the same way Peter would scroll on his phone. Writes still go through
~/.claude/bin/xapi.py.

Usage: python3 xscan.py "<query>" [--port 9224] [--scrolls 6] [--out file.json]
Emits JSON: [{id, url, handle, name, text, replies, reposts, likes, views, ts}]
"""
import argparse, json, sys, time, urllib.parse, urllib.request
from websocket import create_connection

EXTRACT_JS = r"""
(() => {
  const num = s => {
    if (!s) return 0;
    s = s.replace(/,/g, '');
    const m = s.match(/([\d.]+)\s*([KM]?)/i);
    if (!m) return 0;
    let n = parseFloat(m[1]);
    if (/k/i.test(m[2])) n *= 1e3;
    if (/m/i.test(m[2])) n *= 1e6;
    return Math.round(n);
  };
  const out = [];
  for (const a of document.querySelectorAll('article[data-testid="tweet"]')) {
    const link = a.querySelector('a[href*="/status/"]');
    if (!link) continue;
    const url = link.href.split('?')[0];
    const id = url.split('/status/')[1];
    if (!id) continue;
    const handle = (url.match(/x\.com\/([^/]+)\/status/) || [])[1] || '';
    const nameEl = a.querySelector('[data-testid="User-Name"]');
    const name = nameEl ? nameEl.innerText.split('\n')[0] : '';
    const textEl = a.querySelector('[data-testid="tweetText"]');
    const text = textEl ? textEl.innerText : '';
    const t = a.querySelector('time');
    const ts = t ? t.getAttribute('datetime') : '';
    const count = tid => {
      const el = a.querySelector(`[data-testid="${tid}"]`);
      return el ? num(el.getAttribute('aria-label') || el.innerText) : 0;
    };
    const viewsEl = a.querySelector('a[href$="/analytics"]');
    const views = viewsEl ? num(viewsEl.getAttribute('aria-label') || viewsEl.innerText) : 0;
    out.push({id, url, handle, name, text, ts,
              replies: count('reply'), reposts: count('retweet'),
              likes: count('like'), views});
  }
  return JSON.stringify(out);
})()
"""


BLOCKED_JS = r"""
(() => {
  if (document.querySelectorAll('article[data-testid="tweet"]').length) return '';
  const t = document.body.innerText;
  if (/No results for/.test(t)) return '';
  if (/Log in|Sign in|Sign up/.test(t) && /password/i.test(t)) return 'login wall';
  if (/Something went wrong|Try again|rate limit/i.test(t)) return 'error page';
  return 'selector drift or page not rendered: ' + t.slice(0, 120).replace(/\s+/g, ' ');
})()
"""


class Tab:
    def __init__(self, port):
        self.port = port
        info = json.load(urllib.request.urlopen(
            urllib.request.Request(f'http://127.0.0.1:{port}/json/new?about:blank',
                                   method='PUT')))
        self.id = info['id']
        self.seq = 0
        try:
            self.ws = create_connection(info['webSocketDebuggerUrl'], timeout=60,
                                        origin=f'http://localhost:{port}')
        except Exception:
            self._close_rest()
            raise

    def call(self, method, **params):
        self.seq += 1
        self.ws.send(json.dumps({'id': self.seq, 'method': method, 'params': params}))
        while True:
            m = json.loads(self.ws.recv())
            if m.get('id') == self.seq:
                return m.get('result', {})

    def eval(self, js):
        r = self.call('Runtime.evaluate', expression=js, returnByValue=True)
        return r.get('result', {}).get('value')

    def _close_rest(self):
        try:
            urllib.request.urlopen(f'http://127.0.0.1:{self.port}/json/close/{self.id}')
        except Exception:
            pass

    def close(self):
        try:
            self.ws.close()
        except Exception:
            pass
        self._close_rest()


def unwedge(tab):
    """X's app shell can stick on its splash screen with every request 200
    (seen 2026-08-26 after ~70 searches): the service worker is wedged.
    Unregister it, drop the cache, reload once. Returns the fresh extract."""
    tab.call('Runtime.evaluate', awaitPromise=True, returnByValue=True,
             expression='navigator.serviceWorker.getRegistrations()'
                        '.then(rs => Promise.all(rs.map(r => r.unregister())))')
    tab.call('Network.enable')
    tab.call('Network.clearBrowserCache')
    tab.call('Page.reload', ignoreCache=True)
    time.sleep(12)
    print('xscan: unwedged X service worker and reloaded', file=sys.stderr)
    return tab.eval(EXTRACT_JS) or '[]'


def scan(query, port=9224, scrolls=6, pause=2.5):
    url = 'https://x.com/search?f=live&q=' + urllib.parse.quote(query)
    tab = Tab(port)
    seen = {}
    try:
        tab.call('Page.navigate', url=url)
        time.sleep(5)
        for i in range(scrolls):
            raw = tab.eval(EXTRACT_JS)
            if raw is None:
                raise RuntimeError('extract script failed to evaluate (page not ready or JS error)')
            if i == 0 and raw == '[]':
                # A slow render looks like drift. Give the page up to 20 more
                # seconds before deciding it is blocked.
                for _ in range(4):
                    time.sleep(5)
                    raw = tab.eval(EXTRACT_JS) or '[]'
                    if raw != '[]' or tab.eval(BLOCKED_JS) == '':
                        break
                else:
                    raw = unwedge(tab)
                    if raw == '[]' and tab.eval(BLOCKED_JS) != '':
                        raise RuntimeError(f'no posts and no "No results" text: {tab.eval(BLOCKED_JS)}')
            for p in json.loads(raw):
                seen.setdefault(p['id'], p)
            tab.eval('window.scrollBy(0, document.documentElement.clientHeight * 2)')
            time.sleep(pause)
    finally:
        tab.close()
    return list(seen.values())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('query')
    ap.add_argument('--port', type=int, default=9224)
    ap.add_argument('--scrolls', type=int, default=6)
    ap.add_argument('--out')
    a = ap.parse_args()
    posts = scan(a.query, a.port, a.scrolls)
    data = json.dumps(posts, indent=1, ensure_ascii=False)
    if a.out:
        open(a.out, 'w').write(data)
    print(f'{len(posts)} posts', file=sys.stderr)
    if not a.out:
        print(data)


if __name__ == '__main__':
    main()
