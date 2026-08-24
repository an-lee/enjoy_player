import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';
import 'package:enjoy_player/features/player/presentation/widgets/transport/transport_cc_fullscreen.dart';
import 'package:enjoy_player/features/transcript/application/all_transcripts_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_fetch_controller.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_fetch_status.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_track.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../../helpers/chrome_icon_finders.dart';

Widget _harness({required Widget child, required List<Override> overrides}) {
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
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  const mediaId = 'media-test';

  testWidgets('TransportCcButton shows spinner while fetching without tracks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        overrides: [
          allTranscriptsForMediaProvider(
            mediaId,
          ).overrideWith((ref) => Stream.value(const <TranscriptTrack>[])),
          transcriptFetchCtrlProvider(mediaId).overrideWithValue(
            const TranscriptFetchUiState(status: TranscriptFetchStatus.loading),
          ),
        ],
        child: const TransportCcButton(mediaId: mediaId),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'TransportCcButton keeps CC icon when tracks exist while loading',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            allTranscriptsForMediaProvider(mediaId).overrideWith(
              (ref) => Stream.value([
                const TranscriptTrack(
                  id: 't1',
                  targetType: 'Video',
                  targetId: mediaId,
                  language: 'en',
                  source: 'user',
                  label: 'en',
                  trackIndex: null,
                ),
              ]),
            ),
            transcriptFetchCtrlProvider(mediaId).overrideWithValue(
              const TranscriptFetchUiState(
                status: TranscriptFetchStatus.loading,
              ),
            ),
          ],
          child: const TransportCcButton(mediaId: mediaId),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(findChromeIcon(EnjoyChromeGlyph.cc), findsOneWidget);
    },
  );
}
