# AI capabilities (Enjoy worker + BYOK)

Enjoy Player calls the Enjoy / worker HTTP surface for cloud-backed AI, and supports **Bring Your Own Key (BYOK)** per modality so learners can use their own LLM and speech credentials. See [ADR-0033](../decisions/0033-byok-ai-provider-settings.md).

## Implemented (Enjoy provider)

| Modality | Worker route | Flutter entry |
|----------|----------------|---------------|
| ASR | `POST /audio/transcriptions` | `asrServiceProvider` → `AsrCapability` |
| LLM / chat | `POST /chat/completions` | `chatServiceProvider` → `LlmCapability` |
| Translation | `POST /translations` | `translationServiceProvider` → `TranslationCapability` |
| Contextual translation | `POST /chat/completions` (learner markdown) | `contextualTranslationServiceProvider` → `ContextualTranslationCapability` → `LlmCapability` |
| Dictionary | `POST /dictionary/query` | `dictionaryServiceProvider` → `DictionaryCapability` |
| Azure token | `POST /azure/tokens` | `azureTokenApiProvider` + `azureTokenCacheProvider` (9 min TTL) |
| Pronunciation assessment | `POST /azure/tokens` + **native Azure Speech SDK** | `assessmentServiceProvider` → `EnjoyAssessmentCapability` → [`packages/azure_speech`](../../packages/azure_speech/) |
| YouTube transcripts (poll) | `POST /youtube/transcripts` | `YoutubeTranscriptsApi` → `TranscriptRepository._fetchYoutubeWorkerTranscripts` — see [transcript.md § YouTube (Worker)](transcript.md) |

### Native pronunciation plugin

- **Package**: [`packages/azure_speech/README.md`](../../packages/azure_speech/README.md) (Speech SDK wrapper; assessment, transcribe, synthesize)
- **Capability**: [`lib/features/ai/data/enjoy/enjoy_assessment_capability.dart`](../../lib/features/ai/data/enjoy/enjoy_assessment_capability.dart) (token cache + WAV path or temp file from bytes). Before calling the SDK, recordings are re-encoded via **FFmpeg** to **16 kHz mono 16-bit PCM WAV** ([`azure_assessment_wav_normalizer.dart`](../../lib/features/ai/data/azure_assessment_wav_normalizer.dart)) so legacy float / odd-RIFF WAVs do not trigger Azure **SPXERR_UNEXPECTED_EOF**. The normalizer uses an **`aresample` + `aformat` filter graph** for reliable Windows decodes, rejects silent FFmpeg output via a peak/RMS scan ([`wav_signal_peak.dart`](../../lib/core/audio/wav_signal_peak.dart)), and the capability falls back to assessing the original recording if the normalized run comes back blank.
- **Language codes**: [`lib/features/ai/data/azure_language_mapper.dart`](../../lib/features/ai/data/azure_language_mapper.dart) maps short / transcript codes to Azure locales (aligned with the browser extension mapper).
- **Persistence**: `assessment_json` stores the **decoded native SDK JSON** (PascalCase keys from `SpeechServiceResponse_JsonResult`), not `AzurePronunciationAssessmentResult.toJson()`, so `jsonEncode` round-trips correctly when reopening the assessment dialog.
- **Observability**: Logger `ai.enjoy.assessment` logs recognition status, aggregate scores, word/omission counts, and audio metadata (file name, byte size, whether FFmpeg normalization ran). All-zero aggregate scores emit a **warning** (often silent or mismatched audio vs reference, skipped normalization, or locale mismatch).

Assessment requires the native Azure Speech SDK (see [echo-mode](echo-mode.md)). **Shadow reading** exposes per-take assess + result dialog.

## BYOK provider (per-modality settings)

**Settings → AI providers** (`/settings/ai-providers`) configures Enjoy vs BYOK independently for LLM, ASR, TTS, and assessment. The screen renders a **stack of modality cards** — one per `ModalityKind` — so each surface reads as a cohesive settings page rather than four disjoint widgets.

