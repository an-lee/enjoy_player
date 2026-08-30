# Feature: ASR transcript generation

Local audio and video can generate a time-aligned `source: ai` transcript from
the transcript empty state or the subtitle picker. The UI uses the existing
`AsrService` provider routing: Enjoy uses the worker, while BYOK routes to
Azure Speech or an OpenAI-compatible Whisper endpoint.

## Flow

`launchAsrGeneration` accepts only local library files. For media at or above
**15 minutes (900 seconds)**, a Credit-oriented confirm dialog is shown first.
Video extracts a temporary 16 kHz mono WAV through FFmpeg; audio files are read
directly. Recognition is delegated to `AsrGenerationController`.

### Enjoy path routing

The controller includes known media duration in `AsrRequest.durationSeconds`.
On the Enjoy capability:

| Duration | Path |
|---|---|
| **&lt; 900s** | Sync `multipart/form-data` Whisper short-clip (`POST /audio/transcriptions`) |
| **≥ 900s** | Upload audio to Worker (`PUT /audio/media/:media_reference`), JSON submit long-form job, poll `GET /audio/transcriptions/:job_id` until terminal (Deepgram behind the Worker) |

Long-form attempts store an idempotency key (and job id after accept) so
transport retries and app restarts can reattach without double-billing. Cancel
stops client waiting; a later Generate starts a new attempt key after terminal
failure or cancel.

**Progress reporting**: During audio extraction (FFmpeg WAV conversion on short
jobs; file read on long-form upload), the controller surfaces a `[0, 1]`
progress value via `AsrGenerationJob.progress`. The presentation layer uses this
to show a determinate progress indicator during extraction and upload phases,
replacing the previous indeterminate spinner. Long-form upload/poll phases keep
the UI interactive — see `AsrAudioExtractor.onProgress` and
`AsrGenerationController` progress wiring.

Whisper-compatible and long-form language fields normalize the user-selected
BCP-47 tag (e.g. `en-US`) to the base subtag (`en`) before sending. Omitting
language selects Worker multilingual mode for long-form.

The controller converts the `AsrResult` through `buildAsrTranscriptLines`,
persists through `TranscriptRepository.upsertAsrGeneratedTrack`, and makes it
primary.

### BYOK

BYOK Azure Speech / OpenAI Whisper is unchanged and never uses Enjoy Deepgram
long-form billing.

Re-generation uses the deterministic `enjoyTranscriptId` for
`(targetType, mediaId, language, source: ai)`, so it updates one row in place.
The previous track stays available until the replacement succeeds. If ASR
returns a detected language, both the generated track and the media row use it.

## Failure handling and performance

`AsrAudioExtractionException` carries one of `ffmpegUnavailable`,
`noAudioTrack`, `ffmpegFailed`, `fileTooLarge`, or `unsupportedSource`. The
presentation boundary maps those reasons, provider setup failures, credit
failures (including long-form preflight/settlement), provider timeout/retryable
failures, unsupported media, network failures, and no-speech results to
localized notices; raw exceptions are not displayed.

**Credits exhaustion (spec 045)**: a credits rejection keeps the
`asrErrorCreditsExhausted` lead-in and carries the parsed worker envelope on
the job (`AsrGenerationJob.creditsFailure`), so the launcher snackbar shows the
numbered message (required vs. remaining, reset time) with the
**View plans & packages** action → `/subscription` when the envelope is
present. The media item and its state are untouched — Generate can be re-run
after purchasing.

Video extraction runs through FFmpegKit on mobile/macOS and an isolate-backed
`Process.run` on Windows. Temporary WAV files are deleted after bytes have been
read. Short-clip budget remains ~60 seconds for a five-minute desktop file.
Long-form jobs are asynchronous; upload/poll phases keep the UI interactive.
