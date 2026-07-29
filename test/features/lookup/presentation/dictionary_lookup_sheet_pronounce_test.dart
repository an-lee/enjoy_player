import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/lookup/domain/lookup_request.dart';
import 'package:enjoy_player/features/lookup/presentation/dictionary_lookup_sheet.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class _AuthSignedOutCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
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

Widget _harness({required List<Override> overrides, required Widget child}) {
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
  late AppDatabase db;
  late _TrackingPlaybackController playback;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    playback = _TrackingPlaybackController();
  });

  tearDown(() async {
    await db.close();
  });

  const request = LookupRequest(
    selectedText: 'hello world',
    sourceLanguage: 'en-US',
    targetLanguage: 'zh-CN',
  );

  testWidgets('lookup header includes pronounce control', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _harness(
        overrides: [
          authCtrlProvider.overrideWith(_AuthSignedOutCtrl.new),
          appDatabaseProvider.overrideWithValue(db),
          pronouncePlaybackControllerProvider.overrideWith(() => playback),
        ],
        child: const SizedBox(
          height: 600,
          child: DictionaryLookupSheet(request: request),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PronounceIconButton), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('dispose calls pronounce stop', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _harness(
        overrides: [
          authCtrlProvider.overrideWith(_AuthSignedOutCtrl.new),
          appDatabaseProvider.overrideWithValue(db),
          pronouncePlaybackControllerProvider.overrideWith(() => playback),
        ],
        child: const SizedBox(
          height: 600,
          child: DictionaryLookupSheet(request: request),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(playback.stopCount, greaterThan(0));
  });
}
