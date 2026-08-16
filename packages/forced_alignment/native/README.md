# Native eSpeak-NG artifacts

Production alignment loads **libespeak-ng** and a trimmed **espeak-ng-data**
tree at runtime (`DynamicLibrary.open`). Nothing here is compiled during
`flutter test`.

## Layout

```text
native/
  android/libespeak-ng.so
  ios/libespeak-ng.dylib
  macos/libespeak-ng.dylib
  windows/libespeak-ng.dll
  linux/libespeak-ng.so
  espeak-ng-data/          # voices + phoneme tables for focus languages
```

A missing library or data directory is not a test failure. Production
`align` / `alignSegments` return `spokenReferenceUnavailable`. Quality
goldens skip when `espeakFfiIsAvailable()` is false.

Windows x64 `libespeak-ng.dll` plus a trimmed focus-language
`espeak-ng-data` tree are vendored from the official eSpeak-NG 1.52.0
MSI. Other OS binaries may be added the same way.

## Voices (focus catalog)

`en-us`, `en-gb`, `ja`, `ko`, `es`, `es-419`, `fr-fr`, `fr-ca` — see
`lib/src/language_map.dart`. Each mapped id must have a `lang/` file.
Do not silently substitute another voice. `fr-ca` is a Canadian French
variant on the French dictionary (eSpeak-NG 1.52 ships `fr` / `fr-be` /
`fr-ch` only).

## License

eSpeak-NG is GPL-3.0. Linked into this AGPL-3.0 app; see ADR-0072 and
`docs/packaging.md`.
