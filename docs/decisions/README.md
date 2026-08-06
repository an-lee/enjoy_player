# Architecture Decision Records

ADRs are **immutable** after merge. To change a decision, add a new ADR that **supersedes** the old one.

## Template

```markdown
# ADR-NNNN: Title

## Status
Proposed | Accepted | Superseded by ADR-XXXX

## Context
What problem are we solving?

## Decision
What did we choose?

## Consequences
Trade-offs, follow-up work, risks.
```

## Index

| ID | Title |
|----|-------|
| [0001](0001-state-management-riverpod.md) | State management with Riverpod 3 |
| [0002](0002-persistence-drift.md) | Local persistence with Drift |
| [0003](0003-player-core-media-kit.md) | media_kit as sole player engine |
| [0004](0004-feature-first-architecture.md) | Feature-first directory layout |
| [0005](0005-mvp-scope-local-only.md) | MVP scope — local files only |
| [0006](0006-auth-and-profile-sync.md) | Auth, profile, settings sync (browser flow) |
| [0007](0007-dynamic-color-from-artwork.md) | Dynamic color from media artwork |
| [0008](0008-light-mode-parity.md) | Light mode parity |
| [0009](0009-platform-adaptive-shell.md) | Platform-adaptive shell nuances |
| [0010](0010-cloud-sync-mvp.md) | Cloud sync MVP — metadata (audio/video/recording) |
| [0011](0011-dark-mode-only.md) | Dark mode only + logo-aligned brand (supersedes 0008) |
| [0012](0012-per-user-sqlite-isolation.md) | Per-user SQLite + secure profile cache (partial supersession of 0006) |
| [0013](0013-local-first-sync.md) | Local-first cloud sync + Cloud index (supersedes 0010 download behavior on player) |
| [0014](0014-ai-capabilities-layer.md) | AI capabilities layer (Enjoy worker + capability pattern; BYOK/local placeholders) |
| [0015](0015-youtube-playback.md) | YouTube playback via WebView + HTML5 video (dual engine with media_kit) |
| [0016](0016-enjoy-account-webview-sign-in.md) | Enjoy account sign-in via in-app WebView (partial supersession of 0006) |
| [0017](0017-azure-pronunciation-assessment.md) | Azure pronunciation assessment via native Flutter plugin (token-only) |
| [0018](0018-shared-interactive-primitives.md) | Shared interactive primitives — EnjoyTappable, Haptics, EnjoyButton |
| [0019](0019-transcript-dictionary-lookup.md) | Transcript dictionary lookup — selection scope, bottom sheet, worker APIs |
| [0020](0020-android-windows-release-identity.md) | Android app ID `ai.enjoy.player`, release signing via `key.properties`, Windows release branding + Inno installer |
| [0021](0021-youtube-discover-rss.md) | YouTube discovery via RSS feeds and local channel subscriptions (superseded by 0051) |
| [0022](0022-unified-library-navigation.md) | Unified Library navigation — local + cloud source switch |
| [0023](0023-app-update-distribution.md) | App update distribution — store no-op, direct feeds on dl.enjoy.bot |
| [0024](0024-download-landing-page.md) | Download landing page — static site on Cloudflare Pages at get.enjoy.bot |
| [0025](0025-youtube-player-block-google-signin-nav.md) | Block Google sign-in navigations in YouTube player WebView (supplements 0015) |
| [0026](0026-local-production-diagnostics.md) | Local production diagnostics — rotating logs, opt-in verbose, zip export |
| [0027](0027-native-auth-v2.md) | Native auth v2 — Google, Apple, email OTP, PKCE fallback (supersedes 0016 WebView-primary) |
| [0028](0028-agentic-engine-choice.md) | Agentic workflow engine choice — third-party Anthropic-compatible proxy (accepted) |
| [0029](0029-supply-chain-risk.md) | Supply-chain risk for pre-release and local-path dependencies |
| [0030](0030-flutter-lints-baseline-no-custom-lint.md) | Expanded flutter_lints baseline; defer custom_lint |
| [0031](0031-login-only-access.md) | Login-only application access — auth gate, welcome sign-in hub, guest migration removed |
| [0032](0032-platform-scoped-subscription-purchase.md) | Platform-scoped Pro purchase — desktop external checkout; mobile IAP deferred |
| [0033](0033-byok-ai-provider-settings.md) | BYOK AI provider settings — per-modality Enjoy vs BYOK, secure secrets, direct vendor HTTP |
| [0034](0034-custom-scheme-only-pkce-callback.md) | Custom-scheme-only PKCE callback — drops universal/app links (partial supersession of 0027) |
| [0035](0035-responsive-transport-priorities.md) | Responsive transport priorities and collapsed-expand recovery |
| [0036](0036-youtube-bilingual-transcripts.md) | YouTube bilingual transcripts via multi-language worker contract |
| [0037](0037-transcript-auto-translate.md) | Transcript auto-translate (AI secondary track + lazy scheduler; superseded by 0038 for orchestration; display/identity supplemented by 0039) |
| [0038](0038-viewport-per-line-auto-translate.md) | Viewport-driven per-line auto-translate (supersedes 0037 orchestration) |
| [0039](0039-auto-translate-primary-text-keyed-overlay.md) | Auto-translate as primary-text keyed overlay (index display + sourceKey; supplements 0037/0038) |
| [0040](0040-asr-transcript-generation.md) | ASR transcript generation |
| [0041](0041-unified-tier-reconciliation.md) | Unified tier reconciliation — single source of truth + global resume/cold-start reconcile |
| [0042](0042-multi-language-lookup-catalog.md) | Multi-language lookup catalog — decoupled source / target language pickers for transcript dictionary lookup |
| [0043](0043-craft-from-text-import.md) | Craft from text import — single entry, two modes, BYOK parity for TTS |
| [0044](0044-deterministic-end-of-media-completion-loop.md) | Deterministic end-of-media handling with generation-guarded completion loop |
| [0045](0045-ai-result-cache-hierarchy.md) | Unified two-tier AI result cache (L1 LRU+TTL / L2 Drift) and `AiCacheFingerprint` keying |
| [0046](0046-discover-feed-append-only.md) | Discover feed cache is append-only between unsubscribe events |
| [0047](0047-youtube-discover-innertube.md) | InnerTube `browse` as primary source for YouTube channel discover (superseded by 0051) |
| [0048](0048-linux-platform-support.md) | Linux as a first-class supported desktop platform (AppImage) |
| [0049](0049-youtube-language-aware-captions.md) | YouTube language-aware caption discovery & primary selection |
| [0050](0050-path-linked-local-media.md) | Path-linked local media — prefer lasting link, copy fallback (partial supersession of 0005 import storage) |
| [0051](0051-youtube-worker-discovery.md) | YouTube discovery via server-side RSSHub proxy (supersedes 0021 and 0047) |
| [0052](0052-vocabulary-local-first-schema.md) | Vocabulary local-first Drift schema (items/contexts/reviews; sync deferred) |
| [0053](0053-vocabulary-secondary-route.md) | Vocabulary secondary route (Profile entry; not a primary shell tab) |
| [0054](0054-vocabulary-cloud-sync.md) | Vocabulary cloud sync — SRS-preserving item conflict, LWW contexts, reviews never sync, auto-pull exception to ADR-0013 (extends ADR-0010) |
| [0055](0055-adaptive-page-layout-system.md) | Adaptive page layout system (`EnjoyPage` / browse·hub·form widths) |
| [0056](0056-uservideo-library-membership.md) | UserVideo library membership + content-addressed video uploads (partially supersedes 0013 for video upload ids) |
| [0057](0057-permanent-player-surface-host.md) | Permanent RootShell player surface host (clip portal + launch pipeline) |
| [0058](0058-enjoy-deepgram-long-form-asr.md) | Enjoy long-form ASR via Worker Deepgram jobs (≥900s upload/submit/poll) |
| [0059](0059-phone-tablet-orientation-and-player-aspect-layout.md) | Phone portrait lock / tablet rotate; player stack vs side-by-side by window aspect |
| [0060](0060-craft-voice-express-dual-mode.md) | Craft Voice-Express dual-mode redesign — voice-first Express (default) + Advanced two-tool layout |
| [0061](0061-craft-first-class-history.md) | Craft first-class Home entry, global hotkey, history list, edit-in-place |
| [0062](0062-craft-history-remove-keeps-audio.md) | Remove Craft history record keeps practice audio (`provider` → `user`) |
| [0063](0063-craft-blank-transcript-without-solid-timings.md) | Craft blank transcript without solid word timings (no duration estimates) |
| [0064](0064-word-pronounce-client.md) | Word pronounce client — Worker `/pronounce` + shared tap-to-play control (lookup / flashcard / assessment) |
| [0065](0065-enjoy-modals-root-navigator.md) | Enjoy modals default to root navigator (above PlayerSurfaceHost; supplements 0057) |
| [0066](0066-park-player-surface-for-overlays.md) | Park PlayerSurfaceHost while dialogs/sheets/snackbars are visible (WebView2 z-order; supplements 0057/0065) |
| [0067](0067-github-release-publishing.md) | GitHub Release publishing — per-platform workflows keep building, idempotent draft uploads, coordinator finalizes notes |
| [0068](0068-shadow-toolbar-share-button.md) | Share practice poster moved from transcript overlay into shadow-reading toolbar's leading slot; visibility narrows to echo mode + recordings |
| [0069](0069-feature-onboarding-showcaseview.md) | Feature onboarding tips — Enjoy-owned catalog/progress + showcaseview overlays |
