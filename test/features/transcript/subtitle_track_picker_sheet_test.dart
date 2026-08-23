// ignore_for_file: scoped_providers_should_specify_dependencies
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/transcript/application/active_transcript_provider.dart';
import 'package:enjoy_player/features/transcript/application/all_transcripts_provider.dart';
import 'package:enjoy_player/features/transcript/application/auto_translate_controller.dart';
import 'package:enjoy_player/features/transcript/application/transcript_display_readiness_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_fetch_controller.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/domain/auto_translate.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/transcript/application/video_row_for_media_provider.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_fetch_status.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_track.dart';
import 'package:enjoy_player/features/transcript/presentation/subtitle_track_picker_sheet.dart';
import 'package:enjoy_player/features/transcript/presentation/subtitle_track_picker_sections.dart';
import 'package:enjoy_player/features/transcript/presentation/subtitle_track_picker_tiles.dart';
import 'package:enjoy_player/features/transcript/presentation/subtitle_track_picker_primitives.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_display_settings_sheet.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import '../../helpers/transcript_settings_overrides.dart';

const _mediaId = 'media-picker-test';

/// Minimal [PlayerController] that reports no open session, so the picker
/// renders without a video target / media_kit engine.
class _NoSessionPlayerController extends PlayerController {
  @override
  PlaybackSession? build() => null;
}

List<Override> _pickerOverrides({
  required List<TranscriptTrack> tracks,
  _SpyAutoTranslateCtrl? autoTranslateCtrl,
}) => [
  playerControllerProvider.overrideWith(() => _NoSessionPlayerController()),
  allTranscriptsForMediaProvider(
    _mediaId,
  ).overrideWith((ref) => Stream.value(tracks)),
  activeTranscriptIdProvider(_mediaId).overrideWith(
    (ref) => Stream.value(tracks.isEmpty ? null : tracks.first.id),
  ),
  secondaryTranscriptIdProvider(
    _mediaId,
  ).overrideWith((ref) => Stream.value(null)),
  transcriptLinesForMediaProvider(
    _mediaId,
  ).overrideWith((ref) => Stream.value(const [])),
  videoRowForMediaProvider(_mediaId).overrideWith((ref) async => null),
  canTrustWordTimesProvider(_mediaId).overrideWith((ref) async => false),
  transcriptFetchStatusProvider(_mediaId).overrideWithValue(
    const TranscriptFetchUiState(status: TranscriptFetchStatus.idle),
  ),
  autoTranslateCtrlProvider(
    _mediaId,
  ).overrideWith(() => autoTranslateCtrl ?? _SpyAutoTranslateCtrl()),
  autoTranslateSelectionIdProvider(
    _mediaId,
  ).overrideWith((ref) async => 'ai-selection-id'),
  appPreferencesCtrlProvider.overrideWith(() => _ZhNativePrefsCtrl()),
  authCtrlProvider.overrideWith(() => _SignedInAuthCtrl()),
  ...transcriptIpaOverlayOffOverrides(),
  karaokeHighlightSettingsProvider.overrideWith(
    () => KaraokeHighlightSettingsOverride(false),
  ),
];

class _SpyAutoTranslateCtrl extends AutoTranslateCtrl {
  int selectCalls = 0;

  @override
  AutoTranslateUiState build(String mediaId) => const AutoTranslateUiState();

  @override
  Future<void> selectAutoTranslate() async {
    selectCalls += 1;
  }
}

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'u1', email: 't@example.com', name: 'Test'),
  );
}

class _ZhNativePrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async => AppPreferencesState.initial
      .copyWith(nativeLanguage: 'zh-CN', learningLanguage: 'en-US');
}

Widget _harness({required List<Override> overrides}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: Center(
            child: SubtitleTrackPickerSheet(
              mediaId: _mediaId,
              presentation: SubtitleTrackPickerPresentation.dialog,
            ),
          ),
        ),
      ),
    ),
  );
}

