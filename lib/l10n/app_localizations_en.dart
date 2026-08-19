// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Enjoy Player';

  @override
  String get libraryTitle => 'Library';

  @override
  String get librarySourceLocal => 'Local';

  @override
  String get librarySourceCloud => 'Cloud';

  @override
  String get librarySourceCloudEyebrow => 'Cloud';

  @override
  String get librarySourceSwitchSemantics => 'Library source';

  @override
  String get librarySourceToggleToCloud => 'Switch to cloud';

  @override
  String get librarySourceToggleToLocal => 'Switch to local';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeRecentMedia => 'Recent media';

  @override
  String get homeEmptyTitle => 'No recent media';

  @override
  String get homeEmptyHint => 'Import media or drop a file here to start.';

  @override
  String get libraryTabAudio => 'Audio';

  @override
  String get libraryTabVideo => 'Video';

  @override
  String get libraryEmptyAudioTitle => 'We couldn\'t find any audio';

  @override
  String get libraryEmptyAudioHint =>
      'Your library doesn\'t contain any audio content.';

  @override
  String get libraryEmptyVideoTitle => 'We couldn\'t find any videos';

  @override
  String get libraryEmptyVideoHint =>
      'Your library doesn\'t contain any video content.';

  @override
  String get librarySearchNoMatchesTitle => 'No matches';

  @override
  String get librarySearchNoMatchesHint =>
      'Nothing in your library matches this search.';

  @override
  String get librarySearchClear => 'Clear search';

  @override
  String get libraryDeleteFailed => 'Could not remove this item. Try again.';

  @override
  String get transcriptAccessibilityTranscriptList => 'Transcript';

  @override
  String transcriptAccessibilityCue(String time, String snippet) {
    return '$time. $snippet';
  }

  @override
  String get transcriptAccessibilityCurrentLine => 'Current playback line.';

  @override
  String get transcriptAccessibilityEchoRegion => 'Echo practice region.';

  @override
  String get transcriptAccessibilityEchoCurrentLine => 'Current echo line.';

  @override
  String transcriptLineRecordingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings',
      one: '1 recording',
    );
    return '$_temp0';
  }

  @override
  String get transcriptErrorFriendlyTitle => 'Transcript unavailable';

  @override
  String get transcriptErrorFriendlyHint =>
      'Try choosing another subtitle track or importing a file.';

  @override
  String get transcriptFetchingSubtitles => 'Fetching subtitles…';

  @override
  String get asrStatusExtracting => 'Extracting audio…';

  @override
  String get asrStatusUploading => 'Uploading audio…';

  @override
  String get asrLanguageTitle => 'Spoken language';

  @override
  String get asrLanguageAutoDetect => 'Auto-detect language';

  @override
  String get asrStatusRecognizing => 'Recognizing…';

  @override
  String get asrStatusPolling => 'Transcribing…';

  @override
  String get asrStatusSaving => 'Saving…';

  @override
  String get asrStatusSuccess => 'Transcript ready';

  @override
  String get asrStatusCancelled => 'Cancelled';

  @override
  String get asrErrorGeneric => 'Couldn\'t generate transcript';

  @override
  String get asrErrorFfmpegUnavailable =>
      'Audio extraction isn\'t available on this device';

  @override
  String get asrErrorFfmpegUnavailableHint =>
      'Install ffmpeg or use a different video file.';

  @override
  String get asrErrorNoAudioTrack => 'This file has no audio to transcribe';

  @override
  String get asrErrorExtractionFailed =>
      'Couldn\'t extract audio. Please try again.';

  @override
  String get asrErrorFileTooLarge => 'This file is too large to transcribe';

  @override
  String get asrErrorUnsupportedSource => 'This source isn\'t supported';

  @override
  String get asrErrorUnsupportedMedia =>
      'This audio format isn\'t supported for long transcription';

  @override
  String get asrErrorProviderTimeout =>
      'Transcription timed out. Please try again.';

  @override
  String get asrErrorProviderRetryable =>
      'Transcription failed. Please try again.';

  @override
  String get asrErrorByokMissing =>
      'Set up your AI provider to generate a transcript';

  @override
  String get asrErrorByokMissingHint =>
      'Open Settings → AI Providers to add credentials.';

  @override
  String get asrErrorCreditsExhausted => 'You\'ve used all your Enjoy credits';

  @override
  String get asrErrorCreditsExhaustedHint =>
      'Upgrade your plan to keep generating transcripts.';

  @override
  String get asrErrorNetwork =>
      'Network error. Please check your connection and retry.';

  @override
  String get asrErrorNoSpeech => 'No speech detected in this audio';

  @override
  String get asrLongMediaConfirmTitle => 'This may take a while';

  @override
  String asrLongMediaConfirmBody(int minutes) {
    return 'Generating a transcript for $minutes minutes of audio may take several minutes and consume significant credits. Continue?';
  }

  @override
  String get asrLongMediaConfirmContinue => 'Continue';

  @override
  String get asrLongMediaConfirmCancel => 'Cancel';

  @override
  String get actionOpenFiles => 'Open file(s)';

  @override
  String get actionImport => 'Import';

  @override
  String get importFromFile => 'From file…';

  @override
  String get importFromYoutube => 'From YouTube URL…';

  @override
  String get discoverTitle => 'Discover';

  @override
  String get discoverBrowseAction => 'Browse Discover';

  @override
  String get discoverRecommendedHeading => 'Recommended';

  @override
  String get discoverSubscriptionsHeading => 'Subscriptions';

  @override
  String get discoverTimelineHeading => 'Recent uploads';

  @override
  String get discoverSubscribeTitle => 'Subscribe to channel';

  @override
  String get discoverSubscribeHint => 'Paste a YouTube channel URL or @handle.';

  @override
  String get discoverSubscribePlaceholder => 'https://www.youtube.com/@channel';

  @override
  String get discoverSubscribeAction => 'Subscribe';

  @override
  String get discoverSubscribed => 'Subscribed to channel';

  @override
  String get discoverSubscribedLabel => 'Subscribed';

  @override
  String get discoverSubscribeFailed => 'Could not subscribe to that channel.';

  @override
  String get discoverUnsubscribeAction => 'Unsubscribe';

  @override
  String get discoverUnsubscribed => 'Unsubscribed from channel';

  @override
  String get discoverViewFeed => 'View feed';

  @override
  String get discoverAddToLibrary => 'Add to library';

  @override
  String get discoverAddedToLibrary => 'Added to your library';

  @override
  String get discoverAddFailed => 'Could not add this video.';

  @override
  String get discoverInLibrary => 'In library';

  @override
  String get discoverPlay => 'Play';

  @override
  String get discoverFeedEmptyTitle => 'No videos in feed yet';

  @override
  String get discoverFeedEmptyHint =>
      'Subscribe to a channel and refresh to load recent uploads.';

  @override
  String get discoverFeedErrorTitle => 'Could not load feed';

  @override
  String get discoverFeedErrorHint => 'Check your connection and try again.';

  @override
  String get discoverRetry => 'Retry';

  @override
  String get discoverRefreshPartialFailed =>
      'Some channel feeds could not be refreshed.';

  @override
  String discoverRefreshPartialFailedDetail(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels',
      one: '1 channel',
    );
    return 'Could not refresh $_temp0: $names';
  }

  @override
  String discoverRefreshSingleFailed(Object name) {
    return 'Could not refresh $name.';
  }

  @override
  String get discoverRecommendedLoadFailed =>
      'Could not load recommended channels.';

  @override
  String get discoverSubscriptionsLoadFailed => 'Could not load subscriptions.';

  @override
  String get discoverNoSubscriptionsHint =>
      'Subscribe to a recommended channel or paste a channel URL.';

  @override
  String get discoverManageChannels => 'Manage channels';

  @override
  String get discoverFilterAll => 'All';

  @override
  String get discoverYourChannelsHeading => 'Your channels';

  @override
  String get discoverRecommendedAllSubscribed =>
      'You are subscribed to all recommended channels.';

  @override
  String get discoverSourceNotFound =>
      'This YouTube source could not be found.';

  @override
  String get discoverSourceUnavailable =>
      'This source is no longer available (deleted or private).';

  @override
  String get discoverNetworkError =>
      'No internet connection. Check your network and try again.';

  @override
  String get discoverWorkerError =>
      'Could not reach the feed server. Try again later.';

  @override
  String get discoverInvalidUrl =>
      'Could not read a valid YouTube URL. Try a channel, @handle, or playlist link.';

  @override
  String get discoverAlreadySubscribed => 'Already subscribed to this source.';

  @override
  String get discoverSourceTypeChannel => 'Channel';

  @override
  String get discoverSourceTypePlaylist => 'Playlist';

  @override
  String get youtubeImportTitle => 'Import YouTube video';

  @override
  String get youtubeImportHint => 'Paste a YouTube link or video ID';

  @override
  String get youtubeImportInvalid => 'Could not read a valid YouTube video ID.';

  @override
  String get youtubeImporting => 'Adding video…';

  @override
  String get youtubeBadge => 'YouTube';

  @override
  String get youtubeLoginTooltip => 'YouTube account';

  @override
  String get youtubeOpenInBrowser => 'Open in browser';

  @override
  String get youtubeLoginClose => 'Close';

  @override
  String get youtubeLoginScreenTitle => 'YouTube sign-in';

  @override
  String get youtubeLogout => 'Sign out (clear cookies)';

  @override
  String get youtubeTapToPlayHint => 'Tap the video to play';

  @override
  String get searchHint => 'Search';

  @override
  String get transportRepeat => 'Repeat';

  @override
  String get transportFullscreen => 'Fullscreen';

  @override
  String get transportExitFullscreen => 'Exit fullscreen';

  @override
  String get transportMore => 'More';

  @override
  String get transportCollapse => 'Collapse player';

  @override
  String get transportExpand => 'Expand player';

  @override
  String get transportDismissPlayer => 'Close player';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get importMedia => 'Import media';

  @override
  String get importingMedia => 'Importing media…';

  @override
  String get importMediaFailed => 'Could not import this file.';

  @override
  String get importUnsupportedFileType =>
      'This file type isn’t supported. Choose an audio or video file.';

  @override
  String get noMediaYet => 'No media yet';

  @override
  String get tapImportToAdd => 'Import audio or video from the toolbar.';

  @override
  String get navMainLabel => 'Primary navigation';

  @override
  String get miniPlayerMediaVideo => 'Video';

  @override
  String get miniPlayerMediaAudio => 'Audio';

  @override
  String get retry => 'Retry';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsAppearanceSubtitle =>
      'Theme follows your system settings.';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsAboutSubtitle =>
      'Enjoy Player — local transcripts and shadow reading.';

  @override
  String get settingsThemeRowTitle => 'Theme';

  @override
  String get settingsThemeDarkLocked => 'Follows your system appearance.';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get previousLine => 'Previous line';

  @override
  String get nextLine => 'Next line';

  @override
  String get replayLine => 'Replay line';

  @override
  String get echoMode => 'Echo mode';

  @override
  String get exitEchoMode => 'Exit echo mode';

  @override
  String get transcript => 'Transcript';

  @override
  String get transcriptNowReading => 'Now reading';

  @override
  String get playerTranscriptResizeHint =>
      'Drag to resize the transcript panel';

  @override
  String get importSubtitle => 'Import subtitle';

  @override
  String get noTranscript => 'No transcript yet';

  @override
  String get importSrtOrVtt => 'Import an .srt or .vtt file.';

  @override
  String get miniPlayerOpen => 'Open player';

  @override
  String get loading => 'Loading…';

  @override
  String get error => 'Error';

  @override
  String get playerOpenGenericError => 'Could not open this item.';

  @override
  String playbackRateTimes(String rate) {
    return '${rate}x';
  }

  @override
  String get speed => 'Speed';

  @override
  String get volume => 'Volume';

  @override
  String get transportMute => 'Mute';

  @override
  String get transportUnmute => 'Unmute';

  @override
  String get repeatNone => 'Repeat off';

  @override
  String get repeatSegment => 'Repeat segment';

  @override
  String get settingsPlaceholder => 'Player preferences will appear here.';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get subtitlesPrimary => 'Primary';

  @override
  String get subtitlesTranslation => 'Translation (optional)';

  @override
  String get subtitlesNone => 'None';

  @override
  String get subtitlesNotSelected => 'Not selected';

  @override
  String get subtitlesImportFile => 'Import subtitle file…';

  @override
  String get subtitlesDeleteTrack => 'Delete track';

  @override
  String get importSubtitleSuccess => 'Subtitle imported';

  @override
  String get noTranscriptHint =>
      'Add a subtitle file, extract embedded captions, or create an AI transcript.';

  @override
  String get noTranscriptHintRemote =>
      'Cloud captions load automatically when available. Open the CC menu to refresh.';

  @override
  String get transcriptEmptyExtract => 'Extract';

  @override
  String get transcriptEmptyAddSubtitle => 'Add subtitle';

  @override
  String get transcriptEmptyGenerate => 'AI transcript';

  @override
  String get subtitlesGenerate => 'AI transcript';

  @override
  String get subtitlesRegenerate => 'Re-generate transcript';

  @override
  String get subtitlesExtractEmbedded => 'Extract embedded subtitles';

  @override
  String get subtitlesRefreshCloud => 'Refresh transcripts from cloud';

  @override
  String get subtitlesImportLanguageTitle => 'Subtitle language';

  @override
  String get subtitlesImportLanguageHint =>
      'BCP-47 code (e.g. en, zh-TW). Use und if unknown.';

  @override
  String get subtitlesImportLanguageFieldLabel => 'Language code';

  @override
  String get subtitlesProviderOfficial => 'Official';

  @override
  String get subtitlesProviderAuto => 'Auto';

  @override
  String get subtitlesProviderAi => 'AI';

  @override
  String get subtitlesProviderUser => 'User';

  @override
  String get subtitlesAutoTranslate => 'Auto translate';

  @override
  String subtitlesAutoTranslateLanguageChip(String language) {
    return 'To $language';
  }

  @override
  String get subtitlesAutoTranslateRetranslateLine => 'Re-translate this line';

  @override
  String get subtitlesAutoTranslateBlockedStalePrimary =>
      'The primary subtitle changed. Auto translate will rebuild from the new primary.';

  @override
  String get subtitlesAutoTranslateLineFailed => 'Couldn’t translate this line';

  @override
  String get subtitlesAutoTranslatePendingLine => 'Translating…';

  @override
  String get subtitlesAutoTranslateBlockedSignedOut =>
      'Sign in to use auto translate.';

  @override
  String get subtitlesAutoTranslateBlockedSameLanguage =>
      'Auto translate is not needed when your native language matches the primary subtitle.';

  @override
  String get subtitlesAutoTranslateBlockedNoPrimary =>
      'Choose a primary subtitle first.';

  @override
  String get subtitlesAutoTranslateBlockedCredits =>
      'Not enough credits to translate. Check your subscription.';

  @override
  String get subtitlesExtractNoTracks =>
      'No embedded subtitle tracks in this file (only video and audio). If you have a separate .srt or .vtt, use Import file.';

  @override
  String subtitlesExtractedCount(int count) {
    return 'Extracted $count subtitle track(s).';
  }

  @override
  String get subtitlesRefreshDone => 'Transcripts updated from cloud.';

  @override
  String get subtitlesNoPlayableUri =>
      'Could not resolve a playable file for this item.';

  @override
  String get expandEchoBackward => 'Expand echo backward';

  @override
  String get expandEchoForward => 'Expand echo forward';

  @override
  String get shrinkEchoBackward => 'Shrink echo backward';

  @override
  String get shrinkEchoForward => 'Shrink echo forward';

  @override
  String get shadowReadingTitle => 'Shadow reading';

  @override
  String get shadowReadingHint =>
      'Practice speaking along this segment. Record your voice and compare pitch with the reference.';

  @override
  String get shadowReadingReferenceSnippet => 'Reference';

  @override
  String get pitchContourTitle => 'Pitch contour';

  @override
  String get pitchContourError => 'Could not analyze pitch for this segment.';

  @override
  String get pitchContourWaveform => 'Waveform';

  @override
  String get pitchContourReference => 'Reference pitch';

  @override
  String get pitchContourUser => 'Your pitch';

  @override
  String get pitchContourAnalyzing => 'Analyzing pitch…';

  @override
  String get shadowRecordingExisting => 'Saved takes';

  @override
  String get shadowRecordingEmpty => 'No recordings for this segment yet.';

  @override
  String get shadowRecordingTake => 'Take';

  @override
  String get shadowRecordingPlay => 'Play';

  @override
  String get shadowRecordingPause => 'Pause';

  @override
  String get shadowRecordingChooseTake => 'Switch take';

  @override
  String get shadowRecordingDelete => 'Delete';

  @override
  String get shadowRecordingDeleteConfirmTitle => 'Delete this take?';

  @override
  String shadowRecordingDeleteConfirmMessage(String takeLabel) {
    return '$takeLabel will be permanently deleted. This cannot be undone.';
  }

  @override
  String get shadowRecordingRecord => 'Record';

  @override
  String get shadowRecordingStop => 'Stop';

  @override
  String get shadowRecordingMicDenied =>
      'Microphone permission is required to record.';

  @override
  String shadowRecordingSaveFailed(String reason) {
    return 'Couldn\'t save recording: $reason';
  }

  @override
  String get settingsSectionAi => 'AI';

  @override
  String get settingsSectionAiHint =>
      'Choose Enjoy AI or bring your own API keys.';

  @override
  String get settingsAiProvidersTileTitle => 'AI providers';

  @override
  String get settingsAiProvidersTileSubtitle =>
      'Enjoy AI by default, or use your own keys per feature';

  @override
  String get settingsAiProvidersTitle => 'AI providers';

  @override
  String get settingsAiProvidersSubtitle =>
      'Configure how Enjoy Player calls AI for each feature.';

  @override
  String get settingsAiProvidersPrivacyNotice =>
      'API keys are stored securely on this device only and are never synced to Enjoy cloud.';

  @override
  String get settingsAiProvidersEnjoyAi => 'Enjoy AI';

  @override
  String get settingsAiProvidersByok => 'Your API key';

  @override
  String get settingsAiProvidersModalityLlm => 'Language models';

  @override
  String get settingsAiProvidersModalityLlmHint =>
      'Chat, translation, dictionary, and contextual translation';

  @override
  String get settingsAiProvidersModalityAsr => 'Speech recognition';

  @override
  String get settingsAiProvidersModalityAsrHint => 'Transcribe audio to text';

  @override
  String get settingsAiProvidersModalityTts => 'Text-to-speech';

  @override
  String get settingsAiProvidersModalityTtsHint =>
      'Synthesize spoken audio from text';

  @override
  String get settingsAiProvidersModalityAssessment =>
      'Pronunciation assessment';

  @override
  String get settingsAiProvidersModalityAssessmentHint =>
      'Score shadow-reading takes with Azure Speech';

  @override
  String get settingsAiProvidersLlmSpecLabel => 'Protocol';

  @override
  String get settingsAiProvidersLlmSpecOpenAi => 'OpenAI-compatible';

  @override
  String get settingsAiProvidersLlmSpecAnthropic => 'Anthropic-compatible';

  @override
  String get settingsAiProvidersLlmSpecGoogle => 'Google-compatible';

  @override
  String get settingsAiProvidersPresetsLabel => 'Presets';

  @override
  String get settingsAiProvidersBaseUrlLabel => 'Base URL';

  @override
  String get settingsAiProvidersBaseUrlHint => 'https://api.example.com/v1';

  @override
  String get settingsAiProvidersApiKeyLabel => 'API key';

  @override
  String get settingsAiProvidersApiKeyExistingHint =>
      'Leave blank to keep saved key';

  @override
  String get settingsAiProvidersShowApiKey => 'Show API key';

  @override
  String get settingsAiProvidersHideApiKey => 'Hide API key';

  @override
  String get settingsAiProvidersModelLabel => 'Model';

  @override
  String get settingsAiProvidersFetchModels => 'Fetch models';

  @override
  String get settingsAiProvidersFetchedModelsLabel => 'Fetched models';

  @override
  String get settingsAiProvidersFetchModelsFailed =>
      'Could not fetch models. Check base URL and API key.';

  @override
  String get settingsAiProvidersFetchModelsEmpty =>
      'No models returned from this endpoint.';

  @override
  String get settingsAiProvidersSave => 'Save';

  @override
  String get settingsAiProvidersSaveSuccess => 'AI provider settings saved.';

  @override
  String get settingsAiProvidersRemoveByok => 'Remove BYOK';

  @override
  String get settingsAiProvidersRemoveByokTitle => 'Remove BYOK credentials?';

  @override
  String get settingsAiProvidersRemoveByokBody =>
      'This deletes the saved API key on this device and reverts the feature to Enjoy AI.';

  @override
  String get settingsAiProvidersRemoveByokSuccess =>
      'BYOK credentials removed.';

  @override
  String get settingsAiProvidersCancel => 'Cancel';

  @override
  String get settingsAiProvidersComingSoon =>
      'BYOK configuration for this feature is coming soon.';

  @override
  String get settingsAiProvidersSpeechSubscriptionKeyLabel =>
      'Azure subscription key';

  @override
  String get settingsAiProvidersSpeechRegionLabel => 'Azure region';

  @override
  String get settingsAiProvidersSpeechRegionHint => 'eastus';

  @override
  String get settingsAiProvidersSpeechKindLabel => 'Vendor';

  @override
  String get settingsAiProvidersSpeechKindOpenAi => 'OpenAI Whisper';

  @override
  String get settingsAiProvidersSpeechKindAzure => 'Azure Speech';

  @override
  String get settingsAiProvidersSpeechWhisperModelLabel => 'Whisper model';

  @override
  String get settingsAiProvidersSpeechWhisperModelHint => 'whisper-1';

  @override
  String get settingsAiProvidersSpeechTtsModelLabel => 'TTS model';

  @override
  String get settingsAiProvidersSpeechTtsModelHint => 'tts-1';

  @override
  String get settingsAiProvidersApiKeySavedMask => '••••••••••••';

  @override
  String get settingsAiProvidersApiKeyEdit => 'Edit key';

  @override
  String byokNotConfiguredMessage(String modality) {
    return 'BYOK is selected for $modality, but no API key is saved on this device.';
  }

  @override
  String get byokNotConfiguredOpenSettings =>
      'Open Settings → AI providers to add your key.';

  @override
  String get byokValidationApiKeyRequired => 'API key is required.';

  @override
  String get byokValidationBaseUrlRequired => 'Base URL is required.';

  @override
  String get byokValidationBaseUrlInvalid =>
      'Base URL must be a public HTTPS endpoint.';

  @override
  String get byokValidationModelRequired => 'Model is required.';

  @override
  String get byokValidationRegionRequired => 'Azure region is required.';

  @override
  String get byokValidationApiSpecRequired =>
      'Protocol configuration is incomplete.';

  @override
  String get byokValidationAzureKindRequired =>
      'Assessment BYOK requires Azure Speech.';

  @override
  String get settingsSectionRecording => 'Recording';

  @override
  String get settingsSectionRecordingHint =>
      'Microphone used for shadow-reading takes.';

  @override
  String get settingsSectionTranscript => 'Transcript';

  @override
  String get settingsSectionTranscriptHint =>
      'Options for practice transcript timing.';

  @override
  String get settingsTranscriptEnrichmentTitle => 'Enrich Craft word timings';

  @override
  String get settingsTranscriptEnrichmentSubtitle =>
      'When on, Craft save stores word and phone times from on-device alignment. Off (default) keeps today’s synthesis line timings.';

  @override
  String get settingsTranscriptKaraokeTitle => 'Highlight current word';

  @override
  String get settingsTranscriptKaraokeSubtitle =>
      'Highlight the spoken word when word timings exist.';

  @override
  String get settingsTranscriptIpaOverlayTitle => 'Show pronunciation (IPA)';

  @override
  String get settingsTranscriptIpaOverlaySubtitle =>
      'Show IPA under words; tap to play.';

  @override
  String get transcriptDisplaySettingsTitle => 'Transcript display';

  @override
  String get transcriptIpaUnavailableHint => 'Generate pronunciation first.';

  @override
  String get transcriptKaraokeUnavailableHint => 'Generate word timings first.';

  @override
  String get transcriptKaraokeUnavailableRemoteHint =>
      'Karaoke needs word timings from a local file.';

  @override
  String get transcriptEnrichOwnedTitle =>
      'Generate word timings and pronunciation';

  @override
  String get transcriptEnrichOwnedSubtitle =>
      'Uses this item\'s audio. Playback stays available.';

  @override
  String get transcriptEnrichYoutubeTitle => 'Generate pronunciation';

  @override
  String get transcriptEnrichYoutubeSubtitle =>
      'Karaoke stays unavailable. The video is not downloaded.';

  @override
  String get transcriptEnrichCancel => 'Cancel generation';

  @override
  String get transcriptEnrichRetry => 'Try generating again';

  @override
  String get transcriptEnrichFailed => 'Couldn\'t generate. Tap to try again.';

  @override
  String get transcriptEnrichWorking => 'Generating…';

  @override
  String transcriptEnrichProgress(int completed, int total) {
    return '$completed of $total';
  }

  @override
  String get settingsRecordingMicTitle => 'Microphone';

  @override
  String settingsRecordingMicAuto(String label) {
    return 'Auto · $label';
  }

  @override
  String get settingsRecordingMicAutoNoDevice => 'Auto · system default';

  @override
  String get settingsRecordingMicEmpty => 'No microphones detected';

  @override
  String get settingsRecordingMicAutoOption => 'Auto (skip virtual mics)';

  @override
  String get settingsRecordingMicDialogTitle => 'Choose microphone';

  @override
  String get shadowRecordingSilentWarning =>
      'No microphone signal detected. Open Settings → Recording to pick a different microphone.';

  @override
  String get shadowRecordingPlaybackFailed => 'Couldn\'t play this take.';

  @override
  String shadowRecordingOverTarget(String seconds) {
    return '+${seconds}s over target';
  }

  @override
  String shadowRecordingElapsedSemantics(String elapsed, String target) {
    return '$elapsed seconds elapsed of $target seconds target';
  }

  @override
  String shadowRecordingElapsedCountdown(String elapsed, String target) {
    return '$elapsed s / $target s';
  }

  @override
  String shadowRecordingElapsedSeconds(String elapsed) {
    return '$elapsed s';
  }

  @override
  String get shadowRecordingFileNotFound => 'Recording file was not found.';

  @override
  String get hotkeysTitle => 'Keyboard shortcuts';

  @override
  String get hotkeysHintFooter => 'Press Shift+/ (?) to open this list.';

  @override
  String get hotkeysCustomizedBadge => 'Custom';

  @override
  String get hotkeysSectionKeyboard => 'Keyboard shortcuts';

  @override
  String get hotkeysResetBinding => 'Reset';

  @override
  String get hotkeysResetAll => 'Reset all shortcuts';

  @override
  String get hotkeysResetAllConfirmTitle => 'Reset all shortcuts?';

  @override
  String get hotkeysResetAllConfirmMessage =>
      'This restores every shortcut to its default binding. Custom bindings cannot be undone.';

  @override
  String get hotkeysCaptureTitle => 'Press new shortcut';

  @override
  String get hotkeysCaptureHint => 'Press a key combination. Escape cancels.';

  @override
  String get hotkeysConflictError => 'That shortcut is already used.';

  @override
  String get hotkeysScopeGlobal => 'Global';

  @override
  String get hotkeysScopePlayer => 'Player';

  @override
  String get hotkeysScopeLibrary => 'Library';

  @override
  String get hotkeysScopeModal => 'Modal';

  @override
  String get hotkeysDescHelp => 'Show keyboard shortcuts';

  @override
  String get hotkeysDescSearch => 'Open search';

  @override
  String get hotkeysDescSettings => 'Open settings';

  @override
  String get hotkeysDescCraft => 'Open Craft';

  @override
  String get hotkeysDescTogglePlay => 'Play / Pause';

  @override
  String get hotkeysDescToggleExpand => 'Toggle player expand/collapse';

  @override
  String get hotkeysDescToggleFullscreen => 'Toggle fullscreen';

  @override
  String get hotkeysDescPrevLine => 'Play previous line';

  @override
  String get hotkeysDescNextLine => 'Play next line';

  @override
  String get hotkeysDescReplayLine => 'Replay current line';

  @override
  String get hotkeysDescToggleEchoMode => 'Toggle Echo mode';

  @override
  String get hotkeysDescToggleBlurPractice =>
      'Toggle listening-focus (blur practice)';

  @override
  String get hotkeysDescToggleRecording => 'Start/Stop recording';

  @override
  String get hotkeysDescToggleAssessment =>
      'Show/Hide pronunciation assessment';

  @override
  String get hotkeysDescTogglePitchContour => 'Show/Hide pitch contour';

  @override
  String get hotkeysDescPlayRecording => 'Play/Pause recording';

  @override
  String get hotkeysDescSlowDown => 'Slow down playback speed';

  @override
  String get hotkeysDescSpeedUp => 'Speed up playback speed';

  @override
  String get hotkeysDescExpandEchoBackward => 'Expand Echo region backward';

  @override
  String get hotkeysDescExpandEchoForward => 'Expand Echo region forward';

  @override
  String get hotkeysDescShrinkEchoBackward => 'Shrink Echo region backward';

  @override
  String get hotkeysDescShrinkEchoForward => 'Shrink Echo region forward';

  @override
  String get hotkeysDescLibrarySearch => 'Focus search';

  @override
  String get hotkeysDescCloseModal =>
      'Close overlay, exit fullscreen, or cancel recording';

  @override
  String get hotkeysStubSearch => 'Search is not available yet.';

  @override
  String get assessmentTitle => 'Pronunciation assessment';

  @override
  String get assessmentDescription => 'Detailed scoring for your reading.';

  @override
  String get assessmentRun => 'Run pronunciation assessment';

  @override
  String get assessmentView => 'View pronunciation assessment';

  @override
  String get assessmentReassess => 'Re-assess';

  @override
  String get assessmentOverallScore => 'Overall score';

  @override
  String get assessmentAccuracy => 'Accuracy';

  @override
  String get assessmentCompleteness => 'Completeness';

  @override
  String get assessmentFluency => 'Fluency';

  @override
  String get assessmentProsody => 'Prosody';

  @override
  String get assessmentPronunciationAnalysis => 'Pronunciation analysis';

  @override
  String get assessmentAccuracyScore => 'Accuracy score';

  @override
  String get assessmentSyllables => 'Syllables';

  @override
  String get assessmentPhonemes => 'Phonemes';

  @override
  String get assessmentNoRecording => 'Recording file is missing or empty.';

  @override
  String get assessmentNoResultSummary =>
      'No detailed scores are available for this take.';

  @override
  String assessmentRunFailed(String reason) {
    return 'Couldn\'t run assessment: $reason';
  }

  @override
  String get assessmentErrorTypeOmission => 'Omission';

  @override
  String get assessmentErrorTypeInsertion => 'Insertion';

  @override
  String get assessmentErrorTypeMispronunciation => 'Mispronunciation';

  @override
  String get assessmentErrorTypeUnexpectedBreak => 'Unexpected break';

  @override
  String get assessmentErrorTypeMissingBreak => 'Missing break';

  @override
  String get assessmentErrorTypeMonotone => 'Monotone';

  @override
  String get assessmentErrorTypeCorrect => 'Correct';

  @override
  String get assessmentErrorExplOmission =>
      'This word was expected but not detected.';

  @override
  String get assessmentErrorExplInsertion =>
      'Extra word detected that wasn\'t in the reference.';

  @override
  String get assessmentErrorExplMispronunciation =>
      'This word may have been pronounced incorrectly.';

  @override
  String get assessmentErrorExplUnexpectedBreak =>
      'Unexpected pause detected before this word.';

  @override
  String get assessmentErrorExplMissingBreak =>
      'Expected pause was not detected before this word.';

  @override
  String get assessmentErrorExplMonotone =>
      'Pitch variation was lower than expected.';

  @override
  String get assessmentErrorExplCorrect => 'No issues detected for this word.';

  @override
  String get assessmentEmptyReference => 'Reference text is empty.';

  @override
  String get assessmentInvalidStored =>
      'Stored assessment data could not be read.';

  @override
  String get authSignInTitle => 'Welcome to Enjoy';

  @override
  String get authSignInSubtitle =>
      'Sign in to sync your library, track learning progress, and pick up where you left off.';

  @override
  String get authSignInCta => 'Continue';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authContinueWithEmail => 'Continue with Email';

  @override
  String get authOtherSignInOptions => 'Other sign-in options';

  @override
  String get authOrDivider => 'or';

  @override
  String get authEmailPrompt => 'We will send a one-time code to your email.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailInvalid => 'Enter a valid email address.';

  @override
  String get authSendOtp => 'Send code';

  @override
  String get authOtpTitle => 'Enter verification code';

  @override
  String authOtpSentTo(String email) {
    return 'Code sent to $email';
  }

  @override
  String get authOtpLabel => '6-digit code';

  @override
  String get authOtpInputSemantics => 'One-time passcode';

  @override
  String get authVerifyOtp => 'Verify';

  @override
  String get authOtpResend => 'Resend code';

  @override
  String authOtpResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authChangeEmail => 'Change email';

  @override
  String get authOtpResumeTitle => 'Finish signing in';

  @override
  String authOtpResumeSubtitle(String email) {
    return 'Enter the verification code sent to $email';
  }

  @override
  String get authOtpResumeAction => 'Continue verification';

  @override
  String get authWebSignInWaiting => 'Complete sign-in in your browser…';

  @override
  String get authWaitingForApproval => 'Finishing sign-in…';

  @override
  String get authCancel => 'Cancel';

  @override
  String get authSignedInSuccess => 'Signed in successfully';

  @override
  String get authReloadSignInPage => 'Reload sign-in page';

  @override
  String get authOpenInSystemBrowser => 'Open in system browser';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileRefreshTooltip => 'Refresh profile';

  @override
  String get profileFieldName => 'Username';

  @override
  String get profileFieldEmail => 'Email';

  @override
  String get profileFieldEnjoyId => 'Enjoy ID';

  @override
  String get profileFieldMixinId => 'Mixin ID';

  @override
  String get profileMixinNotLinked => 'Not linked';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileEditEntry => 'Edit profile';

  @override
  String get profileEditEntryHint => 'Username, avatar, and account IDs';

  @override
  String get profileChangeAvatar => 'Change avatar';

  @override
  String get profileAvatarTooLarge => 'Avatar must be 2 MB or smaller';

  @override
  String get profileAvatarUnsupportedType =>
      'Avatar must be JPEG, PNG, or WebP';

  @override
  String get profileAvatarEmpty => 'Choose an image to upload';

  @override
  String get profileAvatarUploadFailed => 'Could not upload avatar. Try again.';

  @override
  String get profileCopied => 'Copied';

  @override
  String get profileFieldGoal => 'Daily goal (minutes)';

  @override
  String get profileFieldLearningLanguage => 'Learning language';

  @override
  String get profileFieldNativeLanguage => 'Native language';

  @override
  String get profileFieldRequired => 'Required';

  @override
  String get profileSave => 'Save';

  @override
  String get profileSaveSuccess => 'Profile saved';

  @override
  String get profileSubscriptionFree => 'Free';

  @override
  String get profileSubscriptionPro => 'Pro';

  @override
  String profileCreditsAvailable(String available, String limit) {
    return 'Credits today: $available / $limit';
  }

  @override
  String get profileStatTodayTitle => 'Today';

  @override
  String get profileStatWeekTitle => 'This week';

  @override
  String get profileStatMonthTitle => 'This month';

  @override
  String get profileSectionPractice => 'Practice';

  @override
  String get profileSectionPracticeHint =>
      'Synced practice time from your account';

  @override
  String get profileCreditsUsageTile => 'Credits usage';

  @override
  String get profileCreditsUsageSubtitle =>
      'View AI credits consumption from your account';

  @override
  String get profileSectionAccount => 'Account';

  @override
  String get profileSectionAccountHint => 'Daily credits and usage history';

  @override
  String get profileSectionPreferences => 'Preferences';

  @override
  String get profileSectionPreferencesHint =>
      'Daily goal and language settings';

  @override
  String get profileSignOutConfirmTitle => 'Sign out?';

  @override
  String get profileSignOutConfirmMessage =>
      'You will need to sign in again to sync and use AI features.';

  @override
  String get profileSubscriptionTile => 'Subscription';

  @override
  String get profileSubscriptionSubtitle => 'View your plan and upgrade to Pro';

  @override
  String get subscriptionTitle => 'Subscription';

  @override
  String get subscriptionDescription =>
      'Manage your subscription plan and Pro benefits.';

  @override
  String get subscriptionErrorLoading => 'Failed to load subscription status';

  @override
  String get subscriptionStatusCardTitle => 'Subscription status';

  @override
  String get subscriptionCurrentPlan => 'Current plan';

  @override
  String get subscriptionStatusTier => 'Tier';

  @override
  String get subscriptionStatusActive => 'Status';

  @override
  String get subscriptionActive => 'Active';

  @override
  String get subscriptionInactive => 'Inactive';

  @override
  String get subscriptionStatusExpiration => 'Expiration';

  @override
  String get subscriptionNeverExpires => 'Never expires';

  @override
  String subscriptionExpiresOn(String date) {
    return 'Expires on $date';
  }

  @override
  String get subscriptionStatusCreditsLimit => 'Daily credits limit';

  @override
  String subscriptionDailyCredits(String count) {
    return '$count credits';
  }

  @override
  String get subscriptionTierComparisonTitle => 'Choose your plan';

  @override
  String get subscriptionTierFreeName => 'Free';

  @override
  String get subscriptionTierFreeDescription => 'Perfect for light usage';

  @override
  String get subscriptionTierFreePrice => 'Free';

  @override
  String get subscriptionTierFreeDailyCredits => '1,000 credits/day';

  @override
  String get subscriptionTierLiteName => 'Lite';

  @override
  String get subscriptionTierLiteDescription => 'For daily learners';

  @override
  String get subscriptionTierLitePrice => '1.99 USD/month';

  @override
  String get subscriptionTierLiteDailyCredits =>
      '12,000 credits/day (12× Free)';

  @override
  String get subscriptionTierProName => 'Pro';

  @override
  String get subscriptionTierProDescription => 'For serious learners';

  @override
  String get subscriptionTierProPrice => '9.99 USD/month';

  @override
  String get subscriptionTierProDailyCredits => '60,000 credits/day (60× Free)';

  @override
  String get subscriptionFeatureTranslation => 'Translation';

  @override
  String get subscriptionFeatureSmartTranslation => 'Smart translation';

  @override
  String get subscriptionFeatureDictionary => 'Dictionary';

  @override
  String get subscriptionFeatureAsr => 'Speech recognition';

  @override
  String get subscriptionFeatureTts => 'Speech synthesis';

  @override
  String get subscriptionFeatureAssessment => 'Pronunciation assessment';

  @override
  String get subscriptionFeaturePaidFlashcards =>
      'Download vocabulary flashcards';

  @override
  String get subscriptionFeaturePaidMoreComing => 'More features coming';

  @override
  String get subscriptionUpgrade => 'Upgrade to Pro';

  @override
  String get subscriptionUpgradeShort => 'Upgrade';

  @override
  String get subscriptionRecommendedPlan => 'Recommended';

  @override
  String get subscriptionExtend => 'Extend subscription';

  @override
  String get subscriptionPurchaseTitle => 'Purchase Pro subscription';

  @override
  String get subscriptionPurchaseSelectDuration => 'Select duration';

  @override
  String get subscriptionPurchaseDuration => 'Duration';

  @override
  String get subscriptionPurchaseOneMonth => '1 month';

  @override
  String get subscriptionPurchaseOneSeason => '1 season';

  @override
  String get subscriptionPurchaseOneYear => '1 year';

  @override
  String get subscriptionPurchaseCustomDuration => 'Custom';

  @override
  String get subscriptionPurchaseCustomMonthsLabel => 'Number of months';

  @override
  String get subscriptionPurchaseCustomMonthsHint => '1–12';

  @override
  String get subscriptionPurchaseCustomMonthsHelper =>
      'Enter between 1 and 12 months';

  @override
  String subscriptionPurchaseMonths(int count) {
    return '$count months';
  }

  @override
  String get subscriptionPurchasePaymentMethod => 'Payment method';

  @override
  String get subscriptionProcessorStripe => 'Stripe';

  @override
  String get subscriptionProcessorMixin => 'Cryptocurrency';

  @override
  String get subscriptionPaymentMethodCard => 'Card';

  @override
  String get subscriptionPaymentMethodWechat => 'WeChat';

  @override
  String get subscriptionPaymentMethodAlipay => 'Alipay';

  @override
  String get subscriptionPaymentMethodGooglePay => 'Google Pay';

  @override
  String get subscriptionPaymentMethodUsdt => 'USDT';

  @override
  String get subscriptionPaymentMethodUsdc => 'USDC';

  @override
  String get subscriptionPaymentMethodBtc => 'BTC';

  @override
  String get subscriptionPaymentMethodEth => 'ETH';

  @override
  String get subscriptionPaymentMethodDoge => 'Doge';

  @override
  String get subscriptionPaymentMethodAndMore => 'and more';

  @override
  String get subscriptionTotalPriceLabel => 'Total';

  @override
  String subscriptionTotalPrice(String amount) {
    return '$amount USD';
  }

  @override
  String get subscriptionContinueToPayment => 'Continue to payment';

  @override
  String get subscriptionRedirectingToPayment => 'Redirecting to payment…';

  @override
  String get subscriptionPaymentUrlMissing => 'Payment URL not available';

  @override
  String get subscriptionPaymentLaunchFailed => 'Could not open payment page';

  @override
  String get subscriptionPurchaseFailed => 'Purchase failed';

  @override
  String get subscriptionMobilePurchaseTitle => 'Mobile purchase coming soon';

  @override
  String get subscriptionMobilePurchaseMessage =>
      'In-app purchase on iOS and Android is not available yet. If you already have Pro from the web or desktop app, your status appears above.';

  @override
  String get subscriptionCreditsLimitMessage =>
      'AI credits limit reached. Upgrade for higher limits.';

  @override
  String get subscriptionViewPlans => 'View plans';

  @override
  String get subscriptionUpgradedToPro => 'You\'re now Pro — enjoy!';

  @override
  String get subscriptionVerifyingUpgrade => 'Verifying your upgrade…';

  @override
  String get subscriptionVerifyTimeout =>
      'Couldn\'t confirm your upgrade yet — we\'ll keep checking in the background.';

  @override
  String get creditsUsageTitle => 'Credits usage';

  @override
  String get creditsUsageDescription =>
      'Records of credits checks on the Enjoy AI worker (UTC dates).';

  @override
  String get creditsUsageStartDate => 'Start date';

  @override
  String get creditsUsageEndDate => 'End date';

  @override
  String get creditsUsageServiceType => 'Service';

  @override
  String get creditsUsageClearFilters => 'Clear filters';

  @override
  String get creditsUsageError => 'Could not load usage';

  @override
  String get creditsUsageErrorDescription =>
      'Check your network and AI API base URL in Settings.';

  @override
  String get creditsUsageRetry => 'Retry';

  @override
  String get creditsUsageNoRecords => 'No records';

  @override
  String get creditsUsageNoRecordsWithFilters =>
      'Try changing or clearing filters.';

  @override
  String get creditsUsageNoRecordsDescription =>
      'Usage will appear here after you use AI features while signed in.';

  @override
  String get creditsUsageTableDate => 'Date';

  @override
  String get creditsUsageTableTime => 'Time';

  @override
  String get creditsUsageTableService => 'Service';

  @override
  String get creditsUsageTableTier => 'Tier';

  @override
  String get creditsUsageTableRequired => 'Required';

  @override
  String get creditsUsageTableUsedAfter => 'Used after';

  @override
  String get creditsUsageTableStatus => 'Status';

  @override
  String get creditsUsageAllowed => 'Allowed';

  @override
  String get creditsUsageDenied => 'Denied';

  @override
  String creditsUsagePageInfo(int page) {
    return 'Page $page';
  }

  @override
  String creditsUsageTotalRecords(int count) {
    return '$count shown';
  }

  @override
  String get creditsUsagePrevious => 'Previous';

  @override
  String get creditsUsageNext => 'Next';

  @override
  String get creditsServiceTypeAll => 'All';

  @override
  String get creditsServiceTypeTts => 'TTS';

  @override
  String get creditsServiceTypeAsr => 'ASR';

  @override
  String get creditsServiceTypeTranslation => 'Translation';

  @override
  String get creditsServiceTypeLlm => 'LLM';

  @override
  String get creditsServiceTypeAssessment => 'Assessment';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionAccountHint =>
      'Profile, subscription, and sign out';

  @override
  String get settingsSectionSyncHint =>
      'Upload queue, offline state, and manual sync';

  @override
  String get settingsSectionAppearanceLanguageHint =>
      'Theme density, transcript font, and locale';

  @override
  String get hotkeysSectionKeyboardHint => 'Reference and customize shortcuts';

  @override
  String get settingsSectionAdvancedHint =>
      'API endpoints and experimental toggles';

  @override
  String get settingsSectionDeveloperHint => 'Diagnostics and internal tooling';

  @override
  String get settingsSectionAboutHint => 'Version, licenses, and links';

  @override
  String get settingsSectionSync => 'Cloud sync';

  @override
  String get syncSettingsTileTitle => 'Sync status';

  @override
  String get syncSettingsTileSubtitleSignedOut =>
      'Sign in to sync library and recordings';

  @override
  String get syncSettingsTileSubtitleUpToDate => 'Up to date';

  @override
  String syncSettingsTileSubtitleCounts(int retryable, int failed) {
    return '$retryable waiting · $failed failed';
  }

  @override
  String get syncScreenTitle => 'Sync status';

  @override
  String get syncScreenLastSyncLabel => 'Last successful sync';

  @override
  String get syncScreenLastSyncNever => 'Never';

  @override
  String get syncScreenStatRetryable => 'Waiting to upload';

  @override
  String get syncScreenStatFailed => 'Failed permanently';

  @override
  String get syncScreenSyncNow => 'Sync now';

  @override
  String get syncScreenRetryFailed => 'Retry failed items';

  @override
  String get syncScreenSignedOutBody =>
      'Sign in with your Enjoy account to sync metadata across devices.';

  @override
  String get syncScreenGoSignIn => 'Sign in';

  @override
  String get cloudScreenTitle => 'Cloud';

  @override
  String get cloudTabAudio => 'Audio';

  @override
  String get cloudTabVideo => 'Video';

  @override
  String get cloudSignedOutBody =>
      'Sign in to browse media saved to your Enjoy account.';

  @override
  String get cloudAddToLibrary => 'Add to library';

  @override
  String get cloudAlreadyInLibrary => 'Already in library';

  @override
  String get cloudAddedToLibrary => 'Added to your local library.';

  @override
  String get cloudEmpty => 'No items in this list.';

  @override
  String get cloudHasMediaUrlHint => 'Streams from your saved URL when opened.';

  @override
  String get cloudNoMediaUrlHint =>
      'No remote file URL — use Locate file in the player when you open this item.';

  @override
  String get cloudRefreshTooltip => 'Refresh this tab';

  @override
  String get cloudAddToLibraryTooltip => 'Add to library';

  @override
  String get cloudEmptyAudioTitle => 'No cloud audio yet';

  @override
  String get cloudEmptyAudioSubtitle =>
      'Items you save while signed in will appear here.';

  @override
  String get cloudEmptyVideoTitle => 'No cloud video yet';

  @override
  String get cloudEmptyVideoSubtitle =>
      'Items you save while signed in will appear here.';

  @override
  String get syncSnackSuccess => 'Sync finished successfully.';

  @override
  String syncSnackIssues(int synced, int failed) {
    return 'Sync finished: $synced succeeded, $failed failed.';
  }

  @override
  String get syncQueueDetails => 'Queue details';

  @override
  String get syncQueueEmpty => 'Nothing in the queue.';

  @override
  String get settingsSectionAdvanced => 'Advanced';

  @override
  String get settingsApiBaseUrl => 'API base URL';

  @override
  String get settingsApiBaseUrlHint => 'Example: https://enjoy.bot';

  @override
  String get settingsApiBaseUrlSave => 'Save API URL';

  @override
  String get settingsAiApiBaseUrl => 'AI API base URL';

  @override
  String get settingsAiApiBaseUrlHint => 'Example: https://worker.enjoy.bot';

  @override
  String get settingsAiApiBaseUrlSave => 'Save AI API URL';

  @override
  String get settingsAiApiBaseUrlUseDefault => 'Use API URL';

  @override
  String get settingsAiApiBaseUrlCleared =>
      'AI API now follows the main API URL.';

  @override
  String get settingsAccountSignedOut => 'Not signed in';

  @override
  String get settingsAccountOpenProfile => 'Open profile';

  @override
  String get settingsAccountSignIn => 'Sign in';

  @override
  String get errorNetwork => 'Network error';

  @override
  String get errorUnauthorized => 'Session expired — please sign in again';

  @override
  String get communityActivity => 'Community Activity';

  @override
  String get communityToday => 'Community Today';

  @override
  String get homeRecordingsToday => 'Recordings';

  @override
  String get homePracticeTime => 'Practice Time';

  @override
  String get homeActiveLearners => 'Active Learners';

  @override
  String homePeopleLearning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people learning',
      one: '$count person learning',
    );
    return '$_temp0';
  }

  @override
  String get homeNoActiveUsers => 'No active users';

  @override
  String get homeTodaysGoal => 'Today\'s Goal';

  @override
  String get homeMinutes => 'min';

  @override
  String get homeCompleted => 'completed';

  @override
  String get homeGoalCompleted => 'Goal completed! Great job!';

  @override
  String get homeGoalAlmostThere => 'Almost there! Keep going!';

  @override
  String get homeGoalHalfway => 'Halfway there! You can do it!';

  @override
  String get homeGoalGoodStart => 'Good start! Keep practicing!';

  @override
  String get homeGoalJustStarted => 'Just started! Every minute counts!';

  @override
  String get homeGoalStartNow => 'Start your practice now!';

  @override
  String get mediaLocateTitle => 'Locate media file';

  @override
  String get mediaLocateBody =>
      'This item was added on another device. Choose the same file on this computer. We verify it matches your library using a secure fingerprint.';

  @override
  String get mediaLocateChooseFile => 'Choose file';

  @override
  String get mediaLocateHashMismatch =>
      'That file does not match this item. Make sure you selected the correct file.';

  @override
  String mediaLocateExpectedSize(String sizeLabel) {
    return 'Expected size: $sizeLabel';
  }

  @override
  String get mediaLocateSizeUnknown => 'Expected size: unknown';

  @override
  String get libraryDeleteMediaTitle => 'Delete from library?';

  @override
  String libraryDeleteMediaMessage(String title) {
    return 'Remove \"$title\" from this device. This cannot be undone.';
  }

  @override
  String get libraryDeleteMediaTooltip => 'Delete from library';

  @override
  String get libraryMediaDeleted => 'Removed from library.';

  @override
  String get libraryDeleteMediaFailed => 'Could not remove this item.';

  @override
  String get settingsSectionDeveloper => 'Developer';

  @override
  String get settingsAiPlaygroundTileTitle => 'AI playground';

  @override
  String get settingsAiPlaygroundTileSubtitle =>
      'Exercise ASR, chat, translation, and dictionary APIs';

  @override
  String get aiPlaygroundTitle => 'AI playground';

  @override
  String get aiPlaygroundIntro =>
      'Exercise AI modalities using Enjoy cloud or your BYOK credentials from Settings → AI providers. Translation and dictionary follow the LLM provider.';

  @override
  String get aiPlaygroundActiveProviders => 'Active providers';

  @override
  String aiPlaygroundProviderByokDetail(String detail) {
    return 'BYOK · $detail';
  }

  @override
  String get aiPlaygroundProviderLocal => 'Local (unavailable)';

  @override
  String get aiPlaygroundPickAudio => 'Pick audio file';

  @override
  String get aiPlaygroundTranscribe => 'Transcribe';

  @override
  String get aiPlaygroundChatSystem => 'System (optional)';

  @override
  String get aiPlaygroundChatUser => 'User message';

  @override
  String get aiPlaygroundSendChat => 'Send chat';

  @override
  String get aiPlaygroundTranslateSource => 'Source language';

  @override
  String get aiPlaygroundTranslateTarget => 'Target language';

  @override
  String get aiPlaygroundTranslateText => 'Text to translate';

  @override
  String get aiPlaygroundTranslate => 'Translate';

  @override
  String get aiPlaygroundDictWord => 'Word';

  @override
  String get aiPlaygroundDictSource => 'Source language';

  @override
  String get aiPlaygroundDictTarget => 'Target language';

  @override
  String get aiPlaygroundDictLookup => 'Dictionary lookup';

  @override
  String get aiPlaygroundAssessmentReference =>
      'Reference text (what you spoke)';

  @override
  String get aiPlaygroundAssessmentLanguage => 'Language (e.g. en, en-US)';

  @override
  String get aiPlaygroundAssess => 'Run pronunciation assessment';

  @override
  String get aiPlaygroundAssessmentTtsNote =>
      'Enjoy TTS is not wired yet; configure TTS BYOK under AI providers for synthesis. Assessment uses the provider shown above.';

  @override
  String get aiPlaygroundOutput => 'Output';

  @override
  String get aiPlaygroundClearOutput => 'Clear output';

  @override
  String get aiPlaygroundSectionAsr => 'ASR';

  @override
  String get aiPlaygroundSectionChat => 'Chat';

  @override
  String get aiPlaygroundSectionTranslation => 'Translation';

  @override
  String get aiPlaygroundSectionDictionary => 'Dictionary';

  @override
  String get aiPlaygroundSectionTtsAssessment => 'TTS / Assessment';

  @override
  String get youtubePasteFromClipboard => 'Paste';

  @override
  String get settingsSubtitle => 'Tune Enjoy to fit how you study.';

  @override
  String get settingsAuthLoadFailed =>
      'We couldn\'t refresh your account. Check your connection and try again.';

  @override
  String get settingsSectionAppearanceLanguage => 'Appearance & Language';

  @override
  String get settingsAppearanceTheme => 'Theme';

  @override
  String get settingsAppearanceThemeValue => 'Dark · Cinematic';

  @override
  String get settingsAppearanceDisplayLanguage => 'Display language';

  @override
  String get settingsAppearanceLearningLanguage => 'Learning language';

  @override
  String get settingsAppearanceNativeLanguage => 'Native language';

  @override
  String get settingsAppearanceSyncedFromProfile =>
      'Synced from your account profile';

  @override
  String get settingsLanguageSubtitleSignedIn =>
      'Also updates your Enjoy profile when online.';

  @override
  String get settingsLanguageSubtitleDeviceOnly =>
      'Stored on this device until you sign in.';

  @override
  String get settingsLanguageOptionEnUs => 'English (United States)';

  @override
  String get settingsLanguageOptionEnGb => 'English (United Kingdom)';

  @override
  String get settingsLanguageOptionJaJp => 'Japanese';

  @override
  String get settingsLanguageOptionKoKr => 'Korean';

  @override
  String get settingsLanguageOptionEsEs => 'Spanish (Spain)';

  @override
  String get settingsLanguageOptionEsMx => 'Spanish (Mexico)';

  @override
  String get settingsLanguageOptionFrFr => 'French (France)';

  @override
  String get settingsLanguageOptionFrCa => 'French (Canada)';

  @override
  String get settingsLanguageOptionZhCn => 'Chinese (Simplified, China)';

  @override
  String get settingsLearningLanguageSubtitle =>
      'Default for Discover and import suggestions.';

  @override
  String get settingsLanguagePickerTitleLearning => 'Learning language';

  @override
  String get mediaLanguageUnknown => 'Unknown';

  @override
  String get mediaLanguagePickerTitle => 'Content language';

  @override
  String get mediaEditLanguage => 'Edit language';

  @override
  String get mediaLanguageUpdated => 'Language updated.';

  @override
  String get mediaLanguageUpdateFailed => 'Could not update language.';

  @override
  String get assessmentUnavailableLanguage =>
      'Pronunciation assessment is not available for this language.';

  @override
  String get discoverLanguageFilterAll => 'All languages';

  @override
  String get discoverLanguageFilterLabel => 'Language';

  @override
  String get settingsNativeMustDifferHint =>
      'Must differ from your learning language.';

  @override
  String get settingsLanguagePickerTitleDisplay => 'Display language';

  @override
  String get settingsLanguagePickerTitleNative => 'Native language';

  @override
  String get profileFieldDisplayLanguage => 'Display language';

  @override
  String get profileLearningLanguageReadOnly =>
      'Choose the language you are learning.';

  @override
  String get settingsKeyboardOpenCheatsheet => 'Open shortcuts cheatsheet';

  @override
  String get settingsKeyboardOpenCheatsheetSubtitle =>
      'Browse and customize every shortcut';

  @override
  String get settingsKeyboardCustomizeTitle => 'Customize shortcuts';

  @override
  String hotkeysHelpSubtitle(String key) {
    return 'Press $key anytime to open this list.';
  }

  @override
  String get hotkeysHelpSearchHint => 'Search shortcuts';

  @override
  String get hotkeysHelpEmpty => 'No matching shortcuts';

  @override
  String get hotkeysHelpCustomize => 'Customize shortcuts';

  @override
  String hotkeysSettingsSubtitle(String key) {
    return 'Tap a row to change. Press $key anytime.';
  }

  @override
  String get hotkeysFilterHint => 'Filter shortcuts';

  @override
  String get hotkeysResetTooltip => 'Reset this shortcut';

  @override
  String get hotkeysEditTooltip => 'Change shortcut';

  @override
  String get settingsAboutMadeWithCare =>
      'Made with care for language learners.';

  @override
  String settingsAboutVersion(String version) {
    return 'v$version';
  }

  @override
  String get settingsAboutOpenSourceTitle => 'Open source';

  @override
  String get settingsAboutOpenSourceSubtitle => 'View source code on GitHub';

  @override
  String get settingsAboutContactTitle => 'Contact the developer';

  @override
  String get settingsAboutContactSubtitle =>
      'Send feedback or report a bug directly';

  @override
  String get settingsAboutContactEmailLabel => 'Email';

  @override
  String get settingsAboutContactWeChatLabel => 'WeChat';

  @override
  String get settingsAboutContactMixinLabel => 'Mixin';

  @override
  String get settingsAboutContactCopiedEmail => 'Email copied to clipboard';

  @override
  String get settingsAboutContactCopiedWeChat =>
      'WeChat ID copied to clipboard';

  @override
  String get settingsAboutContactCopiedMixin => 'Mixin ID copied to clipboard';

  @override
  String get settingsDiagnosticsLoggingTitle => 'Diagnostic logging';

  @override
  String get settingsDiagnosticsLoggingSubtitle =>
      'Record extra detail for YouTube, sync, and sign-in issues';

  @override
  String get settingsDiagnosticsPrivacyNote =>
      'Logs stay on this device until you export them. Tokens and cookies are redacted.';

  @override
  String get settingsDiagnosticsExportTitle => 'Export diagnostic report';

  @override
  String get settingsDiagnosticsExportSubtitle =>
      'Save a zip of recent logs for support';

  @override
  String get settingsDiagnosticsExportSuccess => 'Diagnostic report saved.';

  @override
  String get settingsDiagnosticsExportError =>
      'Could not export diagnostic report.';

  @override
  String get settingsCheckForUpdatesTitle => 'Check for updates';

  @override
  String get settingsCheckForUpdatesSubtitle =>
      'See if a newer direct-download build is available';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateAvailableBadgeSemantics => 'Update available';

  @override
  String get updateMandatoryTitle => 'Update required';

  @override
  String updateVersionLine(String current, String latest) {
    return 'Installed $current → $latest';
  }

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateDismiss => 'Dismiss';

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateRetry => 'Retry';

  @override
  String get updatePreparing => 'Preparing download…';

  @override
  String updateDownloading(int percent) {
    return 'Downloading update… $percent%';
  }

  @override
  String get updateVerifying => 'Verifying download…';

  @override
  String get updateOpeningInstaller => 'Opening installer…';

  @override
  String get updateErrorDownload =>
      'Download failed. Check your connection and try again.';

  @override
  String get updateErrorChecksum =>
      'The download was corrupted. Please try again.';

  @override
  String get updateErrorPermission =>
      'Install permission was denied. Allow installs from this app in system settings, then retry.';

  @override
  String get updateErrorAlreadyRunning =>
      'An update download is already in progress.';

  @override
  String get updateErrorInstallation =>
      'Could not open the installer. Please try again.';

  @override
  String get updateErrorGeneric => 'Update failed. Please try again.';

  @override
  String get updateUpToDate => 'You\'re on the latest version.';

  @override
  String get updateCheckOffline =>
      'Could not check for updates. Check your connection.';

  @override
  String get updateStoreChannelHint =>
      'This build is from TestFlight or the Play Store — updates are handled by the store.';

  @override
  String get lookupSheetTitle => 'Look up';

  @override
  String get lookupSectionTranslation => 'Translation';

  @override
  String get lookupSectionContextualTranslation => 'Contextual translation';

  @override
  String get lookupSectionDictionary => 'Definition';

  @override
  String get lookupLoading => 'Loading…';

  @override
  String get lookupErrorRetry => 'Retry';

  @override
  String get lookupEmpty => 'No result.';

  @override
  String get lookupLemma => 'Lemma';

  @override
  String get lookupIpa => 'IPA';

  @override
  String get lookupExamples => 'Examples';

  @override
  String get lookupClose => 'Close';

  @override
  String get lookupCopy => 'Copy';

  @override
  String get lookupCopySuccess => 'Copied to clipboard';

  @override
  String get lookupTapToExpand => 'Expand to load';

  @override
  String get lookupSourceLanguage => 'Source language';

  @override
  String get lookupTargetLanguage => 'Target language';

  @override
  String get lookupSwapLanguages => 'Swap languages';

  @override
  String get lookupPickSourceTitle => 'Choose source language';

  @override
  String get lookupPickTargetTitle => 'Choose target language';

  @override
  String get lookupRefresh => 'Refresh';

  @override
  String get lookupCloudRequiresSignIn =>
      'Sign in under Settings to use cloud dictionary, translation, and contextual translation.';

  @override
  String get lookupLanguageEnUs => 'English';

  @override
  String get lookupLanguageEnGb => 'English (UK)';

  @override
  String get lookupLanguageZhCn => '中文';

  @override
  String get lookupLanguageJaJp => '日本語';

  @override
  String get lookupLanguageKoKr => '한국어';

  @override
  String get lookupLanguageEsEs => 'Español (España)';

  @override
  String get lookupLanguageEsMx => 'Español (México)';

  @override
  String get lookupLanguageFrFr => 'Français (France)';

  @override
  String get lookupLanguageFrCa => 'Français (Canada)';

  @override
  String get lookupLanguageDeDe => 'Deutsch';

  @override
  String get lookupLanguageItIt => 'Italiano';

  @override
  String get lookupLanguagePtBr => 'Português (Brasil)';

  @override
  String get lookupLanguagePtPt => 'Português (Portugal)';

  @override
  String get lookupLanguageRuRu => 'Русский';

  @override
  String get lookupSourceResetToLearning =>
      'Source language reset to learning default';

  @override
  String get vocabularyAddToVocabulary => 'Add to Vocabulary';

  @override
  String get vocabularyAddContext => 'Add Context';

  @override
  String get vocabularyAlreadyInVocabulary => 'Already in Vocabulary';

  @override
  String get vocabularyAdding => 'Adding…';

  @override
  String get vocabularyRemoving => 'Removing…';

  @override
  String get vocabularyConfirmDeleteTitle => 'Remove from vocabulary?';

  @override
  String get vocabularyConfirmDeleteBody =>
      'This deletes the word and all of its contexts.';

  @override
  String get vocabularyCancel => 'Cancel';

  @override
  String get vocabularyDelete => 'Delete';

  @override
  String get vocabularyTitle => 'Vocabulary';

  @override
  String get vocabularyProfileEntry => 'Vocabulary';

  @override
  String get vocabularyProfileEntryHint => 'Review saved words and flashcards';

  @override
  String get vocabularyReview => 'Review';

  @override
  String get vocabularyAllWords => 'All Words';

  @override
  String get vocabularyTotal => 'Total';

  @override
  String get vocabularyDue => 'Due';

  @override
  String get vocabularyStatusNew => 'New';

  @override
  String get vocabularyStatusLearning => 'Learning';

  @override
  String get vocabularyStatusReviewing => 'Reviewing';

  @override
  String get vocabularyStatusMastered => 'Mastered';

  @override
  String get vocabularyNoWords => 'No words yet';

  @override
  String get vocabularyNoWordsDescription =>
      'Select text in a transcript and choose Add to Vocabulary to start your word book.';

  @override
  String get vocabularyNoDueItems => 'Nothing due right now';

  @override
  String get vocabularyNoDueItemsDescription =>
      'You can still start a custom review of all words, by status, language, or a random set.';

  @override
  String get vocabularyNoMatches => 'No matching words';

  @override
  String get vocabularyNoMatchesDescription =>
      'Try a different search or clear the status and language filters.';

  @override
  String get vocabularyListLoadFailed => 'Could not load your vocabulary.';

  @override
  String get vocabularyCustomReview => 'Custom review';

  @override
  String get vocabularySelectReviewItems => 'Choose what to review';

  @override
  String get vocabularyReviewDueItems => 'Due items';

  @override
  String get vocabularyReviewDueHint => 'Words scheduled for today or earlier';

  @override
  String get vocabularyReviewAll => 'All words';

  @override
  String get vocabularyReviewAllHint => 'Review every word in your book';

  @override
  String get vocabularyReviewByStatus => 'By status';

  @override
  String get vocabularyReviewByStatusHint =>
      'Focus on new, learning, reviewing, or mastered';

  @override
  String get vocabularyReviewByLanguage => 'By language';

  @override
  String get vocabularyReviewByLanguageHint =>
      'Limit the session to one source language';

  @override
  String get vocabularyReviewRandom => 'Random';

  @override
  String get vocabularyReviewRandomHint =>
      'Shuffle and take a short practice set';

  @override
  String get vocabularyNumberOfWords => 'Number of words';

  @override
  String vocabularyQueueCount(int count) {
    return '$count words';
  }

  @override
  String get vocabularyStartReview => 'Start review';

  @override
  String get vocabularyEmptyQueue => 'No words match this selection.';

  @override
  String get vocabularyExitReview => 'Exit review';

  @override
  String get vocabularyHowWellDoYouKnow => 'How well do you know this?';

  @override
  String get vocabularyDontKnow => 'Don\'t Know';

  @override
  String get vocabularyKnow => 'Know';

  @override
  String get vocabularyKnowWell => 'Know Well';

  @override
  String get vocabularySkip => 'Skip';

  @override
  String get vocabularyUndo => 'Undo';

  @override
  String vocabularyProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String vocabularyRemaining(int count) {
    return '$count remaining';
  }

  @override
  String get vocabularyFlipBack => 'Flip back';

  @override
  String get vocabularyReviewComplete => 'Review complete';

  @override
  String get vocabularyReviewCompleteDescription =>
      'Nice work. Your ratings are saved.';

  @override
  String get vocabularyDone => 'Done';

  @override
  String get vocabularySearchPlaceholder => 'Search words';

  @override
  String get vocabularyFilterStatus => 'Status';

  @override
  String get vocabularyFilterLanguage => 'Language';

  @override
  String get vocabularyFilterAll => 'All';

  @override
  String get vocabularyFilters => 'Filters';

  @override
  String get vocabularyContext => 'Context';

  @override
  String get vocabularyDictionary => 'Dictionary';

  @override
  String get vocabularyNotes => 'Notes';

  @override
  String get vocabularyNotesPlaceholder => 'Notes coming soon';

  @override
  String get vocabularyNoContextAvailable => 'No context available';

  @override
  String get vocabularyDictionaryNotAvailable =>
      'Dictionary not available offline';

  @override
  String get vocabularyOverdue => 'Overdue';

  @override
  String get vocabularyToday => 'Today';

  @override
  String get vocabularyTomorrow => 'Tomorrow';

  @override
  String vocabularyInDays(int days) {
    return 'In $days days';
  }

  @override
  String get vocabularyKeyboardShortcuts =>
      'Shortcuts: Space flip/back · 1/2/3 rate · ← previous · → skip · Esc exit';

  @override
  String vocabularyContextsCount(int count) {
    return '$count contexts';
  }

  @override
  String vocabularyReviewsCount(int count) {
    return '$count reviews';
  }

  @override
  String get vocabularyFlipHint => 'Tap to flip';

  @override
  String get vocabularyPlaySegment => 'Play segment';

  @override
  String get vocabularyOpenInPlayer => 'Open in player';

  @override
  String get vocabularyOpenInPlayerDescription =>
      'Opening the player will end this review session. Your ratings so far are saved.';

  @override
  String get vocabularyShadowReading => 'Shadow reading';

  @override
  String get vocabularyShadowReadingDescription =>
      'Continue to the player for shadow reading? This ends the review session. Your ratings so far are saved.';

  @override
  String get vocabularyEchoReading => 'Echo reading';

  @override
  String get vocabularyPracticeDismiss => 'Close practice';

  @override
  String get vocabularyPracticePause => 'Pause';

  @override
  String get vocabularyStatsExpand => 'Show status breakdown';

  @override
  String get vocabularyStatsCollapse => 'Hide status breakdown';

  @override
  String get vocabularyPreviousContext => 'Previous context';

  @override
  String get vocabularyNextContext => 'Next context';

  @override
  String vocabularyContextOfTotal(int current, int total) {
    return '$current of $total';
  }

  @override
  String get vocabularyContextualTranslation => 'Contextual translation';

  @override
  String get vocabularyFetchDictionary => 'Look up dictionary';

  @override
  String get vocabularyFetchContextual => 'Translate context';

  @override
  String get vocabularyFetching => 'Loading…';

  @override
  String get vocabularyAiUnavailable => 'Sign in to use AI lookup';

  @override
  String get vocabularyAiFetchFailed =>
      'Could not load. Try again when online.';

  @override
  String get vocabularyMediaUnavailable =>
      'Media actions unavailable for this context';

  @override
  String get vocabularyMediaPlayFailed => 'Could not play this segment';

  @override
  String get vocabularyMediaOpenFailed => 'Could not open this media';

  @override
  String get vocabularyConfirmContinue => 'Continue';

  @override
  String get vocabularySourceLabel => 'Source';

  @override
  String get vocabularyUnknownSource => 'Unknown source';

  @override
  String vocabularyLocatorLabel(String start, String duration) {
    return '${start}s · ${duration}s';
  }

  @override
  String get vocabularyExportToAnki => 'Export to Anki';

  @override
  String get vocabularyExportDialogTitle => 'Export to Anki';

  @override
  String get vocabularyExport => 'Export';

  @override
  String get vocabularyNoItemsToExport => 'No items to export';

  @override
  String get vocabularyProRequired => 'Pro required';

  @override
  String get vocabularyProRequiredDescription =>
      'Anki export is available on Enjoy Pro. Upgrade to export your vocabulary as Anki CSV cards.';

  @override
  String get vocabularyUpgradeToPro => 'Upgrade to Pro';

  @override
  String get vocabularyExportSuccess => 'Vocabulary exported.';

  @override
  String get vocabularyExportError => 'Could not export vocabulary.';

  @override
  String get vocabularyExportCancelled => 'Export cancelled.';

  @override
  String get vocabularyExportSparseCacheHint =>
      'Card backs are richer when dictionary and contextual translations were saved during review.';

  @override
  String get vocabularyExportProgress => 'Exporting…';

  @override
  String get authRequiredCloudFeaturesTitle => 'Account required';

  @override
  String get practicePosterShareTooltip => 'Share practice poster';

  @override
  String get practicePosterPreviewTitle => 'Share your practice';

  @override
  String get practicePosterTagline => 'Shadow reading';

  @override
  String get practicePosterStatTakes => 'Takes';

  @override
  String get practicePosterStatSentences => 'Sentences';

  @override
  String get practicePosterStatSpoken => 'Spoken';

  @override
  String get practicePosterQrHint =>
      'Scan to download Enjoy Player\nplayer.enjoy.bot';

  @override
  String get practicePosterShareAction => 'Share poster';

  @override
  String get practicePosterShareSuccess => 'Poster shared.';

  @override
  String get practicePosterSaveSuccess => 'Poster saved.';

  @override
  String get practicePosterExportError => 'Could not share practice poster.';

  @override
  String get practicePosterLoadError =>
      'Could not load practice data for this video.';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String notFoundSubtitle(String uri) {
    return 'We couldn\'t find $uri.';
  }

  @override
  String get notFoundBackHome => 'Back to home';

  @override
  String get recoveryTitle => 'Local data needs attention';

  @override
  String get recoverySubtitle =>
      'Enjoy Player could not open its local database. The most common cause is a partial update. Your data is still on disk; you can copy the error before continuing.';

  @override
  String get recoveryOpenLogs => 'Open logs folder';

  @override
  String get recoveryOpenLogsError => 'Could not open the logs folder.';

  @override
  String get recoveryCopyError => 'Copy error';

  @override
  String get recoveryCopiedToClipboard => 'Error details copied to clipboard.';

  @override
  String get recoveryResetLibrary => 'Reset local library';

  @override
  String get recoveryResetLibrarySubtitle =>
      'Wipe the local database and start fresh. Your cloud library is not affected. A backup of the current state is written to the application support directory before the wipe.';

  @override
  String get recoveryResetLibraryConfirmTitle => 'Reset local library?';

  @override
  String get recoveryResetLibraryConfirmBody =>
      'This permanently deletes your local library, recordings, transcripts, and sync queue. The cloud library (if signed in) is preserved. A backup is written to the application support directory first.';

  @override
  String get recoveryResetLibraryConfirmAction => 'Reset everything';

  @override
  String get recoveryResetLibraryBackupError =>
      'Backup failed — the local database was not wiped. The error has been logged.';

  @override
  String get recoveryResetLibrarySuccess =>
      'Local library reset. Reloading your data…';

  @override
  String get recoveryResetLibraryError => 'Could not reset the local library.';

  @override
  String get widgetErrorTitle => 'Something went wrong';

  @override
  String get widgetErrorSubtitle =>
      'This screen hit an unexpected error. You can copy the details below and try navigating elsewhere.';

  @override
  String get settingsSearchHint => 'Search settings';

  @override
  String get settingsSearchNoResultsTitle => 'No matching settings';

  @override
  String get settingsSearchNoResultsHint =>
      'Try a different word, or clear your search to browse everything.';

  @override
  String get settingsSearchClear => 'Clear search';

  @override
  String get settingsSectionExpandSemantics => 'Expand section';

  @override
  String get settingsSectionCollapseSemantics => 'Collapse section';

  @override
  String get settingsSectionNeedsAttention => 'Needs attention';

  @override
  String get transcriptBlurToggleTooltip =>
      'Blur practice (focus on listening)';

  @override
  String get transcriptBlurToggleOn => 'Listening-focus mode on';

  @override
  String get transcriptBlurToggleOff => 'Listening-focus mode off';

  @override
  String get transcriptBlurEmptyTooltip =>
      'No transcript lines to practice with';

  @override
  String get transcriptBlurSemanticsOn =>
      'Blur practice on. Tap or hover to reveal a line.';

  @override
  String get transcriptBlurSemanticsOff => 'Blur practice off.';

  @override
  String get importCraftFromText => 'Craft…';

  @override
  String get homeCraftAction => 'Craft';

  @override
  String get craftHistoryTooltip => 'History';

  @override
  String get craftHistoryTitle => 'Craft history';

  @override
  String get craftHistoryEmptyTitle => 'No Craft items yet';

  @override
  String get craftHistoryEmptyHint =>
      'Create audio in Craft and it will show up here.';

  @override
  String get craftHistoryEmptyAction => 'Start crafting';

  @override
  String get craftHistoryRemoveTooltip => 'Remove Craft record';

  @override
  String get craftHistoryRemoveTitle => 'Remove Craft record?';

  @override
  String craftHistoryRemoveMessage(String title) {
    return 'Remove the Craft record for \"$title\". The practice audio stays in your library.';
  }

  @override
  String get craftHistoryRemoveConfirm => 'Remove';

  @override
  String get craftHistoryRemoved => 'Craft record removed';

  @override
  String get craftHistoryRemoveFailed => 'Could not remove this Craft record.';

  @override
  String get craftEditUnavailable => 'This Craft item is no longer available.';

  @override
  String get craftSheetTitle => 'Craft audio from text';

  @override
  String get craftModeTranslateThenSpeak => 'Translate then speak';

  @override
  String get craftModeSpeakDirectly => 'Speak directly';

  @override
  String get craftSourceLanguageLabel => 'Source language';

  @override
  String get craftTargetLanguageLabel => 'Learning language';

  @override
  String get craftTextInputHint => 'Paste or type text…';

  @override
  String get craftPasteFromClipboard => 'Paste from clipboard';

  @override
  String get craftAction => 'Craft';

  @override
  String get craftCraftingProgress => 'Crafting your audio…';

  @override
  String get craftEmptyTextHint => 'Enter at least a sentence to craft.';

  @override
  String get craftSameLanguageHint =>
      'Looks like this is already in your learning language.';

  @override
  String get craftSameLanguageSwitch => 'Speak directly';

  @override
  String get craftOfflineBanner =>
      'You\'re offline. Craft needs an internet connection.';

  @override
  String get craftSignInRequired => 'Sign in to use Craft';

  @override
  String get craftFailureTts =>
      'We couldn\'t turn the text into audio. Check your TTS provider settings or try again.';

  @override
  String get craftFailureTranslate =>
      'We couldn\'t translate the text. Try again or switch to Speak directly.';

  @override
  String get craftFailureSave =>
      'The audio was generated but couldn\'t be saved. Free up space and try again.';

  @override
  String get craftAlreadyInLibrary => 'Already in your library';

  @override
  String get craftOpenExisting => 'Open';

  @override
  String get craftRetry => 'Retry';

  @override
  String get craftOpenAiSettings => 'Open AI settings';

  @override
  String get craftLengthCapNotice =>
      'Crafted the first 5000 characters; the rest was not synthesized.';

  @override
  String get libraryProviderCraftBadge => 'Craft';

  @override
  String get craftTtsSettingsHint => 'Craft uses the TTS provider below.';

  @override
  String get craftScreenTitle => 'Craft';

  @override
  String get craftTranslateTool => 'Translate';

  @override
  String get craftSynthesizeTool => 'Synthesize';

  @override
  String get craftStyleLabel => 'Style';

  @override
  String get craftStyleLiteral => 'Literal';

  @override
  String get craftStyleNatural => 'Natural';

  @override
  String get craftStyleCasual => 'Casual';

  @override
  String get craftStyleFormal => 'Formal';

  @override
  String get craftStyleSimplified => 'Simplified';

  @override
  String get craftStyleDetailed => 'Detailed';

  @override
  String get craftStyleCustom => 'Custom';

  @override
  String get craftCustomPromptHint => 'Enter your custom translation prompt…';

  @override
  String get craftSwapLanguages => 'Swap languages';

  @override
  String get craftTranslateButton => 'Translate';

  @override
  String get craftReTranslateButton => 'Re-translate';

  @override
  String get craftCopyTranslation => 'Copy';

  @override
  String get craftCopiedToClipboard => 'Copied to clipboard';

  @override
  String get craftTranslatedText => 'Translated text';

  @override
  String get craftUseTranslatedText => 'Use translated text';

  @override
  String get craftVoiceLabel => 'Voice';

  @override
  String get craftNoVoicesForLanguage =>
      'No voices available for this language.';

  @override
  String get craftSynthesizeButton => 'Synthesize';

  @override
  String get craftReSynthesizeButton => 'Re-synthesize';

  @override
  String get craftSaveToLibrary => 'Save to library';

  @override
  String get craftSavingProgress => 'Saving to library…';

  @override
  String get craftPreviewLabel => 'Preview';

  @override
  String get craftSourceText => 'Source text';

  @override
  String get craftSynthText => 'Text to synthesize';

  @override
  String get craftModeExpress => 'Express';

  @override
  String get craftModeAdvanced => 'Advanced';

  @override
  String get craftStageCapture => 'Capture';

  @override
  String get craftStageRewrite => 'Rewrite';

  @override
  String get craftStageAudio => 'Audio';

  @override
  String get craftCaptureTitle => 'Say what\'s on your mind';

  @override
  String get craftCaptureSubtitle =>
      'Tap to record. Speak naturally in your language.';

  @override
  String get craftCaptureStop => 'Stop';

  @override
  String get craftCaptureCancel => 'Cancel';

  @override
  String get craftCaptureTypeInstead => 'Type instead';

  @override
  String get craftLoadingTranscribing => 'Transcribing…';

  @override
  String get craftLoadingRewriting => 'Crafting…';

  @override
  String get craftLoadingSynthesizing => 'Generating audio…';

  @override
  String get craftRewriteYourWords => 'Your words';

  @override
  String get craftRewriteTargetLabel => 'In your target language';

  @override
  String get craftRewriteRegenerate => 'Regenerate';

  @override
  String get craftRewriteReRecord => 'Re-record';

  @override
  String get craftRewriteGenerateAudio => 'Generate audio';

  @override
  String get craftAudioPreview => 'Preview';

  @override
  String get craftAudioSaySomethingElse => 'Save & say another';

  @override
  String get craftAudioPracticeNow => 'Save & practice';

  @override
  String get craftAudioUnsavedHint =>
      'Not saved yet. Leave now and this audio is discarded — it won’t appear in history.';

  @override
  String get craftAudioDiscardTitle => 'Discard this audio?';

  @override
  String get craftAudioDiscardMessage =>
      'Generated audio is only kept after you save. Leaving now discards it, and credits already used for this preview are not refunded.';

  @override
  String get craftAudioDiscardConfirm => 'Discard';

  @override
  String get craftSavedToLibrary => 'Saved to library';

  @override
  String get craftSolidTranscriptSttHint =>
      'If line timings look off, regenerate them with speech-to-text from the transcript panel.';

  @override
  String get craftStyleAuto => '✨ Auto';

  @override
  String get craftFailureAsr =>
      'We couldn\'t hear you clearly. Try recording again.';

  @override
  String get craftFailureEmptyTranscript =>
      'That was too short. Try speaking a bit longer.';

  @override
  String get craftRecordingMicDenied =>
      'Microphone access denied. Please enable it in settings.';

  @override
  String get errorGenericLoadFailed =>
      'Something went wrong. Please try again.';

  @override
  String get subscriptionAutoRenewTitle => 'Auto-renew Pro';

  @override
  String get subscriptionAutoRenewMonthly => 'Monthly';

  @override
  String get subscriptionAutoRenewYearly => 'Yearly';

  @override
  String subscriptionAutoRenewPriceMonth(String amount) {
    return '$amount USD/month';
  }

  @override
  String subscriptionAutoRenewPriceYear(String amount) {
    return '$amount USD/year';
  }

  @override
  String get subscriptionAutoRenewSubscribe => 'Subscribe with auto-renew';

  @override
  String get subscriptionAutoRenewOn => 'Auto-renew on';

  @override
  String get subscriptionAutoRenewOff => 'Auto-renew off';

  @override
  String get subscriptionAutoRenewIntervalMonth => 'Monthly plan';

  @override
  String get subscriptionAutoRenewIntervalYear => 'Yearly plan';

  @override
  String subscriptionAutoRenewProvider(String provider) {
    return 'Billed via $provider';
  }

  @override
  String get subscriptionAutoRenewCancel => 'Cancel auto-renew';

  @override
  String get subscriptionAutoRenewCancelConfirmTitle => 'Cancel auto-renew?';

  @override
  String subscriptionAutoRenewCancelConfirmMessage(String date) {
    return 'You keep Pro until $date. You will not be charged again for this subscription.';
  }

  @override
  String get subscriptionAutoRenewCancelConfirmAction => 'Cancel auto-renew';

  @override
  String get subscriptionAutoRenewCancelKeep => 'Keep auto-renew';

  @override
  String subscriptionAutoRenewCancelSuccess(String date) {
    return 'Auto-renew canceled. Pro remains until $date.';
  }

  @override
  String get subscriptionAutoRenewCancelFailed =>
      'Could not cancel auto-renew. Try again.';

  @override
  String get subscriptionAutoRenewConflict =>
      'You already have an active auto-renew subscription.';

  @override
  String get subscriptionAutoRenewPlansUnavailable =>
      'Auto-renew plans are not available right now.';

  @override
  String get subscriptionProMemberTitle => 'You\'re on Pro';

  @override
  String subscriptionRenewsOn(String date) {
    return 'Renews on $date';
  }

  @override
  String subscriptionAccessUntil(String date) {
    return 'Access until $date';
  }

  @override
  String get subscriptionAutoRenewEndingSoon =>
      'Auto-renew is off — Pro continues until the date above';

  @override
  String get subscriptionIncludedWithPro => 'Included with Pro';

  @override
  String get subscriptionPayOnceTitle => 'Pay for months once';

  @override
  String get subscriptionPayOnceSubtitle =>
      'One-time prepaid months (no auto-renew)';

  @override
  String get creditsPackagesTitle => 'Credits packages';

  @override
  String get creditsPackagesSubtitle =>
      'One-time permanent credits — not a subscription';

  @override
  String creditsPackagePriceCredits(String price, String credits) {
    return '$price USD · $credits permanent credits';
  }

  @override
  String get creditsPackageBuy => 'Buy credits';

  @override
  String get creditsPackageConfirmTitle => 'Buy credits package?';

  @override
  String creditsPackageConfirmMessage(String price, String credits) {
    return 'Pay $price USD for $credits permanent credits. This does not change your subscription.';
  }

  @override
  String get creditsPackageConfirmAction => 'Continue to payment';

  @override
  String get creditsPackageVerifying => 'Verifying your credits purchase…';

  @override
  String get creditsPackageVerifyTimeout =>
      'Couldn\'t confirm credits yet — pull to refresh or check again shortly.';

  @override
  String get creditsPackagePurchaseSuccess => 'Permanent credits updated.';

  @override
  String get creditsPackagePurchaseFailed => 'Credits package purchase failed';

  @override
  String creditsPermanentAvailable(String count) {
    return '$count permanent credits available';
  }

  @override
  String get subscriptionCreditsLimitMessageWithPackages =>
      'AI credits limit reached. Upgrade to Pro or buy a credits package to continue.';

  @override
  String get subscriptionViewPlansAndPackages => 'View plans & packages';

  @override
  String get pronouncePlay => 'Play pronunciation';

  @override
  String get pronounceStop => 'Stop pronunciation';

  @override
  String get pronounceLoading => 'Loading pronunciation…';

  @override
  String get pronounceUnavailableLanguage =>
      'Pronunciation unavailable for this language';

  @override
  String get pronounceTextTooLong => 'Text is too long to pronounce';

  @override
  String get pronounceFailed => 'Couldn\'t play pronunciation';

  @override
  String get pronounceCreditsExhausted =>
      'Not enough credits to generate pronunciation';

  @override
  String get pronounceSignInRequired => 'Sign in to hear pronunciation';

  @override
  String get assessmentPlayMyRecording => 'Play my recording';

  @override
  String get assessmentStopMyRecording => 'Stop my recording';

  @override
  String get assessmentRecordingUnavailable => 'Recording file is unavailable';

  @override
  String get assessmentPlayMyClip => 'Play my recording of this word';

  @override
  String get assessmentStopMyClip => 'Stop my recording of this word';

  @override
  String get assessmentClipUnavailable => 'No recording clip for this word';

  @override
  String get subscriptionTierCatalogTitle => 'Choose your plan';

  @override
  String get subscriptionTierCatalogDescription =>
      'All tiers include the same AI features. Choose a credit allowance and billing cycle, then pick how you pay.';

  @override
  String get subscriptionTierCatalogRecommended => 'Recommended';

  @override
  String get subscriptionTierCatalogChoosePro => 'Choose Pro';

  @override
  String get subscriptionTierCatalogExtendPro => 'Extend Pro';

  @override
  String get subscriptionTierCatalogChooseLite => 'Choose Lite';

  @override
  String get subscriptionTierCatalogExtendLite => 'Extend Lite';

  @override
  String get subscriptionTierCatalogNotSelected => 'Downgrade is not available';

  @override
  String get subscriptionUpgradedToLite => 'You\'re now Lite — enjoy!';

  @override
  String subscriptionTierCatalogSelectedInterval(String amount, String unit) {
    return '$amount / $unit — billed via Stripe';
  }

  @override
  String subscriptionTierCatalogIntervalYearSavings(String percent) {
    return 'Save $percent%';
  }

  @override
  String get subscriptionTierCatalogPerMonth => 'month';

  @override
  String get subscriptionTierCatalogPerYear => 'year';

  @override
  String subscriptionPurchaseModalUnifiedTitle(String tier, String interval) {
    return 'Choose how to pay for $tier · $interval';
  }

  @override
  String get subscriptionPurchaseModalUnifiedDescription =>
      'Auto-renew keeps Pro access continuous and renews automatically. Pay once buys a fixed prepaid period with no auto-renew.';

  @override
  String get subscriptionPurchaseModalAutoRenewActiveWarning =>
      'You already have an active auto-renew subscription. Cancel it to switch billing options.';

  @override
  String get subscriptionPurchaseModalOptionAutoRenew => 'Auto-renew';

  @override
  String get subscriptionPurchaseModalOptionAutoRenewSubtitle =>
      'Recommended — renews automatically. Cancel anytime.';

  @override
  String get subscriptionPurchaseModalOptionAutoRenewFootnote =>
      'Billed via Stripe';

  @override
  String get subscriptionPurchaseModalOptionPrepaid => 'Pay once';

  @override
  String get subscriptionPurchaseModalOptionPrepaidSubtitle =>
      'No auto-renew. Pay for a fixed period up front.';

  @override
  String get subscriptionPurchaseModalOptionPrepaidFootnote =>
      'One-time payment';

  @override
  String get subscriptionPurchaseModalSubscribeAutoRenewCta =>
      'Subscribe with auto-renew';

  @override
  String get subscriptionBalanceToCreditsTitle =>
      'Convert balance to permanent credits';

  @override
  String subscriptionBalanceToCreditsDescriptionWithPreview(
    String usd,
    String credits,
  ) {
    return 'Move your $usd legacy balance to ~$credits permanent credits on the credits page.';
  }

  @override
  String get subscriptionBalanceToCreditsDescriptionEmpty =>
      'Once you have a balance from prior deposits, convert it to permanent credits here.';

  @override
  String get subscriptionBalanceToCreditsCta => 'Convert to credits';

  @override
  String get subscriptionBalanceToCreditsComingSoonTitle =>
      'Balance transfer coming soon';

  @override
  String subscriptionBalanceToCreditsComingSoonMessage(String usd) {
    return 'You have $usd in legacy balance. The transfer-to-credits flow is rolling out to the desktop app in a future update. Until then, manage your balance on the web app.';
  }

  @override
  String get onboardingTipSkip => 'Skip';

  @override
  String get onboardingTipHomeImportTitle => 'Import media';

  @override
  String get onboardingTipHomeImportBody =>
      'Bring in a local file or YouTube video to practice with.';

  @override
  String get onboardingTipHomeCraftTitle => 'Craft';

  @override
  String get onboardingTipHomeCraftBody =>
      'Create practice audio from text when you do not have a video yet.';

  @override
  String get onboardingTipEmptyTranscriptLocalTitle => 'Add a transcript';

  @override
  String get onboardingTipEmptyTranscriptLocalBody =>
      'Extract subtitles from the file or import a subtitle file so you can practice line by line.';

  @override
  String get onboardingTipEmptyTranscriptYoutubeTitle => 'Fetch transcript';

  @override
  String get onboardingTipEmptyTranscriptYoutubeBody =>
      'Pull captions for this YouTube video from the cloud to unlock practice.';

  @override
  String get onboardingTipEchoTitle => 'Echo mode';

  @override
  String get onboardingTipEchoBody =>
      'Turn on Echo to shadow each line and practice speaking along with the audio.';

  @override
  String get onboardingTipRecordTitle => 'Record yourself';

  @override
  String get onboardingTipRecordBody =>
      'Record your voice on a line, then compare it with the original.';

  @override
  String get onboardingTipAssessTitle => 'Assess pronunciation';

  @override
  String get onboardingTipAssessBody =>
      'After you record, check pronunciation feedback for that take.';

  @override
  String get settingsResetProductTipsTitle => 'Reset product tips';

  @override
  String get settingsResetProductTipsSubtitle =>
      'Show Home and Player tips again as if you were new.';

  @override
  String get settingsResetProductTipsConfirmTitle => 'Reset product tips?';

  @override
  String get settingsResetProductTipsConfirmBody =>
      'Tips for Craft, Import, transcripts, and practice will show again. Your library and account stay unchanged.';

  @override
  String get settingsResetProductTipsConfirmAction => 'Reset tips';

  @override
  String get settingsResetProductTipsDone => 'Product tips reset';

  @override
  String get transcriptEmptyFetchYoutube => 'Fetch transcript';
}
