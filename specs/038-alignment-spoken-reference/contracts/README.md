# Contracts: Spoken Alignment Reference

Slice 2 contracts still apply ([037 contracts](../../037-alignment-engine/contracts/README.md)). This slice adds the spoken-reference production rule and one failure reason.

| Contract | Purpose |
|----------|---------|
| [align-api.md](./align-api.md) | Same `align` / `alignSegments` meaning; production success requires a spoken reference |
| [spoken-reference.md](./spoken-reference.md) | Synthesizer seam, eSpeak-NG FFI, resample, isolate rules |
| [alignment-failures.md](./alignment-failures.md) | `spokenReferenceUnavailable`; fail-closed; never stand-in success |
| [inert-product.md](./inert-product.md) | Still no Craft, panel, Settings, or playback substitution |
