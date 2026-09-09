# Portfolio Hub

The portfolio for [msschermer.us](https://msschermer.us): selected engineering case studies, interactive examples, supporting tools, infrastructure, and contact information.

## Stack

One self-contained HTML file with inline CSS and a small progressive-enhancement script. No dependencies, build step, font downloads, or application API requests. Served by nginx in a container, behind Caddy.

## Running locally

Open `public/index.html` in Chrome, Edge, or another modern browser. It works directly from disk. Refresh an existing preview after edits.

The CRM example switches between illustrative adapter payloads. The monitoring example compares a healthy check, a lower score, and a failed request. Both use labeled sample data and send no requests. The page and native case-study disclosures remain readable without JavaScript.

## Editing

All layout, content, interactions, and structured data live in `public/index.html`. Keep project headings, descriptions, destination links, and JSON-LD synchronized. Preserve static defaults when changing the interactive examples. The existing social image remains in `public/og-image.png`.

## Motion

The page uses a brief hero entrance, one-time section reveals, and short feedback on project controls. Link arrows and navigation underlines share the same easing. Motion is handled by native browser APIs; there are no animation dependencies or continuous scroll handlers.

Content is visible before enhancement. Reduced-motion preferences disable movement and cancel running effects, including when changed while the page is open. Keyboard focus settles entrance animations immediately. Printing and hidden tabs cancel active effects. Keep these fallbacks intact when adding or changing effects.

## Deployment

Pushing to `main` builds the image via GitHub Actions and publishes it to the GitHub Container Registry, tagged with `latest` and the commit SHA. Deploying the image to the server is a separate operation. The `portfolio-hub` service serves the portfolio at the root domain.
