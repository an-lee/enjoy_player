# Android release CI setup

Guide for configuring [`.github/workflows/release_android.yml`](../.github/workflows/release_android.yml) on GitHub.

The workflow runs on your **self-hosted Linux runner** (`runs-on: [self-hosted, Linux]`) — the same machine as [Android APK smoke](../.github/workflows/android_apk_smoke.yml).

## What the release workflow does

1. `flutter analyze` + `flutter test`
2. Loads **upload keystore** from GitHub Secrets (or uses files already on the runner)
3. Builds signed **App Bundle** (`flutter build appbundle --release --flavor store`) for Google Play
4. Optionally uploads the AAB to Google Play **alpha** (closed testing) as a **draft** (`--play`)
5. Optionally builds signed **per-ABI APKs** for sideload (`--split-per-abi`, `direct` flavor)
6. Optionally **publishes** sideload APKs to dl.enjoy.bot — no GitHub artifact upload (avoids storage billing)

**Triggers**

- **Tag push**: `v*.*.*` (e.g. `v0.8.1`) — builds AAB + per-ABI APKs, uploads Play alpha draft, publishes sideload feeds to dl.enjoy.bot, and attaches binaries to a draft GitHub Release.
- **Manual**: GitHub → Actions → **Release Android** → **Run workflow**. Toggle APK / Play / publish / GitHub Release as needed.

On tag pushes, workflow `inputs.*` are null. The build step treats null like the defaults (`build_apk` / `upload_play` = true) — same pattern as [release_windows.yml](../.github/workflows/release_windows.yml). Only an explicit `false` on a manual run skips those steps.

Smoke builds (debug keystore) stay in [`android_apk_smoke.yml`](../.github/workflows/android_apk_smoke.yml).

---

## Step 1 — Create upload keystore (one-time)

If you do not already have a Play upload key:

