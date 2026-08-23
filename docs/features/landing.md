# Feature: Download landing page (`get.enjoy.bot`)

## Summary

The download landing page is a **hand-authored static site** in [`landing/`](../../landing/) — no build step, no SSG, and explicitly **not** a Flutter web target (the repo bans Flutter web — see the "Supported platforms" hard rule in [AGENTS.md](../../AGENTS.md)). It is hosted on **Cloudflare Pages** (project `enjoy-player-landing`, CNAME → `https://get.enjoy.bot`) and helps a new user pick the right download for their OS. Direct-download buttons are populated at runtime from the release manifest; store links (TestFlight / Play beta) come from a single config file. The architectural rationale is [ADR-0024](../decisions/0024-download-landing-page.md); the in-app update flow that consumes the same manifest is documented in [update.md](update.md).

## Directory structure

| Path | Role |
|------|------|
| `landing/index.html` | Single page: navigation, hero, app showcase, feature bento grid, why section, pricing offers, five platform cards (`card-windows`, `card-macos`, `card-android`, `card-ios`, `card-linux`), closing CTA, and footer. All copy carries `data-i18n` keys. |
| `landing/styles.css` | All styling; dark editorial theme, responsive sections, gradient "recommended" highlights for the Lite pricing offer and detected platform, `overflow-x: clip` on `<html>` to prevent horizontal scroll from decorative bleed. |
| `landing/main.js` | OS detection, manifest fetch, store-button validation, recommended-card highlight. |
| `landing/i18n.js` | `en` / `zh` string tables exposed as `window.translations`; swaps `data-i18n` nodes and persists the choice. |
| `landing/config.js` | `window.ENJOY_CONFIG` — the **only file edited for link maintenance** (see below). |
| `landing/functions/api/latest.js` | Cloudflare Pages Function: same-origin proxy for the release manifest. |
| `landing/_headers` | Cloudflare Pages security headers + per-path cache policy. |
| `landing/wrangler.toml` | Pages config; `pages_build_output_dir = "."` (the directory itself is the output). |
| `landing/logo.svg`, `og-image.svg`, `screenshot-hero.png` | Brand assets and app showcase image (served `immutable`, 24 h TTL). |

## Link maintenance — `config.js`

```js
window.ENJOY_CONFIG = {
  bundleId: 'ai.enjoy.player',
  testFlightUrl: null,   // public TestFlight invite, or null
  playBetaUrl: null,     // Play open-beta opt-in URL, or null
  manifestUrl: '/api/latest',
  releasesUrl: 'https://github.com/an-lee/enjoy_player/releases/latest',
  githubUrl: 'https://github.com/an-lee/enjoy_player',
};
```

- **`testFlightUrl`** — set when a public TestFlight invite is available. `main.js` validates the origin (`https://testflight.apple.com/join/...`, and rejects `PLACEHOLDER`); a `null`/invalid value renders the iOS card with a **disabled "Coming soon"** button (`btn--disabled`, `aria-disabled="true"`, `tabindex="-1"`) — the card stays visible, no broken link is ever exposed.
- **`playBetaUrl`** — same pattern, validated against the `https://play.google.com/` origin.
- **`releasesUrl`** — the no-JS fallback: every platform button's static `href` points at GitHub releases/latest so no action is missing with JavaScript disabled.

Direct-download buttons (`btn-windows`, `btn-macos`, `btn-android`, `btn-linux`) do **not** use `config.js`; their `href`s are rewritten at runtime from the manifest (below).

## Manifest proxy — `functions/api/latest.js`

The Pages Function serves `GET /api/latest`:

1. Fetches the upstream manifest `https://dl.enjoy.bot/player/latest.json` with Cloudflare edge caching (`cacheTtl: 300`, `cacheEverything`).
2. Returns it same-origin with `Cache-Control: public, max-age=300, stale-while-revalidate=600`, so the browser never talks to `dl.enjoy.bot` directly (also allowed by the CSP `connect-src`).
3. On upstream failure returns a JSON `{ error }` body with `502` (or the upstream status) and `Cache-Control: no-store`.

