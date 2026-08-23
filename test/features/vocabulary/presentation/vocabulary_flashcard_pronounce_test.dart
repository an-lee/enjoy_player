import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_source_title.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_flashcard.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class _AuthSignedInCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'test-user', email: 't@example.com', name: 'Test'),
  );
}

class _TrackingPlaybackController extends PronouncePlaybackController {
  int stopCount = 0;

  @override
  PronouncePlaybackState build() => const PronouncePlaybackState.idle();

  @override
  Future<void> stop() async {
    stopCount++;
    state = const PronouncePlaybackState.idle();
  }
}

VocabularyItem _item() => VocabularyItem(
  id: 'i1',
  word: 'hello',
  language: 'en',
  targetLanguage: 'zh',
  status: VocabularyStatus.new_,
  easeFactor: 2.5,
  interval: 0,
  nextReviewAt: DateTime.utc(2030),
  reviewsCount: 0,
  contextsCount: 1,
  createdAt: DateTime.utc(2020),
  updatedAt: DateTime.utc(2020),
);

VocabularyContext _context() => VocabularyContext(
  id: 'c1',
  vocabularyItemId: 'i1',
  text: 'Hello world.',
  sourceType: VocabularySourceType.video,
  sourceId: 'v1',
  locator: const MediaLocator(start: 1000, duration: 2000),
  createdAt: DateTime.utc(2020),
  updatedAt: DateTime.utc(2020),
);

void main() {
  late _TrackingPlaybackController playback;

  setUp(() {
    playback = _TrackingPlaybackController();
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        authCtrlProvider.overrideWith(_AuthSignedInCtrl.new),
        vocabularySourceTitleProvider.overrideWith((ref, id) async => 'Title'),
        pronouncePlaybackControllerProvider.overrideWith(() => playback),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('front exposes pronounce beside headword', (tester) async {
    await tester.pumpWidget(
      wrap(
        VocabularyFlashcard(
          item: _item(),
          primaryContext: _context(),
          flipped: false,
          dictionaryFetchInFlight: false,
          contextualFetchInFlight: false,
          clipPlayInFlight: false,
          onFlip: () {},
          onUnflip: () {},
          onFetchDictionary: () {},
          onFetchContextual: () {},
          onPlayClip: () {},
          onOpenInPlayer: () {},
          onShadowReading: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PronounceIconButton), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('unflip from back stops pronounce', (tester) async {
    var unflipped = false;
    await tester.pumpWidget(
      wrap(
        VocabularyFlashcard(
          item: _item(),
          primaryContext: _context(),
          flipped: true,
          dictionaryFetchInFlight: false,
          contextualFetchInFlight: false,
          clipPlayInFlight: false,
          onFlip: () {},
          onUnflip: () => unflipped = true,
          onFetchDictionary: () {},
          onFetchContextual: () {},
          onPlayClip: () {},
          onOpenInPlayer: () {},
          onShadowReading: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PronounceIconButton), findsOneWidget);

    await tester.tap(find.text('hello'));
    await tester.pump();
    expect(unflipped, isTrue);
    expect(playback.stopCount, greaterThan(0));
  });
}
