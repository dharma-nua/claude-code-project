# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A single-file static HTML poster: **"I Love Golden Retrievers"**. No build tools, no dependencies, no package manager — open `poster.html` directly in a browser to run it.

## Architecture

Everything lives in `poster.html` as a self-contained file with three sections:

- **`<style>`** — All CSS inline in the `<head>`. Color palette is warm amber/orange (`#f5a623`, `#e07b00`, `#f7c948`). Fonts loaded from Google Fonts (Pacifico for headings, Nunito for body).
- **`<body>`** — A single `.poster` card centered on a gradient background. The circular `.dog-frame` holds either the live dog image or a fallback emoji.
- **`<script>`** — Three vanilla JS functions managing the dog image lifecycle:
  - `loadNewDog()` — fetches a random golden retriever image from `https://dog.ceo/api/breed/retriever-golden/images/random`
  - `showDog()` — called via `img onload`, hides the loading emoji and reveals the image
  - `showFallback()` — called via `img onerror`, reverts to the emoji placeholder

The page auto-loads a dog image on first render (`loadNewDog()` called at script end).

## Git Workflow

Always commit and push after every change:

```bash
git add poster.html
git commit -m "short description of what changed"
git push
```

Remote: `https://github.com/dharma-nua/claude-code-project`