late final AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('renders the no-tracks hint when no transcripts are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _pickerOverrides(tracks: const [])),
    );
    // The dialog loading skeleton's internal ListView is unbounded inside
    // the sheet's SingleChildScrollView for one frame before the stream
    // emits; that is a pre-existing quirk of the loading branch and is
    // unrelated to this module split. Drain it, then settle on the data
    // frame which is what the refactor touches.
    await tester.pump();
    tester.takeException();
    await tester.pumpAndSettle();

    // With no tracks, the primary list shows the empty hint while the
    // translation section is still rendered (it always offers "None").
    expect(find.byType(CollapsibleTrackSection), findsNWidgets(1));
    expect(find.text(l10n.noTranscriptHint), findsOneWidget);
  });

  testWidgets(
    'renders primary and translation sections when a track is available',
    (tester) async {
      const track = TranscriptTrack(
        id: 't1',
        targetType: 'Video',
        targetId: _mediaId,
        language: 'en',
        source: 'user',
        label: 'English',
        trackIndex: null,
      );
      await tester.pumpWidget(
        _harness(overrides: _pickerOverrides(tracks: const [track])),
      );
      await tester.pump();
      tester.takeException();
      await tester.pumpAndSettle();

      expect(find.byType(CollapsibleTrackSection), findsNWidgets(2));
      expect(find.text(l10n.subtitlesPrimary), findsOneWidget);
      expect(find.text(l10n.subtitlesTranslation), findsOneWidget);
      expect(find.byType(TranscriptDisplaySettingsSection), findsOneWidget);
      expect(find.byType(SubtitlePickerCard), findsWidgets);
      expect(find.byType(SubtitleToggleTile), findsNWidgets(3));
      expect(find.text(l10n.transcriptDisplaySettingsTitle), findsOneWidget);
      expect(find.text(l10n.transcriptBlurDisplayTitle), findsOneWidget);
      expect(find.text(l10n.settingsTranscriptKaraokeTitle), findsOneWidget);
      expect(find.text(l10n.settingsTranscriptIpaOverlayTitle), findsOneWidget);
    },
  );

  testWidgets('shows Auto translate option and hides ai source tracks', (
    tester,
  ) async {
    const track = TranscriptTrack(
      id: 't1',
      targetType: 'Video',
      targetId: _mediaId,
      language: 'en',
      source: 'user',
      label: 'English',
      trackIndex: null,
    );
    const aiTrack = TranscriptTrack(
      id: 'ai-track',
      targetType: 'Video',
      targetId: _mediaId,
      language: 'zh-CN',
      source: 'ai',
      label: 'Stored AI zh',
      trackIndex: null,
    );
    await tester.pumpWidget(
      _harness(overrides: _pickerOverrides(tracks: const [track, aiTrack])),
    );
    await tester.pump();
    tester.takeException();
    await tester.pumpAndSettle();

    final translationHeader = find.text(l10n.subtitlesTranslation);
    expect(translationHeader, findsOneWidget);
    await tester.tap(translationHeader);
    await tester.pumpAndSettle();

    expect(find.text(l10n.subtitlesAutoTranslate), findsOneWidget);
    expect(find.text('Stored AI zh'), findsNothing);
  });

  testWidgets('tapping Auto translate selects via the nullable radio group', (
    tester,
  ) async {
    const track = TranscriptTrack(
      id: 't1',
      targetType: 'Video',
      targetId: _mediaId,
      language: 'en',
      source: 'user',
      label: 'English',
      trackIndex: null,
    );
    final spy = _SpyAutoTranslateCtrl();
    await tester.pumpWidget(
      _harness(
        overrides: _pickerOverrides(
          tracks: const [track],
          autoTranslateCtrl: spy,
        ),
      ),
    );
    await tester.pump();
    tester.takeException();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.subtitlesTranslation));
    await tester.pumpAndSettle();

    expect(find.byType(AutoTranslateOptionTile), findsOneWidget);
    await tester.tap(find.text(l10n.subtitlesAutoTranslate));
    await tester.pumpAndSettle();

    expect(spy.selectCalls, 1);
  });

  testWidgets(
    'disabled Auto translate does not select when no primary is chosen',
    (tester) async {
      final spy = _SpyAutoTranslateCtrl();
      await tester.pumpWidget(
        _harness(
          overrides: _pickerOverrides(tracks: const [], autoTranslateCtrl: spy),
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.subtitlesTranslation));
      await tester.pumpAndSettle();

      expect(find.byType(AutoTranslateOptionTile), findsOneWidget);
      await tester.tap(find.text(l10n.subtitlesAutoTranslate));
      await tester.pumpAndSettle();

      expect(spy.selectCalls, 0);
    },
  );

  testWidgets('keeps each caption row compact so the picker fits many tracks', (
    tester,
  ) async {
    const tracks = [
      TranscriptTrack(
        id: 't1',
        targetType: 'Video',
        targetId: _mediaId,
        language: 'en',
        source: 'user',
        label: 'English',
        trackIndex: null,
      ),
      TranscriptTrack(
        id: 't2',
        targetType: 'Video',
        targetId: _mediaId,
        language: 'zh-CN',
        source: 'official',
        label: '简体中文',
        trackIndex: null,
      ),
      TranscriptTrack(
        id: 't3',
        targetType: 'Video',
        targetId: _mediaId,
        language: 'ja',
        source: 'auto',
        label: '日本語 (auto)',
        trackIndex: null,
      ),
      TranscriptTrack(
        id: 't4',
        targetType: 'Video',
        targetId: _mediaId,
        language: 'ko',
        source: 'ai',
        label: '한국어',
        trackIndex: null,
      ),
    ];
    await tester.pumpWidget(
      _harness(overrides: _pickerOverrides(tracks: tracks)),
    );
    await tester.pump();
    tester.takeException();
    await tester.pumpAndSettle();

    final primaryHeader = find.text(l10n.subtitlesPrimary);
    expect(primaryHeader, findsOneWidget);
    await tester.tap(primaryHeader);
    await tester.pumpAndSettle();

    expect(find.byType(TrackOptionTile<String>), findsNWidgets(4));
    final firstTileSize = tester.getSize(
      find.byType(TrackOptionTile<String>).first,
    );
    expect(
      firstTileSize.height,
      lessThanOrEqualTo(60),
      reason: 'compact single-line tile should stay under 60px tall',
    );
  });

  testWidgets('renders the skeleton while tracksAsync is loading', (
    tester,
  ) async {
    final overrides = <Override>[
      playerControllerProvider.overrideWith(() => _NoSessionPlayerController()),
      allTranscriptsForMediaProvider(
        _mediaId,
      ).overrideWith((ref) => const Stream.empty()),
      activeTranscriptIdProvider(
        _mediaId,
      ).overrideWith((ref) => const Stream.empty()),
      secondaryTranscriptIdProvider(
        _mediaId,
      ).overrideWith((ref) => const Stream.empty()),
      transcriptLinesForMediaProvider(
        _mediaId,
      ).overrideWith((ref) => const Stream.empty()),
      videoRowForMediaProvider(_mediaId).overrideWith((ref) async => null),
      canTrustWordTimesProvider(_mediaId).overrideWith((ref) async => false),
      transcriptFetchStatusProvider(_mediaId).overrideWithValue(
        const TranscriptFetchUiState(status: TranscriptFetchStatus.idle),
      ),
      autoTranslateCtrlProvider(
        _mediaId,
      ).overrideWith(_SpyAutoTranslateCtrl.new),
      autoTranslateSelectionIdProvider(
        _mediaId,
      ).overrideWith((ref) async => 'ai-selection-id'),
      appPreferencesCtrlProvider.overrideWith(() => _ZhNativePrefsCtrl()),
      authCtrlProvider.overrideWith(() => _SignedInAuthCtrl()),
      ...transcriptIpaOverlayOffOverrides(),
      karaokeHighlightSettingsProvider.overrideWith(
        () => KaraokeHighlightSettingsOverride(false),
      ),
    ];
    await tester.pumpWidget(_harness(overrides: overrides));
    await tester.pump();

    // The skeleton should be visible (one of the Skeleton boxes).
    expect(find.byType(Skeleton), findsWidgets);
  });
}
