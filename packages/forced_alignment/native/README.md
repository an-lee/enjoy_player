# Native eSpeak-NG artifacts

Production alignment loads **libespeak-ng** and a trimmed **espeak-ng-data**
tree at runtime (`DynamicLibrary.open`). Nothing here is compiled during
`flutter test`.

## Layout

```text
native/
  android/arm64-v8a/libespeak-ng.so
  android/armeabi-v7a/libespeak-ng.so
  android/x86_64/libespeak-ng.so
  ios/libespeak-ng.dylib            # iphoneos arm64
  ios/libespeak-ng.simulator.dylib  # iphonesimulator arm64 + x86_64
  macos/libespeak-ng.dylib          # universal: arm64 + x86_64
  windows/libespeak-ng.dll
  linux/libespeak-ng.so             # x86_64
  espeak-ng-data/                   # voices + phoneme tables for focus languages
```

A missing library or data directory is not a test failure for the app suite:
production `align` / `alignSegments` return `spokenReferenceUnavailable`.
The package's own eSpeak FFI tests (golden, native phonemize, fr-CA voice)
run **unconditionally** on host platforms that have a vendored binary — a
load failure there is a regression, not a skip.

## Provenance (eSpeak-NG 1.52.0, GPL-3.0)

| Platform | Artifact | Built from the official 1.52.0 source with |
|---|---|---|
| windows | `libespeak-ng.dll` (x64) | official eSpeak-NG 1.52.0 MSI |
| linux | `libespeak-ng.so` (x86_64) | zig cc 0.15.2 `-target x86_64-linux-gnu.2.31`; requires glibc ≥ 2.29; links only libc/libm |
| macos | `libespeak-ng.dylib` (arm64 + x86_64, min 10.15) | zig cc 0.15.2 against the MacOSX11.3 SDK; links only libSystem |
| android | `libespeak-ng.so` (arm64-v8a, armeabi-v7a, x86_64) | Android NDK r27d, API 26, `-Wl,-z,max-page-size=16384` (Play 16 KB page requirement); links only libc/libm/libdl |
| ios | `libespeak-ng.dylib` (iphoneos arm64, min 14.0) + `libespeak-ng.simulator.dylib` (arm64 + x86_64) | Xcode clang against the iPhoneOS / iPhoneSimulator SDKs; links only libSystem. Rebuild: `native/build_ios.sh` |

All builds compile the same upstream sources (`src/libespeak-ng/*.c` except
`sPlayer.c`, plus `src/ucd-tools/src/{case,categories,ctype,proplist,
scripts,tostring}.c`) with `-fvisibility=hidden -DLIBESPEAK_NG_EXPORT`
(same export discipline as the upstream Windows build), no pcaudiolib, no
speech-player. Rebuilds should keep the 1.52.0 tag and the focus-language
data tree below in lockstep.

Android app builds merge the per-ABI libraries via the app's jniLibs source
(`android/app/build.gradle.kts` points at `native/android/`, whose `<abi>/`
subfolders are exactly the jniLibs shape), and the app pubspec bundles
`espeak-ng-data/` as Flutter assets. At startup
`lib/core/platform/espeak_android_provisioner.dart` reads
`applicationInfo.nativeLibraryDir` over the `ai.enjoy.player/espeak` channel,
extracts the data assets into app-support storage (revision-marked,
idempotent), and pins both paths via `setEspeakNativePathOverrides`. Anything
missing keeps the package fail-closed (`spokenReferenceUnavailable`).

macOS and iOS app builds copy the host dylib into `Frameworks/` and the
trimmed data tree into `Contents/Resources/espeak-ng-data` (macOS) or
`Runner.app/espeak-ng-data` (iOS) via `bundle_into_app.sh`. Production
`align` resolves those bundle paths from `Platform.resolvedExecutable`
when the process is not sitting in the source tree.

## Voices (focus catalog)

`en-us`, `en-gb`, `ja`, `ko`, `es`, `es-419`, `fr-fr`, `fr-ca` — see
`lib/src/language_map.dart`. Each mapped id must have a `lang/` file.
Do not silently substitute another voice. `fr-ca` is a Canadian French
variant on the French dictionary (eSpeak-NG 1.52 ships `fr` / `fr-be` /
`fr-ch` only).

## License

eSpeak-NG is GPL-3.0. Linked into this AGPL-3.0 app; see ADR-0072 and
`docs/packaging.md`.
