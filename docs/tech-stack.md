# Tech stack

| Concern | Choice | Notes |
|---------|--------|-------|
| Language | Dart ^3.12 | Strict analysis; matches `sdk: ^3.12.0` in `pubspec.yaml`. Flutter pinned in [`.github/flutter-version`](../.github/flutter-version). |
| UI | Flutter 3.x / Material 3 + `google_fonts` | Dark-only `buildAppTheme()` + `EnjoyThemeTokens` in `lib/core/theme/` |
| State | `flutter_riverpod` + `riverpod_annotation` | `@Riverpod` notifiers, `build_runner` |
| Navigation | `go_router` | Shell route for persistent mini player |
| Playback | `media_kit` + `media_kit_video` + `media_kit_libs_video` | Single `Player` instance |
| Persistence | `drift` + `drift_flutter` + `sqlite3_flutter_libs` | Native SQLite |
| Files | `file_picker` + `path_provider` + `cross_file` | Prefer lasting external link; copy into app `media/` when lasting access is unavailable ([ADR-0050](decisions/0050-path-linked-local-media.md)) |
| IDs | `uuid` | v5 namespaced IDs for media from file hash |
| Logging | `logging` | Wrapper `logNamed` |
| Networking | `http` | Enjoy API client under `lib/data/api/` |
| Secure storage | `flutter_secure_storage` | Access token only |
| Browser / deep links | `url_launcher` | OAuth `start_auth` browser step |
| Markdown (AI explanations) | `flutter_markdown_plus` | Contextual translation in transcript lookup sheet |
| i18n | `flutter_localizations` + ARB | `lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_CN.arb`; default display locale `zh-CN` ([`kAppDefaultDisplayLocale`](../lib/core/application/app_language_catalog.dart)) |
| Codegen | `build_runner`, `drift_dev`, `riverpod_generator` | Run after schema/provider edits |
| Lint | `flutter_lints` ^6.0.0 | Expanded baseline in `analysis_options.yaml` (quotes, trailing commas, async hygiene, package deps). `custom_lint` deferred — see [ADR-0030](decisions/0030-flutter-lints-baseline-no-custom-lint.md). |

Deferred (ADR-0005): URL streaming UX polish. Library/recording **cloud sync** remains deferred; see [ADR-0006](decisions/0006-auth-and-profile-sync.md) for optional auth + profile scope.

> Note: `flutter_inappwebview` is **active** (not deferred) — it powers the YouTube player per [ADR-0015](decisions/0015-youtube-playback.md) and the in-app Enjoy sign-in WebView per [ADR-0027](decisions/0027-native-auth-v2.md).
