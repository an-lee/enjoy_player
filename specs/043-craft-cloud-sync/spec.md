# Feature Specification: Crafted Audio Cloud Sync

**Feature Branch**: `043-craft-cloud-sync`

**Created**: 2026-08-21

**Status**: Draft

**Input**: User description: "I craft some audios in my Android. Then I want to practice it in my Windows, but it complains that cannot find the audio file. We should fix this. For the craft artifacts, we should upload them with the audio to cloud, so we can use them in every platform. ref to the similar implementation in web app(`~/projects/enjoy`). We don't upload the local files imported, but for the crafted audios, which is not large, we should save them to cloud after users add them into library."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Practice a crafted audio on any signed-in device (Priority: P1)

A user crafts a short audio (e.g. a translated phrase, a vocabulary clip, a sentence they rephrased) on their Android phone and adds it to their library. Later, when they sign in on their Windows desktop and open that same crafted audio from the library, the audio plays immediately — without any "file not found" or "cannot find the audio file" error.

**Why this priority**: This is the core user pain that motivated the feature. Without it, every crafted audio created on one device is unplayable on any other device, defeating the purpose of having a synced library.

**Independent Test**: Can be fully tested by crafting an audio on platform A, signing in on platform B with the same account, opening the crafted audio on platform B, and confirming playback starts within a few seconds. Delivers the core cross-platform portability promise.

**Acceptance Scenarios**:

1. **Given** a user has a crafted audio in their library on device A, **When** the user signs in to a different device B (any supported platform) and opens that audio from the library, **Then** the audio begins playback without the user seeing a missing-file error.
2. **Given** a user crafts an audio on device A, **When** the user adds it to their library, **Then** the audio binary is uploaded to cloud storage in the background and a cloud reference is associated with the library entry — the user does not need to take any extra action.
3. **Given** a user crafts an audio while offline on device A, **When** the user adds it to their library, **Then** the audio remains playable locally; once the device next has network access, the audio is uploaded automatically.
4. **Given** a crafted audio already exists in the library on device B, **When** the user opens it without ever having opened it on device B before, **Then** the audio is fetched from the cloud (not from a path local to the creating device) and plays.

---

### User Story 2 — Editing a crafted audio updates the cloud copy (Priority: P2)

A user crafts a sentence, adds it to their library, then later returns to the Craft studio, edits the text or voice, and saves the updated version. The updated audio binary replaces the previous one in cloud storage so the user sees the latest version on all their devices.

**Why this priority**: Crafting is iterative — users refine translations, change voices, fix typos. If the cloud copy is not refreshed, users would see stale content on other devices, which is worse than no sync at all.

**Independent Test**: Can be tested by crafting an audio, saving it, editing it to a noticeably different version, then opening it on a different device and confirming the new content plays (not the old).

**Acceptance Scenarios**:

1. **Given** a user has a crafted audio in their library, **When** the user edits the audio in Craft studio and saves the update, **Then** the cloud copy is replaced with the new audio binary.
2. **Given** two devices are signed in to the same account and the user edits a crafted audio on device A, **When** the user opens the same audio on device B within a short time of the edit, **Then** the updated version plays.

---

### User Story 3 — Imported user files are unaffected (Priority: P2)

A user who has imported large local audio files (e.g. an hour-long podcast, their personal music collection) into their library does not see those files auto-uploaded to cloud storage just because Crafted Audio Cloud Sync exists. The feature only changes behavior for crafted audios.

**Why this priority**: Without this guardrail, the feature could surprise users by silently consuming significant cloud storage and bandwidth for files they deliberately imported as local-only.

**Independent Test**: Can be tested by importing a large local audio file on device A, signing in on device B, and confirming that the file does NOT appear (or appears as a "local only" placeholder requiring user opt-in), and that no background upload is attempted.

**Acceptance Scenarios**:

1. **Given** a user has imported a local audio file into their library, **When** the user views their library on a different device, **Then** the imported file is not present on the new device unless the user explicitly opted into cloud storage for that file.
2. **Given** a user imports a local audio file, **When** the file is added to the library, **Then** no automatic background upload of the file's binary to cloud storage occurs.

---

### User Story 4 — Storage lifecycle for deleted crafts (Priority: P3)

A user who deletes a crafted audio from their library no longer has that audio binary occupying cloud storage after the deletion propagates.

**Why this priority**: This is hygiene — without it, cloud storage would accumulate orphaned audios over time. It's lower priority because the immediate user pain is about playback, not about quota.

**Independent Test**: Can be tested by crafting an audio, confirming it appears in cloud storage, deleting it from the library, then waiting for sync and confirming it is no longer present in cloud storage.

**Acceptance Scenarios**:

1. **Given** a user has a crafted audio in their library, **When** the user deletes the crafted audio from their library, **Then** the associated cloud object is scheduled for deletion.
2. **Given** a user deletes a crafted audio while offline, **When** the device next syncs, **Then** the cloud deletion request is sent.

---

### Edge Cases

