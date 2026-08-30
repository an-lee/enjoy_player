# AGENTS.md — Enjoy Player (Flutter)

Guidance for humans and AI coding agents working in this repository.

## Read first

1. [README.md](README.md) — setup & commands
2. [.specify/memory/constitution.md](.specify/memory/constitution.md) — quality, testing, UX, performance, and governance gates
3. [docs/architecture.md](docs/architecture.md) — modules & data flow
4. [docs/conventions.md](docs/conventions.md) — Dart / Flutter rules
5. [docs/decisions/README.md](docs/decisions/README.md) — ADR index

## Hard rules

- **Every edit must be green**: After any code change (adding, removing, or editing files), run `flutter analyze` and `flutter test` and fix everything until both pass with zero errors. A task is not done until the tree is green. If a change removes/renames public API, also delete or update every test that references it. For maximum safety, run the full CI gates: `bash .github/scripts/validate_ci_gates.sh` (or `--fix` / `--all`).
- **Supported platforms**: Android, iOS, macOS, Windows, Linux. **Do not add Flutter web** targets, `web/` scaffolding, or `kIsWeb` branches — native desktop/mobile only ([ADR-0048](docs/decisions/0048-linux-platform-support.md)).
- **Single `media_kit` player**: Only [`MediaKitPlayerEngine`](lib/features/player/application/player_engine.dart) / [`PlayerController`](lib/features/player/application/player_controller.dart) may own a `media_kit` `Player`. Never instantiate `Player()` elsewhere (ADR-0003, ADR-0015). YouTube uses `flutter_inappwebview`, not `media_kit`.
- **No `print()`**: Use [`logNamed`](lib/core/logging/log.dart) (a one-line wrapper around `package:logging`'s `Logger`) — never `print()`. See [conventions.md § Logging](docs/conventions.md#logging) for the canonical pattern.
- **Persistence**: All SQLite access goes through Drift [`AppDatabase`](lib/data/db/app_database.dart) DAOs — no raw SQL in UI/feature widgets (ADR-0002).
- **Quality gates**: Behavior changes need automated tests or documented manual verification, shared UI patterns, performance evidence for user-visible hot paths, and matching docs updates.
- **Documentation hygiene**: Architectural decisions → new ADR in [`docs/decisions/`](docs/decisions/). Feature behavior changes → update [`docs/features/<feature>.md`](docs/features/). Shared UI interaction patterns → [ADR-0018](docs/decisions/0018-shared-interactive-primitives.md).
- **Page layout**: New screens pick an [`EnjoyPageKind`](lib/core/layout/enjoy_page_kind.dart) and use [`EnjoyPage`](lib/core/theme/widgets/enjoy_page.dart) / layout tokens (`pageGutter`, `formMaxWidth`, `hubMaxWidth`). Do not invent per-screen max widths or ad-hoc full-bleed forms on desktop — see [ADR-0055](docs/decisions/0055-adaptive-page-layout-system.md) and [app-ui.md](docs/features/app-ui.md#page-layout).

## AI-debug route

When a failing test blocks the tree, the smallest reproducer is one focused test — `testName` is the `test('…')` description, not the file name:

```bash
flutter test test/path/to/specific_test.dart -n testName
```

Runtime logs (redacted; INFO+ by default, FINE+ when **Settings → About → Diagnostic logging** is on) land at `{applicationSupport}/logs/enjoy-player.log` (rotated: `enjoy-player.log`, `.1`, `.2`, ~2 MB each). Per platform: Windows `%APPDATA%\Enjoy\Enjoy Player\logs\`, macOS `~/Library/Application Support/Enjoy/logs/`, Linux `~/.local/share/enjoy/logs/`, iOS / Android inside the app sandbox (export via **Settings → About → Export diagnostic report**).

The first line of a fresh log is a **session banner** — `app=<version>+<buildNumber> platform=<os> mode=<debug|profile|release> channel=<distributionChannel> locale=<localeTag> diagnosticVerbose=<bool>` — that ties every subsequent line to one cold start; treat that banner as the correlation identity when triaging a user report. New code uses [`logNamed`](lib/core/logging/log.dart) (never `print()`) — see [conventions.md § Logging](docs/conventions.md#logging) and [diagnostics.md](docs/features/diagnostics.md).

## Lookup language catalog

The transcript lookup sheet (`lib/features/lookup/`) uses a **separate** `kSupportedLookupLanguageTags` catalog (14 tags) in [`lib/core/application/app_language_catalog.dart`](lib/core/application/app_language_catalog.dart), decoupled from `kSupportedNativeLanguageTags` (profile "native", 2 tags) and `kSupportedFocusLanguageTags` (profile "learning", 8 tags). Widening the lookup picker must not regress profile / settings UI. See [ADR-0042](docs/decisions/0042-multi-language-lookup-catalog.md) and [docs/features/dictionary-lookup.md § Languages](docs/features/dictionary-lookup.md#languages).

## Codegen

After schema or `@riverpod` / `@Riverpod` / Freezed / Drift annotation changes, regenerate **and commit** the outputs:

```bash
dart run build_runner build
# or (root + path packages, then fail if tree drifts):
bash .github/scripts/check_codegen_drift.sh --fix
```

Never hand-edit `*.g.dart` / `*.freezed.dart`. A source change without regenerating the matching generated file fails the **Codegen drift** workflow — and a stale generated file that lands on `main` blocks every subsequent PR with the same drift (riverpod neighbour hashes cascade, so one forgotten regeneration turns into a red `*.g.dart` for unrelated providers too). Never merge with a red Codegen drift run; fix forward by regenerating in the **main checkout** (not an agent worktree — `build_runner` deletes checked-in generated files there).

## Verification

Before pushing Dart / `lib` / `packages` / `test` changes, run the same cheap gates CI uses:

```bash
bash .github/scripts/validate_ci_gates.sh
# auto-fix format + regenerate codegen when needed:
bash .github/scripts/validate_ci_gates.sh --fix
# full local mirror (slower):
bash .github/scripts/validate_ci_gates.sh --all
```

Or the individual commands:

```bash
bash .github/scripts/check_dart_format.sh   # or: --fix
flutter analyze
flutter test
```

`dart format` must cover `lib`, `test`, and `packages/*/lib` + `packages/*/test` (same path set as CI). Skipping format or codegen is the most common way to break main CI.

### Git hooks

Install once per clone so pushes cannot skip the format / codegen gates:

```bash
git config core.hooksPath .githooks
```

- [`.githooks/pre-commit`](.githooks/pre-commit) — secret scanner
- [`.githooks/pre-push`](.githooks/pre-push) — `check_dart_format` + `check_codegen_drift` when Dart sources are in the push range

Release packaging (Android signing, AAB/APK, Windows installer, FFmpeg, **iOS TestFlight**, **macOS notarization**): [docs/packaging.md](docs/packaging.md) and [ADR-0020](docs/decisions/0020-android-windows-release-identity.md).