```bash
keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep the keystore and passwords **out of git**. See [packaging.md § Android signing](packaging.md#android-signing).

For local builds, copy [`android/key.properties.example`](../android/key.properties.example) to `android/key.properties` and point `storeFile` at your keystore.

---

## Step 2 — GitHub Secrets & variables

Open the repo on GitHub → **Settings** → **Secrets and variables** → **Actions**.

### Option A — Keystore on the self-hosted runner (recommended if you already release locally)

Place `android/key.properties` and the `.jks` file on the Linux runner (same layout as local release). Set a **Repository variable**:

| Variable | Value |
|----------|-------|
| `ANDROID_USE_RUNNER_KEYSTORE` | `true` |

No keystore secrets are required. The workflow cleans up only CI-generated `ci-release-keystore.jks` when using secrets import.

### Option B — Import keystore from GitHub Secrets (portable runners)

Base64-encode the keystore on a machine that has it:

```bash
base64 -w0 release-keystore.jks   # Linux
# or: base64 -i release-keystore.jks | pbcopy   # macOS
```

| Secret name | Where to get it |
|-------------|-----------------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of your upload `.jks` / `.keystore` file |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias (e.g. `upload` from `key.properties.example`) |
| `ANDROID_KEY_PASSWORD` | Key password (often same as store password) |

Leave `ANDROID_USE_RUNNER_KEYSTORE` unset or set to `false`.

### Google Play upload (for **Upload Play** / `--play`)

| Secret name | Where to get it |
|-------------|-----------------|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` | Base64 of the GCP Play service-account JSON (see [Upload to Google Play](#upload-to-google-play)). Prefer this over raw JSON — GHA multiline env vars corrupt `private_key` newlines. |

Optional overrides (repository variables or workflow `env`): `GOOGLE_PLAY_TRACK` (default `alpha`), `GOOGLE_PLAY_RELEASE_STATUS` (default `draft`), `GOOGLE_PLAY_PACKAGE_NAME` (default `ai.enjoy.player`).

---

## Step 3 — Self-hosted runner checklist

See [ci-self-hosted-runners.md](ci-self-hosted-runners.md) for registration and labels (`self-hosted`, `Linux`).

```bash
flutter doctor
java -version   # 17+
python3 --version   # Play AAB upload (--play); ensure_linux_tooling installs python3 + python3-venv
echo "$ANDROID_SDK_ROOT"
sdkmanager "platforms;android-35" "build-tools;35.0.0"
```

---

## Step 4 — Run a release

1. Bump `version:` in `pubspec.yaml` if needed.
2. Either push a `vX.Y.Z` tag, or GitHub → **Actions** → **Release Android** → **Run workflow**.
3. For manual runs, toggle **Also build release APK**, **Upload store AAB to Google Play**, and **Publish** as needed (tag pushes enable APK + Play + publish automatically).
4. When Play upload is enabled and the service-account secret is set, confirm a **draft** release on the **alpha** (closed testing) track in Play Console.
5. Collect outputs from the runner workspace, the draft GitHub Release, or dl.enjoy.bot when publish ran:
   - `build/app/outputs/bundle/release/EnjoyPlayer-vX.Y.Z.aab`
   - `build/app/outputs/flutter-apk/EnjoyPlayer-vX.Y.Z-*.apk` (when APK step ran)

Most sideload users want **`EnjoyPlayer-vX.Y.Z-arm64-v8a.apk`** only.

---

## Upload to Google Play

CI and local releases share [`.github/scripts/upload_play_aab.sh`](../.github/scripts/upload_play_aab.sh) (Play Android Publisher API). Defaults: package `ai.enjoy.player`, track **`alpha`**, status **`draft`** — you review and roll out in Play Console.

### One-time service account setup

1. In [Google Cloud Console](https://console.cloud.google.com/), create or pick a project and enable **Google Play Android Developer API**.
2. Create a **service account**, add a **JSON key**, and download it (keep out of git).
3. In [Play Console](https://play.google.com/console/) → **Users and permissions** → **Invite new users**, paste the service account email.
4. Under app permissions for `ai.enjoy.player`, grant rights to manage releases on the **closed testing (alpha)** track (and view app information as needed).
5. Store the JSON:
   - **CI**: GitHub → Secrets → `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64`:
     ```bash
     base64 -w0 .google/play-service-account.json | gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64
     ```
   - **Local**: `export GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH="$(git rev-parse --show-toplevel)/.google/play-service-account.json"` (or set it in gitignored `publish_env.local.sh` / `.ps1`). Keep `.google/` out of git (already in `.gitignore`).

Ensure the **upload keystore** used to sign the AAB matches the upload key registered in Play Console (App signing).

### Local commands

```bash
bash .github/scripts/release.sh --platform android --play
bash .github/scripts/release.sh --platform android --publish-only --play   # existing AAB only
```

```powershell
pwsh ./release.ps1 -Platform android -Play
```

If Play credentials are unset, the script logs *Skipping Play upload* and exits successfully (same soft-skip pattern as TestFlight).

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| *Missing ANDROID_KEYSTORE_* | Add secrets or set `ANDROID_USE_RUNNER_KEYSTORE=true` with local `key.properties` |
| *ANDROID_SDK_ROOT not set* | Set `ANDROID_SDK_ROOT` in runner service environment |
| AAB signed with debug key | Signing setup failed — check secrets / `key.properties` paths |
| *Skipping Play upload* | Set `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` (CI) or `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH` (local) |
| *Invalid control character* / invalid JSON for Play SA | Use **base64** secret (`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64`), not raw JSON in a GHA env var |
| Play API 403 / permission denied | Re-check Play Console invite + closed-testing permissions for the service account |
| *signed with the wrong key* / *Android debug keystore* | AAB was not signed with the Play **upload** key. This machine needs `android/key.properties` + the upload `.jks` (SHA1 must match Play Console → Setup → App signing → Upload key). Rebuild after fixing — `--publish-only` will keep re-uploading a bad AAB. GitHub already stores `ANDROID_KEYSTORE_*`; copy that same keystore locally. |
| Upload `TimeoutError` / chunk retries exhausted | Store AAB is large (~180MB). Uploader uses resumable 8 MiB chunks with a 600s HTTP timeout; raise `GOOGLE_PLAY_UPLOAD_TIMEOUT_SEC` or `GOOGLE_PLAY_UPLOAD_CHUNK_RETRIES` if the link is slow. Retry with `--publish-only --play` (no rebuild). |
| `python3` missing | Install Python 3 on the release host; `ensure_play_upload_tooling.sh` needs it for the API client venv |
| R8 / ProGuard missing class | Extend [`proguard-rules.pro`](../android/app/proguard-rules.pro) per Gradle hint |

---

## Local release (without CI)

Same commands, documented in [packaging.md](packaging.md):

```bash
bash .github/scripts/release.sh --platform android --play
# or raw Flutter:
flutter build appbundle --release --flavor store
flutter build apk --release --split-per-abi --flavor direct
```
