# ADR-0029: Supply-chain risk for pre-release and local-path dependencies

## Status

Accepted — 2026-06-28.

## Context

Issue #83 flagged three categories of dependency-hygiene risk in
`pubspec.yaml`:

1. **Pre-release / single-publisher deps** that are central to the
   release pipeline but have no functional test coverage in this
   repository.
2. **Local-path packages** under `packages/` that are not published to
   pub.dev and are pinned to whatever the working tree happens to
   contain.
3. **Documented fragility** — the `azure_speech` plugin declares
   `sdk: ^3.9.0` while the root requires `^3.12.0`, and the
   `ffmpeg_kit_flutter_new` plugin ships no Windows implementation
   even though the app must run on Windows.

`flutter_secure_storage: ^10.2.0` was also flagged as a "typo" in the
review, but is in fact a valid caret range: 10.x is the current
pre-release → 10.3.1 stable series on pub.dev and `pubspec.lock` already
resolves to `10.3.1`. The caret range is intentional. The next stable
major (11.x) is currently a `11.0.0-beta.1` pre-release; we will
upgrade explicitly when the maintainer stabilizes the API.

## Decision

### Pre-release / single-publisher deps

Pin **exactly** (no caret) so a fresh `pub get` on a different machine
cannot silently upgrade. Bumps go through normal PR review. Current
pins:

| Package | Pin | Used for | Risk |
|---------|-----|----------|------|
| `file_picker` | `12.0.0-beta.4` | Library / import flows | Beta; single publisher (miguelpruivo) |
| `auto_updater` | `0.2.1` | Sparkle / WinSparkle auto-update on macOS / Windows | Single publisher (leocavalcante) |
| `ota_update` | `7.1.0` | Direct-channel Android APK auto-update | Single publisher (heroims GobeToolkit) |

We accept the single-publisher risk because there is no widely-used
multi-publisher alternative that meets the platform requirements
(Sparkle for macOS, WinSparkle for Windows, APK streaming for Android).
We mitigate by:

- Pinning exactly so a compromised publisher cannot move our builds
  forward without a code review.
- Running CI (`flutter analyze`, `flutter test`) on every PR so a
  malicious update that breaks the build is caught before merge.
- Re-evaluating alternatives at the next major version bump.

### Local-path packages

The three path: deps in `pubspec.yaml` are deliberately in-tree and are
tracked by `bash .github/scripts/check_no_new_path_deps.sh` in CI
(see `ci.yml`). New path: deps must be added to the script's
`ALLOWLIST` and to this ADR, or converted to a `git:` ref / pub.dev
package.

Current allowlist:

| Path | Reason | Follow-up |
|------|--------|-----------|
| `packages/azure_speech` | First-party Flutter plugin wrapping Microsoft Azure Cognitive Services Speech SDK for pronunciation assessment (Android / iOS / macOS / Windows). Forked from a private internal fork to control the small subset of API surface we need. | Track upstream `microsoft/cognitive-services-speech-sdk` releases; re-evaluate at next major. |
| `packages/ffmpeg_kit_flutter_new` | Vendored from `sk3llo/ffmpeg_kit_flutter` because the upstream `arthenica/ffmpeg-kit` was archived in 2025. We need Android / iOS / macOS bindings. Windows is **not** implemented by this plugin — see packaging.md. | Watch the new community fork; re-evaluate when a Windows-capable plugin emerges. |
| `packages/forced_alignment` | First-party on-device alignment engine (16 kHz PCM in, Echogarden-shaped word/phone timings out). UI-free; not invoked by Craft/transcript/player (ADR-0071). Production spoken reference is a thin eSpeak-NG `espeak_Synth` FFI wrap in this package (ADR-0072), not pub.dev `espeak`. | Re-evaluate if upstream `espeak` grows waveform synth; keep fail-closed when native lib/data is missing. |

### `azure_speech` SDK constraint

Bumped from `sdk: ^3.9.0` → `sdk: ^3.12.0` to match the root
constraint. The plugin's own deps (`json_annotation: ^4.11.0`,
`meta: ^1.16.0`, `plugin_platform_interface: ^2.1.8`) all resolve
under Dart 3.12, so this is a safe tightening that prevents the
plugin from silently constraining the root to an older Dart.

## Consequences

- `pub get` is now reproducible: the only deps that can move on a
  fresh checkout are the caret-pinned, stable ones we trust.
- CI gates new path: deps behind an explicit PR. A maintainer who
  wants to add one must edit both `check_no_new_path_deps.sh` and this
  ADR in the same PR, which forces a conversation.
- We are still vulnerable to a publisher compromise between two
  intentional upgrades. We accept this in exchange for staying on
  actively-maintained packages; the alternative (vendoring everything)
  is out of scope for the team.
