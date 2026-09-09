# Portfolio Hub

The portfolio for [msschermer.us](https://msschermer.us): selected engineering case studies, interactive examples, supporting tools, infrastructure, and contact information.

## Stack

One HTML file with inline CSS and a small progressive-enhancement script, plus four self-hosted font files. No build step, no dependencies, no third-party requests, and no application API calls. Served by nginx in a container, behind Caddy.

## Typography

Three self-hosted faces in `public/fonts/`, latin subset only, ~104KB total. All are licensed under the SIL Open Font License 1.1, which permits self-hosting and redistribution.

| Role | Face | File |
| --- | --- | --- |
| Text, UI, headlines | Inter (variable, 100–900) | `inter-var-latin.woff2` |
| Accent / display italic | Instrument Serif Italic | `instrument-serif-italic-latin.woff2` |
| Labels, eyebrows, data | IBM Plex Mono 400 / 500 | `plex-mono-*-latin.woff2` |

Inter and Instrument Serif are preloaded because they render above the fold. All faces use `font-display: swap` and carry an explicit `unicode-range`, so a missing file degrades to the declared system fallback rather than blocking text.

The mono face is self-hosted rather than left to a system stack: `SFMono-Regular` is not reachable from a web page on macOS, so the previous stack fell through to Courier there, changing the look of every label by platform.

## Product screenshots

`public/img/` holds one screenshot per tool, captured from the live application at 1280×800. They are the proof that the case-study claims are real, so re-capture them at the same size whenever a tool's interface changes meaningfully.

Each is wrapped in the `.shot` component and links to the running tool. Featured projects lead with a large image alongside the case-study summary; technical examples live inside the expandable build notes. All are `loading="lazy"` with explicit `width`/`height` and a CSS `aspect-ratio`, so the box is reserved before the image decodes and a late-arriving image never shifts the text under the reader. Total image weight is ~384KB, none of it above the fold.

## Design tokens

All color, type, and spacing values are declared as custom properties in the `:root` block at the top of the stylesheet. Change them there rather than in individual rules:

- **Surfaces** — two dark steps (`--ink`, `--ink-2`, `--ink-3`) and three light steps (`--paper`, `--paper-2`, `--paper-3`).
- **Text roles** are named by job, not value: `--on-dark-1/2/3`, `--on-light-1/2/3`. Check contrast when changing a text or surface color.
- **Accent** — cool blue for links and emphasis, with a small yellow-green availability illustration.
- **Type** — a fluid modular scale, `--fs-mono` through `--fs-4xl`.
- **Space** — a 4px scale, `--s1` through `--s10`. Every gap and pad is a step on it.

Single-column grid tracks use `minmax(0,1fr)` rather than `1fr`; the latter resolves to `minmax(auto,1fr)` and lets a long child push the page wider than the viewport.

## Running locally

Open `public/index.html` directly in Chrome. Fonts, images, and the favicon use relative paths and work from disk or over HTTP. To use a local server instead:

```
node -e "const h=require('http'),f=require('fs'),p=require('path');const t={'.html':'text/html; charset=utf-8','.woff2':'font/woff2','.png':'image/png','.svg':'image/svg+xml'};h.createServer((q,s)=>{let u=q.url.split('?')[0];if(u==='/')u='/index.html';f.readFile(p.join('public',u),(e,d)=>{if(e){s.writeHead(404);return s.end()}s.writeHead(200,{'Content-Type':t[p.extname(u)]||'application/octet-stream'});s.end(d)})}).listen(8899,()=>console.log('http://127.0.0.1:8899'))"
```

The CRM example switches between illustrative adapter payloads. The monitoring example compares a healthy check, a lower score, and a failed request. Both use labeled sample data and send no requests.

## Editing

All layout, content, interactions, and structured data live in `public/index.html`. Keep project headings, descriptions, destination links, and JSON-LD synchronized. Preserve the static defaults when changing the interactive examples.

The contact section uses the owner-provided email address and LinkedIn profile.

## Motion

The availability badge gives a short wave on arrival and then settles. The page also uses a brief hero entrance, one-time section reveals, short feedback on project controls, and a redraw of the monitoring line. Nav underlines and link arrows share one easing token. Motion uses native browser APIs; there are no animation dependencies and no scroll handlers.

Content is visible before enhancement. Reduced-motion preferences disable movement and cancel running effects, including when the preference changes while the page is open. Keyboard focus settles entrance animations immediately. Printing and hidden tabs cancel active effects. Keep these fallbacks intact when adding or changing effects.

The reading-position indicator in the nav is also observer-based, for the same reason: no scroll listener on the main thread.

The desktop hero fills the first viewport below the navigation using a minimum height and distributed spacing. It can grow naturally for enlarged text or constrained windows. Typography and spacing adapt to short windows; mobile keeps a natural reading flow. Project shortcuts are omitted on mobile and short desktop windows; the main Work link remains available. A static, wrapping technology strip keeps the stack readable without an automatic carousel. Inline link labels own their underlines so adjacent arrows remain undecorated.

## Deployment

Pushing to `main` builds the image via GitHub Actions and publishes it to the GitHub Container Registry, tagged with `latest` and the commit SHA. Deploying the image to the server is a separate operation. The `portfolio-hub` service serves the portfolio at the root domain.

## Stack icons

The technology strip uses five brand SVGs from Simple Icons 16.0.0, stored locally in `public/icons/`. Source: https://github.com/simple-icons/simple-icons/tree/16.0.0/icons. The CC0 license is included as `LICENSE-simple-icons.txt`; brand names and marks remain the property of their owners. The database and API symbols are generic SVGs. Icons are decorative beside visible labels and add no script, package dependency, or external request.
