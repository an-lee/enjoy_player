import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/library/domain/practice_resume.dart';
import 'package:enjoy_player/features/library/presentation/widgets/continue_practice_card.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

PracticeResume _resume({
  String id = 'media-1',
  String title = 'Sample talk',
  int durationMs = 100000,
  int positionMs = 40000,
  bool echoActive = false,
}) {
  final ts = DateTime.utc(2026, 1, 1);
  return PracticeResume(
    media: Media(
      id: id,
      kind: MediaKind.video,
      title: title,
      sourceUri: 'file:///$id',
      durationMs: durationMs,
      language: 'en-US',
      contentHash: id,
      fileSize: 1,
      provider: 'youtube',
      createdAt: ts,
      updatedAt: ts,
    ),
    positionMs: positionMs,
    echoActive: echoActive,
    lastActiveAt: ts,
    sessionId: 'session-1',
  );
}

Widget _harness({required GoRouter router, required PracticeResume resume}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows title, progress, and opens player on tap', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              Scaffold(body: ContinuePracticeCard(resume: _resume())),
        ),
        GoRoute(
          path: '/player/:mediaId',
          builder: (context, state) =>
              Text('player:${state.pathParameters['mediaId']}'),
        ),
      ],
    );

    await tester.pumpWidget(_harness(router: router, resume: _resume()));
    await tester.pumpAndSettle();

    expect(find.text('Sample talk'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(ContinuePracticeCard));
    await tester.pumpAndSettle();
    expect(find.text('player:media-1'), findsOneWidget);
  });

  testWidgets('shows Echo when echoActive', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: ContinuePracticeCard(resume: _resume(echoActive: true)),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      _harness(router: router, resume: _resume(echoActive: true)),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.textContaining(l10n.echoMode), findsWidgets);
  });

  testWidgets('omits progress bar when duration is unknown', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: ContinuePracticeCard(
              resume: _resume(durationMs: 0, positionMs: 0),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      _harness(router: router, resume: _resume(durationMs: 0)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
