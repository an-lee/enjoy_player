# Self-hosted CI runners

All GitHub Actions workflows in this repo run on **self-hosted** runners. They do **not** use GitHub Actions cache (`actions/cache` or `cache: true` on setup actions) or upload build outputs via `actions/upload-artifact` — both bill for storage. Dependencies stay on the runner's local disk between jobs; release binaries go to **dl.enjoy.bot** (S3/R2) when publish is enabled, or remain on the runner workspace until the job ends.

Runners are managed via **[`gh-sr`](https://github.com/an-lee/gh-sr)** (`~/.gh-sr/runners.yml` on the control machine), except where noted. See that repo's docs for `hosts` / `runners` / `container_runner_image` schema.

Shared workflow pieces:

| Path | Purpose |
|------|---------|
| [`.github/actions/setup-flutter`](../.github/actions/setup-flutter) | Install/pin Flutter from [`.github/flutter-version`](../.github/flutter-version). Installs into a persistent, version-keyed directory on the runner's local disk and **skips the download entirely** when that version is already present — no `subosito/flutter-action` cache, no GitHub cache API. Reinstalls if the cached tree is missing `bin/flutter` or a working `.git` (required by `flutter --version`). |
| [`.github/actions/setup-android`](../.github/actions/setup-android) | Wrap `android-actions/setup-android` with retries: the upstream action fails the job when the flaky network cannot fetch dl.google.com package manifests; the wrapper tolerates that, retries the `sdkmanager` install with backoff, and skips the network entirely once the requested packages persist on the runner. |
| [`.github/actions/setup-macos-runner-env`](../.github/actions/setup-macos-runner-env) | Homebrew PATH, UTF-8 locale, curl HTTP/1.1, `GIT_CONFIG_COUNT=0` (SwiftPM-safe) |
| [`.github/scripts/apple_spm_hygiene.sh`](../.github/scripts/apple_spm_hygiene.sh) | Host lock + SPM cache clear + retry helpers for Apple CI/release |
| [`.github/scripts/ensure_linux_tooling.sh`](../.github/scripts/ensure_linux_tooling.sh) | Install apt packages only when missing. On the shared gh-sr agentic pool these are now normally baked into the container image (see below), so this is usually a fast no-op. |
| [`.github/scripts/ensure_nuget_feed.ps1`](../.github/scripts/ensure_nuget_feed.ps1) | Ensure NuGet.org feed on Windows |
| [`.github/workflows/shared/runtime.md`](../.github/workflows/shared/runtime.md) | gh-aw shared Flutter pre-agent setup + `dart` network for agentic workflows |

When you bump Flutter in `.github/flutter-version`, the next workflow run downloads that version once per runner/host and reuses it from local disk afterward.

---

## Baking dependencies into the runner instead of installing them per job

Because runners are self-hosted, dependencies that don't change often should live on the runner rather than being fetched by every job:

- **Linux (shared gh-sr agentic pool):** gh-sr builds a Docker image for `runner_mode: container` / `profile: agentic` runners. `runners.yml`'s `container_runner_image.extra_apt_packages` bakes the Flutter Linux build packages (`clang`, `cmake`, `ninja-build`, `xz-utils`, `zip`, `libgtk-3-dev`, `liblzma-dev`, `libsqlite3-dev`) into that image, on top of the packages already in gh-sr's own core manifest (`curl`, `git`, `jq`, `pkg-config`, `unzip`, …). This survives `gh sr rebuild` / `gh sr update` (which recreate the container and would otherwise wipe anything installed at runtime by `ensure_linux_tooling.sh`).
- **macOS / Windows (native runners):** gh-sr has no generic dependency-baking mechanism for native runners — the runner's own filesystem just persists between jobs as long as it isn't reinstalled from scratch. Install Flutter's OS-level prerequisites once, manually, per the checklists below; the idempotent scripts (`fetch_ffmpeg.ps1`, `ensure_nuget_feed.ps1`, `ensure_inno_setup.ps1`, `ensure_ios_ci_toolchain.sh`) then skip re-installing on every run.
- **Flutter SDK itself (all platforms):** handled at the workflow level by [`.github/actions/setup-flutter`](../.github/actions/setup-flutter) — see the table above.

---

## Agentic workflows (gh-aw)

GitHub **Agentic Workflows** (`gh-aw`) run on a Linux self-hosted runner with labels **`self-hosted`**, **`linux`**, and **`agentic`**. The same physical machine may also carry the **`Linux`** label used by deterministic CI — that is fine; both share the Flutter pin in [`.github/flutter-version`](../.github/flutter-version).

Each agentic job runs pre-agent steps from [`shared/runtime.md`](../.github/workflows/shared/runtime.md) before the AI engine starts:

1. `ensure_linux_tooling.sh` (apt packages, idempotent)
2. [`.github/actions/setup-flutter`](../.github/actions/setup-flutter)
3. `flutter pub get`

**Scope:** AWF requires Linux. Agents can run `flutter analyze`, `flutter test`, and `dart format` here — not iOS/macOS/Windows builds or signed Android releases.

**Network:** Shared runtime adds the gh-aw `dart` ecosystem (`pub.dev`, Flutter storage) to the firewall allowlist.

**Compile:** After editing workflow `.md` files, run `gh aw compile --validate` and commit the generated `.lock.yml` files.

Agentic workflow sources: `test-improver`, `repo-assist`, `perf-improver`, `duplicate-code-detector`, `large-file-simplifier`, `issue-triage`, `update-docs`, `agentic-wiki-writer`.

---

## Register runners

Runners are registered via `gh-sr` (`gh sr setup && gh sr up`), except where noted below. Labels must match workflow `runs-on`:

| Workflow | Labels | gh-sr runner block |
|----------|--------|---------------------|
| CI, Codegen drift, Android APK smoke, Release Android | `self-hosted`, `Linux` | `baizhiheizi` (org-scoped, `profile: agentic`, shared with gh-aw) |
| gh-aw agentic workflows (test-improver, repo-assist, …) | `self-hosted`, `linux`, `agentic` | `baizhiheizi` (same pool as above) |
| Build Apple, Release Apple | `self-hosted`, `macos` | `baizhiheizi-mac` (org-scoped, shared) |
| Build Windows, Release Windows | `self-hosted`, `windows`, `flutter` | `enjoy-player-win` (repo-scoped, dedicated) |

The **`macos`** label (GitHub's default for macOS self-hosted runners) is what Apple workflows target. An optional **`flutter`** custom label can be added to runner blocks for stricter routing, but it is **not** required by [`build_apple.yml`](../.github/workflows/build_apple.yml) or [`release_apple.yml`](../.github/workflows/release_apple.yml).

`enjoy-player-win` is a **dedicated, repo-scoped** native Windows runner (introduced to close the gap where no self-hosted Windows runner previously existed — Release Windows used to run on GitHub-hosted `windows-latest`). Unlike the shared Linux/macOS org pools, it only serves `baizhiheizi/enjoy_player`.

---

## Linux runner checklist

One machine (the shared gh-sr agentic pool) serves CI, codegen, and Android smoke jobs.

The Flutter build packages below are baked into the gh-sr container image via `container_runner_image.extra_apt_packages` in `runners.yml` — after `gh sr rebuild`, they no longer need manual installation or a per-job `apt-get`. This list is kept here for reference and for any non-gh-sr / native Linux host:

```bash
# Flutter (pin to .github/flutter-version)
flutter --version
flutter doctor

# Java 17+ on PATH
java -version

# Android SDK (set in runner service env or ~/.profile)
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"   # example path
sdkmanager "platforms;android-35" "build-tools;35.0.0"

# Build deps — baked into the gh-sr agentic image; CI also runs
# ensure_linux_tooling.sh idempotently as a safety net.
sudo apt-get install -y \
  clang cmake curl git ninja-build pkg-config unzip xz-utils zip \
  libgtk-3-dev liblzma-dev libsqlite3-dev
```

Ensure the runner service inherits `PATH`, `ANDROID_SDK_ROOT`, and `JAVA_HOME`.

---

## macOS runner checklist

See also [apple-release-ci.md](apple-release-ci.md) for signing secrets and release steps.

```bash
flutter --version
xcodebuild -version
pod --version
brew bundle install --file=macos/Brewfile

# One-time after Xcode upgrade (installs CoreSimulator + CLI components; needs admin once):
sudo xcodebuild -runFirstLaunch

# iOS smoke CI also runs this idempotently; pre-warm to avoid multi-GB downloads mid-job:
xcodebuild -downloadPlatform iOS
```

The **Build Apple** workflow runs [`.github/scripts/ensure_ios_ci_toolchain.sh`](../.github/scripts/ensure_ios_ci_toolchain.sh) before iOS compile smoke. If `xcodebuild -runFirstLaunch` fails with *Authorization is required*, run the `sudo` command above on the runner Mac.

Runner user must access Keychain certs when using `APPLE_USE_RUNNER_KEYCHAIN=true`.

---

## Windows runner checklist

`gh-sr` has no automated dependency-baking for native Windows runners (that's Linux/container-image only — see above), so the following is a **one-time manual setup** on the host before `gh sr setup enjoy-player-win`:

- **Visual Studio Build Tools** with the **"Desktop development with C++"** workload (required by `flutter build windows`)
- **Git** on `PATH`
- **NuGet CLI** on `PATH` (WebView2 / `azure_speech` restore) — `ensure_nuget_feed.ps1` only configures the feed, it does not install `nuget` itself
- **Chocolatey** — `ensure_inno_setup.ps1` falls back to `choco install innosetup` when Inno Setup isn't already present
- **OpenSSH Server**, only if `gh-sr` will reach this host over SSH (not needed when the host's `addr: local`, as with `z13`)

Once those are in place:

```powershell
flutter --version
flutter doctor
nuget help   # NuGet CLI on PATH for azure_speech / WebView2
iscc /?      # Inno Setup, or let ensure_inno_setup.ps1 install it via choco
```

Windows workflows run `windows/scripts/fetch_ffmpeg.ps1`, `ensure_nuget_feed.ps1`, and (for releases) `ensure_inno_setup.ps1` automatically — all idempotent, so after the first run they no-op. For local builds see [packaging.md](packaging.md).

---

## Workflows

| Workflow | Runner | Trigger | Notes |
|----------|--------|---------|-------|
| [ci.yml](../.github/workflows/ci.yml) | Linux | PR/push touching `lib/`, `test/`, `packages/`, pubspec, or CI setup + manual | analyze, format, test |
| [codegen_drift.yml](../.github/workflows/codegen_drift.yml) | Linux | PR/push touching `lib/`, `packages/`, pubspec + manual | build_runner drift check |
| [android_apk_smoke.yml](../.github/workflows/android_apk_smoke.yml) | Linux | PR/push touching `lib/`, `packages/`, `android/`, pubspec + manual | APK + AAB compile smoke |
| [build_linux.yml](../.github/workflows/build_linux.yml) | Linux | PR/push touching `lib/`, `packages/`, `linux/`, pubspec, or CI setup + manual | Linux desktop build smoke (debug + release) |
| [build_windows.yml](../.github/workflows/build_windows.yml) | self-hosted Windows | PR/push touching `lib/`, `packages/`, `windows/`, pubspec + manual | debug + release smoke |
| [build_apple.yml](../.github/workflows/build_apple.yml) | macOS | PR/push touching `lib/`, `packages/`, `ios/`, `macos/`, pubspec + manual | iOS + macOS compile smoke |
| [release_apple.yml](../.github/workflows/release_apple.yml) | macOS | manual only (`workflow_dispatch`) | signed IPA, TestFlight, notarized macOS |
| [release_android.yml](../.github/workflows/release_android.yml) | Linux | manual only (`workflow_dispatch`) | signed AAB/APK for Play / sideload |
| [release_windows.yml](../.github/workflows/release_windows.yml) | self-hosted Windows (`enjoy-player-win`) | manual only (`workflow_dispatch`) | release build + Inno Setup installer |

Each build/smoke workflow's `paths` filter lives inline in its own file — see the `on.pull_request.paths` block. Path filters only apply to `pull_request`/`push`; `workflow_dispatch` always runs regardless of what changed. Release workflows dropped their `push: tags: v*` trigger — publishing now always starts from **Actions → Run workflow**, with the release scripts' `--publish` behavior controlled entirely by the `publish` input.
