```
#!/usr/bin/env node
/*
 * Walks a list of routes on a running app and writes each page out as a
 * single self-contained HTML file: linked stylesheets are inlined as
 * <style> blocks, and any font referenced from that CSS is inlined as a
 * base64 data URI. The result opens cold, with no dev server, no login,
 * and no network requests.
 *
 * Usage:
 *   node flatten-routes.mjs --base http://localhost:3000 --routes routes.json --out ./flat-pages
 *
 * Requires Node 18 or later (built-in fetch). No npm install needed.
 */

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';

const FONT_MIME = {
  woff2: 'font/woff2',
  woff: 'font/woff',
  ttf: 'font/ttf',
  otf: 'font/otf',
  eot: 'application/vnd.ms-fontobject',
};

function parseArgs(argv) {
  const args = { base: '', routes: 'routes.json', out: './flat-pages' };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--base') args.base = argv[++i];
    else if (flag === '--routes') args.routes = argv[++i];
    else if (flag === '--out') args.out = argv[++i];
  }
  if (!args.base) {
    console.error('Missing --base <url>. Example: --base http://localhost:3000');
    process.exit(1);
  }
  return args;
}

async function fetchText(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText} fetching ${url}`);
  return res.text();
}

async function fetchBuffer(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText} fetching ${url}`);
  return Buffer.from(await res.arrayBuffer());
}

async function inlineFontUrls(css, baseUrl) {
  const matches = [...css.matchAll(/url\(\s*(['"]?)([^'")]+)\1\s*\)/g)];
  let out = css;
  for (const m of matches) {
    const raw = m[2];
    if (raw.startsWith('data:')) continue;
    const abs = new URL(raw, baseUrl).toString();
    const ext = path.extname(new URL(abs).pathname).slice(1).toLowerCase();
    const mime = FONT_MIME[ext];
    if (!mime) continue;
    try {
      const buf = await fetchBuffer(abs);
      const dataUri = `data:${mime};base64,${buf.toString('base64')}`;
      out = out.split(m[0]).join(`url(${dataUri})`);
    } catch (err) {
      console.warn(`  skipped font ${abs}: ${err.message}`);
    }
  }
  return out;
}

async function flattenPage(html, baseUrl) {
  let out = html;

  const linkTags = html.match(/<link\s+[^>]*rel=["']stylesheet["'][^>]*>/gi) || [];
  for (const tag of linkTags) {
    const hrefMatch = tag.match(/href=["']([^"']+)["']/i);
    if (!hrefMatch) continue;
    const abs = new URL(hrefMatch[1], baseUrl).toString();
    let css = await fetchText(abs);
    css = await inlineFontUrls(css, abs);
    out = out.replace(tag, `<style>\n${css}\n</style>`);
  }

  const styleBlocks = [...out.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)];
  for (const block of styleBlocks) {
    const inlined = await inlineFontUrls(block[1], baseUrl);
    if (inlined !== block[1]) out = out.replace(block[0], `<style>${inlined}</style>`);
  }

  return out;
}

function nameFor(route) {
  if (route === '/' || route === '') return 'index';
  return route.replace(/^\/|\/$/g, '').replace(/\//g, '-');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const routes = JSON.parse(await readFile(args.routes, 'utf8'));
  await mkdir(args.out, { recursive: true });

  for (const route of routes) {
    const url = new URL(route, args.base).toString();
    console.log(`fetching ${url}`);
    const html = await fetchText(url);
    const flat = await flattenPage(html, url);
    const file = path.join(args.out, `${nameFor(route)}.html`);
    await writeFile(file, flat, 'utf8');
    console.log(`  wrote ${file}`);
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
```
