# Documentation index

Maintainers and agents should keep these files **accurate** when behavior or architecture changes.

| Path | Audience | Update when |
|------|----------|-------------|
| [.specify/memory/constitution.md](../.specify/memory/constitution.md) | Everyone | Quality, testing, UX, performance, or governance principles change |
| [AGENTS.md](../AGENTS.md) | AI agents | Global rules change |
| [architecture.md](architecture.md) | Everyone | Layers, providers, or DB schema change |
| [tech-stack.md](tech-stack.md) | Everyone | Dependencies or versions change |
| [conventions.md](conventions.md) | Contributors | Style / lint / folder rules change (incl. the sliver stable-key convention) |
| [api/rest-services.md](api/rest-services.md) | Contributors | REST service layer pattern (`RestApi`, `JsonMap`, `*ApiClient` choice) changes |
| [packaging.md](packaging.md) | Release | Local-first release runbook (Windows / Android / Apple) |
| [apple-release-ci.md](apple-release-ci.md) | Release | GitHub Actions Apple release workflow & secrets |
| [android-release-ci.md](android-release-ci.md) | Release | GitHub Actions Android release workflow & secrets |
| [windows-release-ci.md](windows-release-ci.md) | Release | GitHub Actions Windows release workflow |
| [ci-self-hosted-runners.md](ci-self-hosted-runners.md) | Release / CI | Self-hosted runner setup for all workflows |
| [testing.md](testing.md) | Contributors | Test strategy or CI commands change |
| [perf-measurement.md](perf-measurement.md) | Contributors | Perf test patterns (emission counting, barrier doubles, list stress) or hot-path verification guidance change |
| [decisions/](decisions/) | Architects | Irreversible technical choices |
| [superpowers/](superpowers/) | Contributors + agents | Large mechanical refactor specs & implementation plans |
| [features/](features/) | Product + dev | Feature behavior changes |
| [features/app-ui.md](features/app-ui.md) | Product + dev | Shell, navigation chrome, or design tokens change |
| [features/skeleton-loading.md](features/skeleton-loading.md) | Product + dev | Skeleton widget API, prebuilt placeholders, or sliver-safe placement rules change |
| [features/hotkeys.md](features/hotkeys.md) | Product + dev | Keyboard shortcuts or customization behavior changes |
| [features/auth.md](features/auth.md) | Product + dev | Sign-in, profile, API base URL, or settings sync behavior changes |
| [features/credits-usage.md](features/credits-usage.md) | Product + dev | Credits usage audit (Worker `/credits/usages`) behavior changes |
| [features/subscription.md](features/subscription.md) | Product + dev | Pro subscription status, desktop checkout, or mobile purchase deferral changes |
| [features/ai.md](features/ai.md) | Product + dev | AI worker capabilities, playground, provider matrix, or `ApiException → AppFailure` translation (`guardAiCall`) behavior changes |
| [features/sync.md](features/sync.md) | Product + dev | Cloud metadata sync (library + recordings + queue) behavior changes |
| [features/library.md](features/library.md) | Product + dev | Home / Library media UI, thumbnails, cold-start perf notes |
| [features/cloud.md](features/cloud.md) | Product + dev | Remote media index (add-to-library) behavior changes |
| [features/youtube.md](features/youtube.md) | Product + dev | YouTube import, WebView playback, login, transcripts behavior changes |
| [features/diagnostics.md](features/diagnostics.md) | Product + dev | Local diagnostic logging, export, and privacy behavior changes |
| [features/discover.md](features/discover.md) | Product + dev | YouTube Discover feeds, subscriptions, add-to-library behavior changes |
| [features/dictionary-lookup.md](features/dictionary-lookup.md) | Product + dev | Transcript selection lookup (translation / contextual / dictionary) behavior changes |
| [features/vocabulary.md](features/vocabulary.md) | Product + dev | Vocabulary book, SRS review, add-from-lookup, Anki export, or vocab sync behavior changes |
| [features/community.md](features/community.md) | Product + dev | Signed-in Home community activity card behavior changes |
| [features/settings.md](features/settings.md) | Product + dev | Settings hub, hotkeys / sync sub-screens, account hero, language / mic pickers, or developer API editors change |
| [features/shadow-reading.md](features/shadow-reading.md) | Product + dev | Shadow reading panel, recording bus, pitch contour, or Azure pronunciation assessment behavior changes |
| [features/update.md](features/update.md) | Product + dev | App update strategy (NoOp / Direct), manifest schema, evaluator rules, or prompt UX change |
| [features/landing.md](features/landing.md) | Product + dev | Download landing page (get.enjoy.bot) links, manifest proxy, i18n, or deploy workflow change |
| [features/share-poster.md](features/share-poster.md) | Product + dev | Shareable practice poster (echo-tailored cover + quote) behavior changes |
| [features/player.md](features/player.md) | Product + dev | Player engine binding, expand/collapse, transport, echo enforcement, or wide-layout behavior changes |
| [features/transcript.md](features/transcript.md) | Product + dev | Transcript loading, line navigation, auto-scroll, or cloud fetch behavior changes |
| [features/asr.md](features/asr.md) | Product + dev | Local-file ASR generation pipeline, audio extraction (FFmpegKit / isolate), failure reasons, or `source: ai` upsert behavior changes |
| [features/echo-mode.md](features/echo-mode.md) | Product + dev | Echo region, shadow-reading, pronunciation assessment, or share practice poster behavior changes |
| [features/local-database-recovery.md](features/local-database-recovery.md) | Product + dev | Stale/malformed local-DB detection, the recovery surface, or the reset-local-library flow changes |
| [features/linux-platform.md](features/linux-platform.md) | Product + dev | Linux support matrix, AppImage packaging/release, or per-platform feature availability changes |
| [features/craft.md](features/craft.md) | Product + dev | Craft dual-mode (voice-first Express + Advanced translate/synthesize), from Text import, voice picker, history, or failure handling changes |

## How to add an ADR

1. Copy the template in [decisions/README.md](decisions/README.md).  
2. Use the next number: `000N-short-title.md`.  
3. **Do not rewrite old ADRs** — supersede with a new one.

## How to update a feature spec

Edit the matching file under [features/](features/) in the **same PR** as the code change.