- **No network at craft time**: The crafted audio is playable locally immediately; upload is deferred and retried automatically when connectivity returns. The library entry does not lose its "cloud-synced" status — it is pending sync.
- **Cloud upload fails repeatedly**: The local audio remains playable; the user is not blocked. The cloud sync continues to retry in the background until it succeeds or the user removes the entry.
- **Same crafted audio exists on two devices independently before sync**: Because each craft produces an identical binary for the same source text + voice + language combination, a duplicate-detection mechanism ensures only one cloud object is stored, not two.
- **User edits a craft on two devices simultaneously**: The later-arriving update wins; the cloud object is overwritten with whichever version's binary arrived last.
- **Crafted audio already exists in cloud from a prior session and user re-crafts the exact same content**: No duplicate upload — the existing cloud object is reused.
- **User is not signed in when crafting**: The audio is still playable locally on the creating device, but cloud sync does not occur until the user signs in.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST upload the audio binary of a crafted audio to cloud storage when the user adds it to their library, without requiring an additional user action.
- **FR-002**: System MUST store the cloud reference (URL or equivalent identifier) for the uploaded audio alongside the crafted audio's library entry, so that other devices signed in to the same account can access the audio.
- **FR-003**: System MUST populate the existing `mediaUrl`-style field on the crafted audio's library entry when the upload completes successfully, and MUST fall back to the local file path only when no cloud reference is available.
- **FR-004**: System MUST attempt the upload at the moment of save if network is available; if the device is offline, the upload MUST be queued and retried automatically when connectivity returns.
- **FR-005**: System MUST NOT upload the audio binary of an imported user file (`provider = 'user'`) or a YouTube download (`provider = 'youtube'`) automatically. Only crafted audios (`provider = 'craft'`) are in scope.
- **FR-006**: System MUST update the cloud copy of the audio binary when a user edits and saves an existing crafted audio in Craft studio.
- **FR-007**: System MUST attempt to remove the cloud copy of the audio binary when the user deletes the corresponding crafted audio from their library.
- **FR-008**: System MUST avoid creating duplicate cloud objects when the same crafted audio is independently produced on two devices — content-based deduplication MUST be used to reuse the existing cloud object.
- **FR-009**: System MUST open and play a crafted audio on a device that does not have the local file, by downloading from the cloud reference, so that the user sees playback within a few seconds on a normal network connection.
- **FR-010**: System MUST treat crafted-audio artifacts (transcript, voice settings, etc.) as already-synced metadata; this feature only addresses the audio binary itself, which is the new piece being uploaded.
- **FR-011**: System MUST display a "syncing to cloud" / "synced to cloud" indicator for crafted audios in the library, so the user understands why playback works across devices.

### Key Entities *(include if feature involves data)*

- **Crafted Audio Library Entry**: An entry in the user's library representing an audio the user created via Craft studio. Existing attributes: title, source text, voice, language, provider (`'craft'`), local file path. New/changed: a cloud reference (URL or identifier) that makes the audio accessible from any signed-in device.
- **Cloud Audio Object**: A blob (binary) stored in cloud storage representing one crafted audio. Identified by a content-based key (so identical content from different devices maps to one object) and addressable by a cloud reference the client can use to download.
- **Cloud Sync Status**: The state of the cloud upload/download for a crafted audio entry. Possible values include: not synced (offline at craft time), syncing (upload in progress), synced (cloud reference available), failed (retrying).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% of users who craft an audio on platform A and open it on platform B (same account) successfully play the audio within 10 seconds of opening, without encountering a missing-file error.
- **SC-002**: A crafted audio added to the library on a connected device completes its cloud upload within 30 seconds for 95% of craftings that are under 5 MB in size.
- **SC-003**: 0% of imported user files (`provider = 'user'`) and 0% of YouTube downloads (`provider = 'youtube'`) have their audio binary uploaded to cloud storage automatically by this feature.
- **SC-004**: Editing a crafted audio on one device results in the updated audio playing on a second device within 60 seconds of the edit, for 95% of edits.
- **SC-005**: Crafting an audio while offline does not block the user from saving the audio to their library; the audio plays locally, and the cloud sync completes automatically within 5 minutes of the device regaining connectivity, for 90% of offline crafts.
- **SC-006**: Deleting a crafted audio from the library on a connected device results in the corresponding cloud object being removed within 5 minutes, for 95% of deletions.
- **SC-007**: When two devices independently craft the same source text + voice + language, only one cloud object is created (verified by deduplication), and both devices subsequently see the same audio.

## Assumptions

- Users who craft audios are signed in to an account that supports cloud sync; the feature only operates within signed-in user accounts. Anonymous crafting remains local-only.
- Crafted audios are short TTS outputs typically under a few megabytes, making them suitable for default-eager cloud upload. Large crafted audios (e.g. multi-paragraph narrated documents) may need a size threshold, but the v1 default is "always upload crafted audios, no size cap".
- The cloud storage backend used by the reference web app (Rails ActiveStorage with R2/S3 underlying storage) is available to the Flutter player as well; if not, an equivalent direct-upload endpoint is exposed.
- Existing infrastructure (auth, library sync engine, media source resolver) is reused; this feature adds the missing binary-upload step.
- Network bandwidth and cloud quota are not constraints that block v1 — we assume the user's account has sufficient quota for their crafted audio usage.
- The local file path resolution behavior (existing fallback to `mediaUrl` when local file is missing) is already implemented and correct; this feature only adds the missing `mediaUrl` population for crafted audios.
- The "duplicate detection" relies on content-hash equivalence: same source text + language + voice + normalized text produces the same audio binary, so a single cloud object can serve multiple library entries across devices.