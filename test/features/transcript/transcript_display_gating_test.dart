import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/subtitle/transcript_display_readiness.dart';
import 'package:enjoy_player/features/player/application/player_interactions.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_enrichment_controller.dart';
import 'package:enjoy_player/features/transcript/presentation/subtitle_track_picker_primitives.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_busy_action.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_display_settings_sheet.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../../helpers/transcript_settings_overrides.dart';

class _SpyKaraoke extends KaraokeHighlightSettingsOverride {
  _SpyKaraoke(super.enabled);

  var writes = 0;

  @override
  Future<void> setEnabled(bool enabled) async {
    writes += 1;
    await super.setEnabled(enabled);
  }
}

class _ToggleBlurInteractions extends PlayerInteractions {
  _ToggleBlurInteractions(super.ref);

  @override
  Future<void> toggleBlur() async {
    ref.read(transcriptBlurModeProvider.notifier).toggle();
  }
}

Widget _harness({
  required TranscriptDisplayReadiness readiness,
  required KaraokeHighlightSettings karaoke,
  List<Override> extraOverrides = const [],
}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
  return ProviderScope(
    overrides: [
      karaokeHighlightSettingsProvider.overrideWith(() => karaoke),
      ...transcriptIpaOverlayOffOverrides(),
      ...extraOverrides,
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TranscriptDisplaySettingsSection(
          mediaId: 'media-gating',
          readiness: readiness,
        ),
      ),
    ),
  );
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('line-only disables karaoke/IPA and shows enrich', (
    tester,
  ) async {
    final karaoke = _SpyKaraoke(true);
    await tester.pumpWidget(
      _harness(
        karaoke: karaoke,
        readiness: const TranscriptDisplayReadiness(
          hasNestedWords: false,
          hasTimedWords: false,
          hasPhones: false,
          canTrustWordTimes: true,
          karaokeSwitchEnabled: false,
          ipaSwitchEnabled: false,
          showEnrich: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(3));
    expect(switches.first.onChanged, isNotNull);
    expect(switches[1].onChanged, isNull);
    expect(switches[2].onChanged, isNull);
    expect(find.text(l10n.transcriptBlurDisplayTitle), findsOneWidget);
    expect(find.byType(TranscriptBusyListTile), findsOneWidget);
    expect(find.text(l10n.transcriptEnrichOwnedTitle), findsOneWidget);

    await tester.tap(find.byType(SubtitleToggleTile).first);
    await tester.pump();
    expect(karaoke.writes, 0);
  });

  testWidgets('blur switch flips transcriptBlurModeProvider', (tester) async {
    await tester.pumpWidget(
      _harness(
        karaoke: KaraokeHighlightSettingsOverride(false),
        extraOverrides: [
          playerInteractionsProvider.overrideWith(
            (ref) => _ToggleBlurInteractions(ref),
          ),
        ],
        readiness: const TranscriptDisplayReadiness(
          hasNestedWords: false,
          hasTimedWords: false,
          hasPhones: false,
          canTrustWordTimes: true,
          karaokeSwitchEnabled: false,
          ipaSwitchEnabled: false,
          showEnrich: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TranscriptDisplaySettingsSection)),
    );
    expect(container.read(transcriptBlurModeProvider), isFalse);

    await tester.tap(find.byType(SubtitleToggleTile).first);
    await tester.pumpAndSettle();
    expect(container.read(transcriptBlurModeProvider), isTrue);
  });

  testWidgets('timed+phones+owned enables switches and hides enrich', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        karaoke: KaraokeHighlightSettingsOverride(true),
        readiness: const TranscriptDisplayReadiness(
          hasNestedWords: true,
          hasTimedWords: true,
          hasPhones: true,
          canTrustWordTimes: true,
          karaokeSwitchEnabled: true,
          ipaSwitchEnabled: true,
          showEnrich: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(3));
    expect(switches[1].onChanged, isNotNull);
    expect(switches[1].value, isTrue);
    expect(find.byType(TranscriptBusyListTile), findsNothing);
  });

  testWidgets('YouTube enrich copy when word times are not trusted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        karaoke: KaraokeHighlightSettingsOverride(false),
        readiness: const TranscriptDisplayReadiness(
          hasNestedWords: false,
          hasTimedWords: false,
          hasPhones: false,
          canTrustWordTimes: false,
          karaokeSwitchEnabled: false,
          ipaSwitchEnabled: false,
          showEnrich: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.transcriptEnrichYoutubeTitle), findsOneWidget);
    expect(
      find.text(l10n.transcriptKaraokeUnavailableRemoteHint),
      findsOneWidget,
    );
  });

  testWidgets('running enrich tile shows cue progress', (tester) async {
    await tester.pumpWidget(
      _harness(
        karaoke: KaraokeHighlightSettingsOverride(false),
        extraOverrides: [
          transcriptEnrichmentControllerProvider(
            'media-gating',
          ).overrideWithValue(
            const TranscriptEnrichmentState.running(completed: 12, total: 240),
          ),
        ],
        readiness: const TranscriptDisplayReadiness(
          hasNestedWords: false,
          hasTimedWords: false,
          hasPhones: false,
          canTrustWordTimes: true,
          karaokeSwitchEnabled: false,
          ipaSwitchEnabled: false,
          showEnrich: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(l10n.transcriptEnrichCancel), findsOneWidget);
    expect(find.text(l10n.transcriptEnrichProgress(12, 240)), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('owned nested words without phones still show enrich', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        karaoke: KaraokeHighlightSettingsOverride(false),
        readiness: const TranscriptDisplayReadiness(
          hasNestedWords: true,
          hasTimedWords: true,
          hasPhones: false,
          canTrustWordTimes: true,
          karaokeSwitchEnabled: true,
          ipaSwitchEnabled: false,
          showEnrich: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TranscriptBusyListTile), findsOneWidget);
    expect(find.text(l10n.transcriptEnrichOwnedTitle), findsOneWidget);
  });
}
