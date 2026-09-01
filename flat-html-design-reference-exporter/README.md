## Flat HTML route exporter

Walks a list of routes on a running app and writes each page out as a single self-contained HTML file. Every linked stylesheet is inlined as a `<style>` block, and every font referenced from that CSS is inlined as a base64 data URI, so the file renders in the exact typeface with zero external requests. No screenshots, no dev server, no login, no network: the file just opens.

### Install

1. Requires Node 18 or later. It uses the built-in `fetch`, so there is nothing to `npm install`.
2. Save `flatten-routes.mjs` and `routes.example.json` into your project.
3. Copy `routes.example.json` to `routes.json` and list the paths you want exported, one per array entry, for example `"/pricing"`.
4. Start your app locally so it answers requests at some base URL.
5. Run the script:
   `node flatten-routes.mjs --base http://localhost:3000 --routes routes.json --out ./flat-pages`
6. Open any file in `./flat-pages` directly in a browser. No server required.

### What to change

- `--base`, to point at your own app's local URL.
- `routes.json`, to your own list of routes.
- If your app renders its markup entirely client side with no server-rendered HTML, point `--base` at a prerendered or server-rendered build instead. This script reads whatever HTML the server returns; it does not run a browser or execute JavaScript.
