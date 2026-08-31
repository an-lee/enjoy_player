import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
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

/// Play always fails with the given failure; used to drive the error paths.
class _ThrowingPlaybackController extends PronouncePlaybackController {
  _ThrowingPlaybackController(this.error);

  final Object error;

  @override
  PronouncePlaybackState build() =>
      const PronouncePlaybackState(phase: PronouncePlaybackPhase.idle);

  @override
  Future<void> play(PronounceTarget target) async => throw error;
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

  testWidgets(
    'credits failure shows the shared credits message, not raw text',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PronounceIconButton(
            text: 'hello',
            localeTag: 'en-US',
            surfaceId: PronounceSurfaceId.lookup,
          ),
          overrides: [
            pronouncePlaybackControllerProvider.overrideWith(
              () => _ThrowingPlaybackController(
                const CreditsFailure(
                  'HTTP 402',
                  requiredCredits: 1500,
                  usedCredits: 0,
                  limitCredits: 1000,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the (enabled) pronounce icon to trigger the failing play.
      await tester.tap(find.byType(IconButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('1500'), findsOneWidget);
      expect(find.text('HTTP 402'), findsNothing);
      // The one-tap recovery CTA rides on the warning snackbar (spec 045).
      expect(
        find.widgetWithText(TextButton, l10n.subscriptionViewPlansAndPackages),
        findsOneWidget,
      );
    },
  );
}