`main.js` reads `assets.windows.url`, `assets.macos.url`, `assets.android_arm64_v8a.url`, and `assets.linux.url` from the manifest, sets each button's `href` + `download` attribute, and fills the `v<version>` badge. The fetch has a **5 s `AbortController` timeout**; on any failure the static GitHub fallback links remain. The manifest schema itself is documented in [update.md § Manifest schema](update.md#manifest-schema).

## OS detection & progressive enhancement — `main.js`

- `detectOS()` uses `navigator.userAgent` / `navigator.platform` heuristics; **iPadOS is disambiguated from macOS via `navigator.maxTouchPoints > 1`** (iPadOS reports `MacIntel`).
- The detected platform's card gets the `card--recommended` gradient highlight plus a localized "Recommended" badge, and is **moved to the front** of `#platform-grid`. All five cards always render regardless.
- Init order: `initI18n()` → `applyConfig()` (store buttons) → highlight → manifest fetch → `applyManifest()`.

## Internationalization — `i18n.js`

Two locales, `en` (default) and `zh`, selected by the header `EN` / `中` buttons (`data-lang`). `initI18n()` swaps the text of every `[data-i18n]` node from `window.translations` and persists the choice (localStorage), so reloads keep the language. Dynamic strings created later (e.g., the recommended badge) look up their `data-i18n` key against the active locale at creation time.

## Pricing offers

The landing page mirrors the current subscription catalog with three informational offers:

- **Free** — $0 forever, 1,000 Enjoy AI credits per day, and all core player features.
- **Lite** — $1.99/month, 12,000 Enjoy AI credits per day.
- **Pro** — $9.99/month, 60,000 Enjoy AI credits per day.

The pricing cards link to the download section rather than pretending to provide checkout. Paid plans are managed inside the app, with platform-specific purchase availability described in [subscription.md](subscription.md). If plan prices or allowances change, update the cards and both locale tables together with the product catalog.

## Security headers & caching — `_headers`

Applied site-wide:

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://dl.enjoy.bot; font-src 'self'; frame-ancestors 'none'
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

Per-path caching: `index.html` is `no-cache, must-revalidate` (links must be fresh); `styles.css` / `main.js` / `config.js` get 1 h (no build-time fingerprinting, so not immutable); SVG brand assets 24 h `immutable`; `/api/latest` mirrors the Function's 5 min + SWR policy.

## Deployment — GitHub Actions + Wrangler

[`.github/workflows/deploy_landing.yml`](../../.github/workflows/deploy_landing.yml) runs on pushes to `main` touching `landing/**`, on PRs touching `landing/**`, and manually:

- **Production**: `wrangler pages deploy landing --project-name enjoy-player-landing --branch main`.
- **PR previews**: deploys to branch `pr-<number>` (Cloudflare Pages preview deployment) and comments on the PR.
- **Required CI secrets**: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`. Without them the workflow fails — set both before the first deploy.
- Concurrency group `deploy-landing-<ref>` with cancel-in-progress.

## Local development

No build step — serve the directory and edit files directly:

```bash
npx wrangler pages dev landing --config landing/wrangler.toml
```

(`wrangler pages dev` also executes the `/api/latest` Function locally.) Any static server works for HTML/CSS/JS-only changes, but only `wrangler pages dev` exercises the manifest proxy.

## Maintenance tasks

| Task | What to do |
|------|-----------|
| New TestFlight invite / Play beta URL | Edit `landing/config.js`, merge; production deploys automatically. |
| New app release | Nothing — the manifest proxy reflects the live `latest.json` on next load. |
| New platform card | Add the `<article id="card-…">` in `index.html`, wire its button in `main.js` (`urlMap` / `applyConfig`), add `en`+`zh` strings in `i18n.js`. |
| Copy changes | Update **both** `en` and `zh` tables in `i18n.js` (the HTML text is only the `en` fallback). |

## See also

- [ADR-0024: Download landing page on Cloudflare Pages](../decisions/0024-download-landing-page.md)
- [update.md — in-app update flow and manifest schema](update.md)
- [linux-platform.md — AppImage distribution referenced by the Linux card](linux-platform.md)