| Modality | BYOK backends | Secret storage |
|----------|---------------|----------------|
| LLM | OpenAI-, Anthropic-, Google-compatible HTTP via `ai_sdk_dart` | `ModalityKind.llm` |
| ASR | OpenAI Whisper-compatible multipart **or** Azure Speech `transcribe` | `ModalityKind.asr` |
| TTS | OpenAI `/audio/speech` **or** Azure Speech `synthesize` | `ModalityKind.tts` |
| Assessment | Azure Speech pronunciation assessment (subscription key) | `ModalityKind.assessment` |

Translation, dictionary, and contextual translation follow the **LLM** provider when BYOK is selected (LLM-backed prompts, not Enjoy worker HTTP).

### Card layout (`ModalityProviderCard`)

Each modality is rendered through the shared [`ModalityProviderCard`](../../lib/features/ai/presentation/settings/widgets/modality_provider_card.dart) widget so the four surfaces stay visually consistent:

1. **Header** — modality icon (`auto_awesome_outlined`, `graphic_eq_rounded`, `record_voice_over_outlined`, `verified_outlined`) next to the title, subtitle, and a **provider pill** (`_ProviderPill`) that reflects the active provider (Enjoy / BYOK).
2. **Segmented provider control** — `SegmentedButton<AIProvider>` with `Enjoy AI` and `BYOK` segments. Disabled while a save is in flight.
3. **Inset BYOK panel** (`_ByokPanel`) — an `AnimatedSwitcher` reveals an inset surface when the provider switches to BYOK. Inside the panel:
   - LLM → `LlmByokForm` with a `SegmentedButton<LlmApiSpec>` for OpenAI / Anthropic / Google compatibility, plus a preset shortcut list and a "fetch models" affordance when the base URL is editable.
   - Speech (ASR / TTS) → `SpeechByokForm` with a `SegmentedButton<SpeechByokKind>` for OpenAI-compatible vs Azure Speech, switching between subscription-key fields and base-URL + model fields.
   - Assessment → `SpeechByokForm` (Azure-only, subscription key + region).
4. **Footer** — a `Divider` separator, then a quiet row with a provider-status icon, the privacy/explainer text, an optional **Remove BYOK** button (only when BYOK is already saved), and a primary **Save** button with a loading spinner.

Keys are **masked** in storage and the field shows a saved-key preview chip (e.g. `sk-…1234`) so users can confirm the secret is persisted without revealing it.

### Persistence and security

- Non-secret config: Drift settings key `ai.modality_configs_v1` (`AiModalityConfigRepository`).
- Secrets: [`ByokSecretStore`](../../lib/data/api/byok_secret_store.dart) (secure storage per modality).
- Validation: [`ByokConfigValidator`](../../lib/features/ai/domain/byok_config_validator.dart) — HTTPS base URLs only, required fields per vendor. Validation failures surface inline via `AppNotice.error` with localized keys from [`byok_validation_messages.dart`](../../lib/features/ai/presentation/settings/byok_validation_messages.dart).
- Missing secret at runtime: [`ByokNotConfiguredFailure`](../../lib/features/ai/domain/byok_not_configured_failure.dart) with localized message and link back to `/settings/ai-providers` (no silent Enjoy fallback).

### Capability routing

[`ai_capability_providers.dart`](../../lib/features/ai/application/ai_capability_providers.dart) resolves `Enjoy*Capability` vs `Byok*Capability` from `aiModalityConfigsProvider`. Feature code should use `*ServiceProvider`, not vendor HTTP in widgets.

### Error translation (`guardAiCall`)

Every `*Service` in [`ai_services.dart`](../../lib/features/ai/application/ai_services.dart) (`AsrService`, `ChatService`, `TranslationService`, `ContextualTranslationService`, `DictionaryService`, `TtsService`, `AssessmentService`) wraps its single Riverpod capability call in [`guardAiCall<T>()`](../../lib/features/ai/application/ai_api_failures.dart):

```dart
Future<AsrResult> transcribe(AsrRequest request) => guardAiCall(
      () => _ref.read(asrCapabilityProvider).transcribe(request),
    );
```

