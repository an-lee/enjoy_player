import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/subtitle/transcript_display_readiness.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
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

Widget _harness({
  required TranscriptDisplayReadiness readiness,
  required KaraokeHighlightSettings karaoke,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
  return ProviderScope(
    overrides: [
      karaokeHighlightSettingsProvider.overrideWith(() => karaoke),
      ...transcriptIpaOverlayOffOverrides(),
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
    expect(switches, hasLength(2));
    expect(switches.every((s) => s.onChanged == null), isTrue);
    expect(switches.every((s) => s.value == false), isTrue);
    expect(find.byType(TranscriptBusyListTile), findsOneWidget);
    expect(find.text(l10n.transcriptEnrichOwnedTitle), findsOneWidget);

    await tester.tap(find.byType(SubtitleToggleTile).first);
    await tester.pump();
    expect(karaoke.writes, 0);
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
    expect(switches.first.onChanged, isNotNull);
    expect(switches.first.value, isTrue);
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
}
