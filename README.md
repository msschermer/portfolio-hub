# Portfolio Hub

The landing page at [msschermer.us](https://msschermer.us). A static index of the tools I have built and run, with a link to the live version and the source of each.

## Stack

One static HTML file, no build step and no JavaScript. Served by nginx in a container, behind Caddy.

## Running locally

Open `public/index.html` in a browser. That is the whole thing.

## Deployment

Pushing to `main` builds the image via GitHub Actions and publishes it to the GitHub Container Registry. The server pulls the image and serves it at the root domain.