`guardAiCall` runs the body and translates any [`ApiException`](../../lib/data/api/api_exception.dart) thrown by the underlying REST client into the user-facing [`AppFailure`](../../lib/core/errors/app_failure.dart) hierarchy used by the AI presentation layer, via [`mapApiExceptionToAppFailure`](../../lib/features/ai/application/ai_api_failures.dart):

| `ApiException` | `AppFailure` |
|----------------|--------------|
| `statusCode == 401` (`isUnauthorized`) | `AuthFailure(code: AuthFailureCode.sessionRevoked)` |
| `statusCode == 402`, `byokProvider == false` | `CreditsFailure` — carries the worker 402 envelope (required / used / limit / resetAt) parsed best-effort from the response body |
| `statusCode == 402`, `byokProvider == true` | `ProviderBillingFailure` — the user's own provider rejected on billing; never shows the Enjoy subscription CTA |
| Any other | `NetworkFailure(statusCode: e.statusCode)` |

Centralising the catch means any future cross-cutting change (new `ApiException` subclasses, telemetry, context-specific failure codes) happens in one place for every AI capability instead of in N near-identical `try`/`catch` blocks. The `*ServiceProvider` access pattern at every call site is unchanged — only the service body shape differs.

#### Credits-exhausted presentation (spec 045)

Every Enjoy AI surface renders `CreditsFailure` through the shared seam in [`credits_failure_actions.dart`](../../lib/features/subscription/presentation/credits_failure_actions.dart): `creditsFailureMessage` (numbered "needs X credits, Y left today" + reset time when the envelope was parsed; generic copy otherwise), `creditsCtaLabel`, and `showCreditsFailureNotice`. Inline idioms (lookup rows, Craft cards, controller states) reuse the same builder and CTA, all pointing at `/subscription`. The worker envelope contract is documented in `specs/045-ai-credits-error-ux/contracts/worker-402-envelope.md`. The AI playground is a documented exception — it keeps raw error output for diagnostics.

Missing BYOK credentials are surfaced **before** the capability runs, by the `ByokNotConfigured*Capability` wrappers and [`ByokNotConfiguredFailure`](../../lib/features/ai/domain/byok_not_configured_failure.dart) — see [BYOK provider § Persistence and security](#persistence-and-security) above. The translation table above only applies to errors thrown by the resolved capability itself.

### Debug UI

**Settings → Developer → AI playground** shows the active provider label per modality and exercises ASR, chat, translation, dictionary, and assessment.

## Not wired yet

- **Enjoy TTS** still throws `UnimplementedError` ([`EnjoyTtsCapability`](../../lib/features/ai/data/enjoy/enjoy_tts_capability.dart)).
- **`AIProvider.local`** (on-device models) remains a typed placeholder.

## Code layout

- Domain contracts and DTO-style models: `lib/features/ai/domain/`
- Enjoy implementations: `lib/features/ai/data/enjoy/`
- BYOK implementations: `lib/features/ai/data/byok/`
- Riverpod services and capability wiring: `lib/features/ai/application/`
- Settings UI: `lib/features/ai/presentation/settings/`
  - Screen: `ai_providers_screen.dart` (privacy callout + stacked modality cards)
  - Shared modality card: `widgets/modality_provider_card.dart` (segmented provider, modality pill, inset BYOK panel, calmer footer)
  - Per-modality forms: `widgets/llm_byok_form.dart`, `widgets/speech_byok_form.dart`, `widgets/byok_api_key_field.dart`
- HTTP clients (Enjoy paths only): `lib/data/api/services/ai/`

## Consumers

Feature screens should depend on `*ServiceProvider` types in `application/`, not on `ApiClient` directly, so modality and provider selection stay in one place. Transcript dictionary lookup uses the same services — see [dictionary-lookup](dictionary-lookup.md).

## Verification

Automated: `flutter test test/features/ai/` and `packages/azure_speech/test/`. `test/features/ai/chat_service_test.dart` pins the `guardAiCall` translation by overriding `llmCapabilityProvider` with a stub that throws `ApiException 503` and asserting the future completes-with-error as an `AppFailure`. Manual BYOK scenarios: [`specs/003-byok-ai/quickstart.md`](../../specs/003-byok-ai/quickstart.md).
