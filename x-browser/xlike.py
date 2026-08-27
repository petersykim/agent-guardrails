"""Like posts through Peter's browser. Costs $0.

A like is the handshake: it lands in the author's notifications before any
reply does, and there is almost nothing to lose. Every post we reply to is
liked FIRST; the judge also marks a lower-bar "like only" bucket.

Usage: python3 xlike.py url1 url2 ... [--port 9224] [--space 20 60]
Records every like in docs/x-research/LIKED.json {id: {handle, url, at}} and
never likes the same post twice.
"""
import argparse, json, os, random, sys, time
from xscan import Tab

HERE = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.normpath(os.path.join(HERE, '..', '..', 'docs', 'x-research'))
LIKED = os.path.join(DOCS, 'LIKED.json')
LIKE_BTN = '[data-testid="like"]'
UNLIKE_BTN = '[data-testid="unlike"]'


def focal_js(pid, selector):
    """JS returning the element matching `selector` INSIDE the article whose
    own permalink carries this status id. On a thread page the parent posts
    render first, so an unscoped querySelector would act on the wrong post."""
    return ('(()=>{for(const a of document.querySelectorAll(\'article[data-testid="tweet"]\')){'
            'if([...a.querySelectorAll(\'a[href*="/status/"]\')].some(l=>l.getAttribute("href").split("/status/")[1]?.split(/[/?]/)[0]==="' + pid + '"))'
            '{return a.querySelector(\'' + selector + '\')}}return null})()')


def load_liked():
    try:
        return json.load(open(LIKED))
    except FileNotFoundError:
        return {}


def save_liked(d):
    tmp = LIKED + '.tmp'
    json.dump(d, open(tmp, 'w'), indent=1, ensure_ascii=False)
    os.replace(tmp, LIKED)


def post_id(url):
    return url.rstrip('/').rsplit('/status/', 1)[-1].split('?')[0]


def handle_of(url):
    return url.split('x.com/', 1)[-1].split('/', 1)[0]


def like_one(tab, url):
    """Returns 'liked', 'already', or raises. Acts only inside the article
    that carries this URL's status id, never the first button on the page."""
    pid = post_id(url)
    tab.call('Page.navigate', url=url)
    for _ in range(10):
        time.sleep(2)
        state = tab.eval(f'{focal_js(pid, UNLIKE_BTN)} ? "already" : '
                         f'({focal_js(pid, LIKE_BTN)} ? "ready" : "")')
        if state:
            break
    else:
        raise RuntimeError('like button never rendered for the focal post')
    if state == 'already':
        return 'already'
    tab.eval(f'{focal_js(pid, LIKE_BTN)}.click()')
    for _ in range(5):
        time.sleep(1.5)
        if tab.eval(f'!!{focal_js(pid, UNLIKE_BTN)}'):
            return 'liked'
    raise RuntimeError('like did not register on the focal post')


def like(urls, port=9224, space=(20, 60)):
    liked = load_liked()
    out = {}
    todo = [u for u in urls if post_id(u) not in liked]
    if not todo:
        return out
    tab = Tab(port)
    try:
        for i, u in enumerate(todo):
            r = like_one(tab, u)
            out[u] = r
            liked[post_id(u)] = {'handle': handle_of(u), 'url': u, 'result': r,
                                 'at': time.strftime('%Y-%m-%dT%H:%M:%S%z')}
            save_liked(liked)
            print(f'{r} {handle_of(u)}', file=sys.stderr)
            if i < len(todo) - 1:
                time.sleep(random.uniform(*space))
    finally:
        tab.close()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('urls', nargs='+')
    ap.add_argument('--port', type=int, default=9224)
    ap.add_argument('--space', type=float, nargs=2, default=(20, 60))
    a = ap.parse_args()
    r = like(a.urls, a.port, tuple(a.space))
    print(f'{sum(1 for v in r.values() if v == "liked")} liked, '
          f'{sum(1 for v in r.values() if v == "already")} already, '
          f'{len(a.urls) - len(r)} skipped (ledger)', file=sys.stderr)


if __name__ == '__main__':
    main()
