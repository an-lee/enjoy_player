import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class _FixedPlaybackController extends PronouncePlaybackController {
  _FixedPlaybackController(this.initial);
  final PronouncePlaybackState initial;

  @override
  PronouncePlaybackState build() => initial;
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('unsupported locale disables with unavailable tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const PronounceIconButton(
          text: 'مرحبا',
          localeTag: 'ar-SA',
          surfaceId: PronounceSurfaceId.lookup,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(button.onPressed, isNull);
    expect(button.tooltip, l10n.pronounceUnavailableLanguage);
  });

  testWidgets('loading state shows stop-capable spinner tooltip', (
    tester,
  ) async {
    final target = PronounceTarget.tryCreate(
      text: 'hello',
      localeTag: 'en-US',
      surfaceId: PronounceSurfaceId.lookup,
    )!;
    await tester.pumpWidget(
      _wrap(
        const PronounceIconButton(
          text: 'hello',
          localeTag: 'en-US',
          surfaceId: PronounceSurfaceId.lookup,
        ),
        overrides: [
          pronouncePlaybackControllerProvider.overrideWith(
            () => _FixedPlaybackController(
              PronouncePlaybackState(
                phase: PronouncePlaybackPhase.loading,
                target: target,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(button.tooltip, l10n.pronounceLoading);
  });

  testWidgets('playing state uses stop tooltip', (tester) async {
    final target = PronounceTarget.tryCreate(
      text: 'hello',
      localeTag: 'en-US',
      surfaceId: PronounceSurfaceId.lookup,
    )!;
    await tester.pumpWidget(
      _wrap(
        const PronounceIconButton(
          text: 'hello',
          localeTag: 'en-US',
          surfaceId: PronounceSurfaceId.lookup,
        ),
        overrides: [
          pronouncePlaybackControllerProvider.overrideWith(
            () => _FixedPlaybackController(
              PronouncePlaybackState(
                phase: PronouncePlaybackPhase.playing,
                target: target,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    final tooltip = find.byTooltip(l10n.pronounceStop);
    expect(tooltip, findsOneWidget);
  });
}
