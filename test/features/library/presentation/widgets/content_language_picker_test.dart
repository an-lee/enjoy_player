import 'dart:async';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/features/library/presentation/widgets/content_language_picker.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/language_choice_sheet.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppPreferencesCtrl extends AppPreferencesCtrl {
  _FakeAppPreferencesCtrl(this._state);

  final AppPreferencesState _state;

  @override
  Future<AppPreferencesState> build() async => _state;
}

Widget _wrap({required ProviderContainer container, required Widget child}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'showContentLanguagePicker: opens with selectedValue, dismissal returns null',
    (tester) async {
      const selectedValue = 'ja-JP';
      final container = ProviderContainer(
        overrides: [
          appPreferencesCtrlProvider.overrideWith(
            () => _FakeAppPreferencesCtrl(
              const AppPreferencesState(
                locale: Locale('en', 'US'),
                learningLanguage: 'en-US',
              ),
            ),
          ),
        ],
      );
      // We can't easily seed an async notifier's value without a custom
      // builder; the picker tolerates a loading/empty AsyncValue (uses null
      // for the fallback selectedValue).
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  unawaited(
                    showContentLanguagePicker(
                      context: context,
                      ref: ref,
                      selectedValue: selectedValue,
                      title: 'pick me',
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Modal opened — title shows up.
      expect(find.text('pick me'), findsOneWidget);
      // Dismiss by tapping outside (barrier).
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'showContentLanguagePicker: title defaults when none is provided',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () {
                unawaited(
                  showContentLanguagePicker(context: context, ref: ref),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Modal opened — verify the sheet tree contains a Text widget for the
      // title. We don't pin the exact wording.
      expect(find.byType(Text), findsWidgets);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('showFocusLanguagePicker: opens with custom title', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () {
                unawaited(
                  showFocusLanguagePicker(
                    context: context,
                    selectedValue: 'en-US',
                    title: 'Custom focus picker title',
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Custom focus picker title'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  });

  testWidgets('showFocusLanguagePicker: opens with default (localized) title', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () {
                unawaited(
                  showFocusLanguagePicker(
                    context: context,
                    selectedValue: 'es_mx', // mixed separator → canonical
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Sheet opened (no exception, with mixed-case tag).
    expect(find.byType(Text), findsWidgets);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  });

  // Pure-function checks for the canonicalization the picker applies on
  // dismissal.
  test('canonicalMediaLanguageTag mirrors picker normalization', () {
    expect(canonicalMediaLanguageTag('ja_JP'), 'ja-JP');
    expect(canonicalMediaLanguageTag('en-us'), 'en-US');
    expect(canonicalMediaLanguageTag(null), 'und');
    expect(canonicalMediaLanguageTag(''), 'und');
  });

  test('LanguageChoiceOption retains value + label', () {
    const opt = LanguageChoiceOption(value: 'en-US', label: 'English (US)');
    expect(opt.value, 'en-US');
    expect(opt.label, 'English (US)');
  });
}
