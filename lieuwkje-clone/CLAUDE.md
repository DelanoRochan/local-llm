# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**lieuwkje-clone** — A single-page React website that recreates the "Lieuwkje" Dutch handmade greeting card shop. Built with Vite + React 19 + Tailwind CSS v4.

## Quick commands

```bash
npm run dev      # Start dev server
npm run build    # Production build
npm run preview  # Preview production build
npm run lint     # Run oxlint
```

## Architecture

Single-page app with a flat component structure — no router, no state management library. Everything lives in a single `App.jsx` file.

### Entry chain

```
index.html → src/main.jsx → src/App.jsx
```

### Key files

| File | Role |
|---|---|
| `vite.config.js` | Vite config with `@vitejs/plugin-react` and `@tailwindcss/vite` |
| `src/index.css` | Tailwind v4 import, `@theme` custom colors/fonts, fade-in animation |
| `src/main.jsx` | React 18+ entry — wraps `<App />` in `StrictMode`, renders to `#root` |
| `src/App.jsx` | Single-file app with all components: `App`, `Logo`, `CardTile`, `CardIllustration`, `CookieBanner`, `InstagramIcon`, `BagIcon` |
| `src/assets/` | Static assets (hero.png, React/Vite logos, unused) |
| `public/` | Favicon and icons sprite (`icons.svg`) |

### Component breakdown (all in `src/App.jsx`)

- **App** (default export) — Root layout: sticky header + scrollable card grid + fixed cookie banner
- **Logo** — Inline SVG floral illustration + "Lieuwkje" text in Cormorant Garamond italic
- **CardTile** — Rounded card wrapper with Sage/beige background + fade-in animation
- **CardIllustration** — Abstract watercolor SVG with ellipses, gradients, and easel silhouette
- **CookieBanner** — Fixed bottom banner with cookie notice and three action buttons (Voorkeuren/Afwijzen/Accepteren)
- **InstagramIcon / BagIcon** — Inline SVG icons for the header

### Data

Product cards are hardcoded in the `CARDS` array in `App.jsx` — 9 items with bg color, gradient palette, label, and price. A `highlighted` flag on one card triggers a product-label overlay.

### Styling system

Tailwind CSS v4 (not v3) via the `@tailwindcss/vite` plugin. Custom design tokens are defined in `src/index.css` using the `@theme` directive:

- Warm beige header: `--color-warm-bg: #f0e2d0`
- Cream body bg: `--color-cream: #f8f5ef`
- Sage card tones: `--color-sage-100/200/300`
- Cookie banner: `--color-cookie-bg`, `--color-cookie-border`
- Serif font: `--font-family-serif: Cormorant Garamond`

Responsive breakpoints: `sm:` (768px), `lg:` (1024px). Grid goes from 1 → 2 → 3 columns.
