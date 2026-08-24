import 'package:drift/native.dart';
import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/update_profile_request.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _kProfile = UserProfile(
  id: 'user-1',
  email: 'test@example.com',
  name: 'Test',
  locale: 'en-US',
  learningLanguage: 'ja-JP',
  nativeLanguage: 'zh-CN',
);

const _kEmptyProfile = UserProfile(
  id: 'user-1',
  email: 'test@example.com',
  name: 'Test',
);

class _SignedInAuthCtrl extends AuthCtrl {
  _SignedInAuthCtrl([UserProfile? profile]) : _profile = profile ?? _kProfile;

  final UserProfile _profile;
  final List<UpdateProfileRequest> updateProfileCalls = [];
  final List<Locale?> syncLocaleCalls = [];

  @override
  Future<AuthState> build() async => AuthSignedIn(profile: _profile);

  @override
  Future<void> updateProfile(UpdateProfileRequest request) async {
    updateProfileCalls.add(request);
  }

  @override
  Future<void> syncLocaleToServerIfSignedIn(Locale? locale) async {
    syncLocaleCalls.add(locale);
  }
}

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();

  @override
  Future<void> updateProfile(UpdateProfileRequest request) async {}

  @override
  Future<void> syncLocaleToServerIfSignedIn(Locale? locale) async {}
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('themeModeFromStorage', () {
    test('maps known values and defaults to system', () {
      expect(themeModeFromStorage('light'), ThemeMode.light);
      expect(themeModeFromStorage('dark'), ThemeMode.dark);
      expect(themeModeFromStorage('system'), ThemeMode.system);
      expect(themeModeFromStorage(null), ThemeMode.system);
      expect(themeModeFromStorage('nope'), ThemeMode.system);
    });

    test('themeModeToStorage round-trips', () {
      expect(themeModeToStorage(ThemeMode.light), 'light');
      expect(themeModeToStorage(ThemeMode.dark), 'dark');
      expect(themeModeToStorage(ThemeMode.system), 'system');
    });
  });

  group('AppPreferencesState', () {
    test('initial has default locale and null languages', () {
      const state = AppPreferencesState.initial;
      expect(state.locale, kAppDefaultDisplayLocale);
      expect(state.learningLanguage, isNull);
      expect(state.nativeLanguage, isNull);
    });

    group('effectiveLearningLanguage', () {
      test('returns canonical focus tag when learningLanguage is set', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'ja-JP',
        );
        expect(state.effectiveLearningLanguage, 'ja-JP');
      });

      test('returns default when learningLanguage is null', () {
        const state = AppPreferencesState(locale: Locale('en', 'US'));
        expect(state.effectiveLearningLanguage, kDefaultLearningLanguageTag);
      });

      test('canonicalizes non-standard tags', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'EN-us',
        );
        expect(state.effectiveLearningLanguage, 'en-US');
      });

      test('falls back to default for unsupported tags', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'de-DE',
        );
        expect(state.effectiveLearningLanguage, kDefaultLearningLanguageTag);
      });
    });

    group('effectiveNativeLanguage', () {
      test('returns native when it differs from learning', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'ja-JP',
          nativeLanguage: 'zh-CN',
        );
        expect(state.effectiveNativeLanguage, 'zh-CN');
      });

      test('coerces native when it equals learning', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'en-US',
          nativeLanguage: 'en-US',
        );
        expect(state.effectiveNativeLanguage, isNot('en-US'));
        expect(
          kSupportedNativeLanguageTags,
          contains(state.effectiveNativeLanguage),
        );
      });

      test('coerces null native to a valid default', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'ja-JP',
        );
        expect(
          kSupportedNativeLanguageTags,
          contains(state.effectiveNativeLanguage),
        );
      });
    });

    group('effectiveDisplayLocale', () {
      test('returns locale when set', () {
        const state = AppPreferencesState(locale: Locale('en', 'US'));
        expect(state.effectiveDisplayLocale, const Locale('en', 'US'));
      });

      test('returns default when locale is null', () {
        const state = AppPreferencesState(locale: null);
        expect(state.effectiveDisplayLocale, kAppDefaultDisplayLocale);
      });
    });

    group('copyWith', () {
      test('replaces locale', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'ja-JP',
          nativeLanguage: 'zh-CN',
        );
        final next = state.copyWith(locale: const Locale('zh', 'CN'));
        expect(next.locale, const Locale('zh', 'CN'));
        expect(next.learningLanguage, 'ja-JP');
        expect(next.nativeLanguage, 'zh-CN');
      });

      test('replaces learningLanguage', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'ja-JP',
          nativeLanguage: 'zh-CN',
        );
        final next = state.copyWith(learningLanguage: 'ko-KR');
        expect(next.learningLanguage, 'ko-KR');
        expect(next.locale, const Locale('en', 'US'));
        expect(next.nativeLanguage, 'zh-CN');
      });

      test('replaces nativeLanguage', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'ja-JP',
          nativeLanguage: 'zh-CN',
        );
        final next = state.copyWith(nativeLanguage: 'en-US');
        expect(next.nativeLanguage, 'en-US');
        expect(next.locale, const Locale('en', 'US'));
        expect(next.learningLanguage, 'ja-JP');
      });

      test('preserves all fields when no arguments given', () {
        const state = AppPreferencesState(
          locale: Locale('en', 'US'),
          learningLanguage: 'ja-JP',
          nativeLanguage: 'zh-CN',
        );
        final next = state.copyWith();
        expect(next.locale, state.locale);
        expect(next.learningLanguage, state.learningLanguage);
        expect(next.nativeLanguage, state.nativeLanguage);
      });
    });
  });

  group('AppPreferencesCtrl', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<ProviderContainer> signedInContainer({
      UserProfile profile = _kProfile,
    }) async {
      final container = ProviderContainer(
        overrides: [
          authCtrlProvider.overrideWith(() => _SignedInAuthCtrl(profile)),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      await container.read(authCtrlProvider.future);
      return container;
    }

    Future<ProviderContainer> signedOutContainer() async {
      final container = ProviderContainer(
        overrides: [
          authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      await container.read(authCtrlProvider.future);
      return container;
    }

    group('build', () {
      test('returns initial state when signed out', () async {
        final container = await signedOutContainer();
        addTearDown(container.dispose);

        final state = await container.read(appPreferencesCtrlProvider.future);
        expect(state.locale, kAppDefaultDisplayLocale);
        expect(state.learningLanguage, isNull);
        expect(state.nativeLanguage, isNull);
        expect(state.themeMode, ThemeMode.system);
      });

      test('reads and normalizes stored prefs when signed in', () async {
        await db.settingsDao.setValue(SettingsKeys.prefsLocale, 'en-US');
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'ja-JP',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'zh-CN',
        );

        final container = await signedInContainer();
        addTearDown(container.dispose);

        await container.read(appPreferencesCtrlProvider.future);
        await _pump();
        final settled = container.read(appPreferencesCtrlProvider).valueOrNull!;
        expect(settled.locale, const Locale('en', 'US'));
        expect(settled.learningLanguage, 'ja-JP');
        expect(settled.nativeLanguage, 'zh-CN');
      });

      test('reads stored theme mode when signed in', () async {
        await db.settingsDao.setValue(SettingsKeys.prefsThemeMode, 'light');

        final container = await signedInContainer();
        addTearDown(container.dispose);

        await container.read(appPreferencesCtrlProvider.future);
        await _pump();
        final settled = container.read(appPreferencesCtrlProvider).valueOrNull!;
        expect(settled.themeMode, ThemeMode.light);
      });

      test('canonicalizes non-standard learning language in DB', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'EN-us',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'zh-CN',
        );

        final container = await signedInContainer(profile: _kEmptyProfile);
        addTearDown(container.dispose);

        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        final stored = await db.settingsDao.getValue(
          SettingsKeys.prefsLearningLanguage,
        );
        expect(stored, 'en-US');
      });

      test('coerces native language when it equals learning in DB', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'en-US',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'en-US',
        );

        final container = await signedInContainer(profile: _kEmptyProfile);
        addTearDown(container.dispose);

        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        final stored = await db.settingsDao.getValue(
          SettingsKeys.prefsNativeLanguage,
        );
        expect(stored, isNot('en-US'));
        expect(kSupportedNativeLanguageTags, contains(stored));
      });

      test('defaults learning language when DB value is null', () async {
        final container = await signedInContainer(profile: _kEmptyProfile);
        addTearDown(container.dispose);

        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        final state = container.read(appPreferencesCtrlProvider).valueOrNull!;
        expect(state.learningLanguage, kDefaultLearningLanguageTag);
      });

      test('defaults locale when DB value is null', () async {
        final container = await signedInContainer(profile: _kEmptyProfile);
        addTearDown(container.dispose);

        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        final state = container.read(appPreferencesCtrlProvider).valueOrNull!;
        expect(state.locale, kAppDefaultDisplayLocale);
      });

      test('normalizes locale raw value in DB', () async {
        await db.settingsDao.setValue(SettingsKeys.prefsLocale, 'en');

        final container = await signedInContainer(profile: _kEmptyProfile);
        addTearDown(container.dispose);

        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        final state = container.read(appPreferencesCtrlProvider).valueOrNull!;
        expect(state.locale, const Locale('en', 'US'));
      });

      test('falls back to default locale for unsupported raw value', () async {
        await db.settingsDao.setValue(SettingsKeys.prefsLocale, 'fr-FR');

        final container = await signedInContainer(profile: _kEmptyProfile);
        addTearDown(container.dispose);

        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        final state = container.read(appPreferencesCtrlProvider).valueOrNull!;
        expect(state.locale, kAppDefaultDisplayLocale);
      });
    });

    group('setLocale', () {
      test('updates state and persists to DB', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLocale(const Locale('en', 'US'));

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.locale, const Locale('en', 'US'));

        final stored = await db.settingsDao.getValue(SettingsKeys.prefsLocale);
        expect(stored, 'en-US');
      });

      test('null locale resolves to default', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLocale(null);

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.locale, kAppDefaultDisplayLocale);
      });

      test('syncs locale to server when signed in', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLocale(const Locale('zh', 'CN'));

        final authCtrl =
            container.read(authCtrlProvider.notifier) as _SignedInAuthCtrl;
        expect(authCtrl.syncLocaleCalls, contains(const Locale('zh', 'CN')));
      });

      test('unsupported locale resolves to default', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLocale(const Locale('fr', 'FR'));

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.locale, kAppDefaultDisplayLocale);
      });
    });

    group('setLearningLanguage', () {
      test('updates state and persists canonical tag', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLearningLanguage('ko-KR');

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.learningLanguage, 'ko-KR');

        final stored = await db.settingsDao.getValue(
          SettingsKeys.prefsLearningLanguage,
        );
        expect(stored, 'ko-KR');
      });

      test('rejects unsupported learning language tag', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLearningLanguage('de-DE');

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.learningLanguage, isNot('de-DE'));
      });

      test('coerces native when it equals new learning language', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'ja-JP',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'en-US',
        );

        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLearningLanguage('en-US');

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.learningLanguage, 'en-US');
        expect(state.nativeLanguage, isNot('en-US'));
        expect(kSupportedNativeLanguageTags, contains(state.nativeLanguage));
      });

      test('persists coerced native language to DB', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'ja-JP',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'en-US',
        );

        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLearningLanguage('en-US');

        final storedNative = await db.settingsDao.getValue(
          SettingsKeys.prefsNativeLanguage,
        );
        expect(storedNative, isNot('en-US'));
      });

      test('syncs language fields to server when signed in', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLearningLanguage('fr-FR');

        final authCtrl =
            container.read(authCtrlProvider.notifier) as _SignedInAuthCtrl;
        expect(authCtrl.updateProfileCalls, isNotEmpty);
        final lastCall = authCtrl.updateProfileCalls.last;
        expect(lastCall.learningLanguage, 'fr-FR');
      });

      test('canonicalizes case-insensitive input', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setLearningLanguage('JA-jp');

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.learningLanguage, 'ja-JP');
      });
    });

    group('setNativeLanguage', () {
      test('updates state and persists to DB', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'ja-JP',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'zh-CN',
        );

        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setNativeLanguage('en-US');

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.nativeLanguage, 'en-US');

        final stored = await db.settingsDao.getValue(
          SettingsKeys.prefsNativeLanguage,
        );
        expect(stored, 'en-US');
      });

      test('rejects tag not in allowed native tags', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'ja-JP',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'zh-CN',
        );

        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setNativeLanguage('ja-JP');

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.nativeLanguage, 'zh-CN');
      });

      test('no-op when native equals learning language', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'en-US',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'zh-CN',
        );

        final container = await signedInContainer(profile: _kEmptyProfile);
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setNativeLanguage('en-US');

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.nativeLanguage, 'zh-CN');
      });

      test('syncs language fields to server when signed in', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'ja-JP',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'zh-CN',
        );

        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setNativeLanguage('en-US');

        final authCtrl =
            container.read(authCtrlProvider.notifier) as _SignedInAuthCtrl;
        expect(authCtrl.updateProfileCalls, isNotEmpty);
        final lastCall = authCtrl.updateProfileCalls.last;
        expect(lastCall.nativeLanguage, 'en-US');
        expect(lastCall.learningLanguage, 'ja-JP');
      });
    });

    group('applyFromUserProfile', () {
      test('applies locale from profile', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .applyFromUserProfile(
              const UserProfile(
                id: 'user-1',
                email: 'test@example.com',
                name: 'Test',
                locale: 'zh-CN',
                learningLanguage: 'ko-KR',
                nativeLanguage: 'en-US',
              ),
            );

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.locale, const Locale('zh', 'CN'));
        expect(state.learningLanguage, 'ko-KR');
        expect(state.nativeLanguage, 'en-US');
      });

      test('preserves current locale when profile locale is null', () async {
        await db.settingsDao.setValue(SettingsKeys.prefsLocale, 'en-US');

        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .applyFromUserProfile(
              const UserProfile(
                id: 'user-1',
                email: 'test@example.com',
                name: 'Test',
                learningLanguage: 'fr-FR',
                nativeLanguage: 'zh-CN',
              ),
            );

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.locale, const Locale('en', 'US'));
      });

      test('preserves current locale when profile locale is blank', () async {
        await db.settingsDao.setValue(SettingsKeys.prefsLocale, 'en-US');

        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .applyFromUserProfile(
              const UserProfile(
                id: 'user-1',
                email: 'test@example.com',
                name: 'Test',
                locale: '  ',
                learningLanguage: 'fr-FR',
                nativeLanguage: 'zh-CN',
              ),
            );

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.locale, const Locale('en', 'US'));
      });

      test('canonicalizes learning language from profile', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .applyFromUserProfile(
              const UserProfile(
                id: 'user-1',
                email: 'test@example.com',
                name: 'Test',
                learningLanguage: 'EN-gb',
                nativeLanguage: 'zh-CN',
              ),
            );

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.learningLanguage, 'en-GB');
      });

      test('coerces native when it equals learning from profile', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .applyFromUserProfile(
              const UserProfile(
                id: 'user-1',
                email: 'test@example.com',
                name: 'Test',
                learningLanguage: 'en-US',
                nativeLanguage: 'en-US',
              ),
            );

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.nativeLanguage, isNot('en-US'));
        expect(kSupportedNativeLanguageTags, contains(state.nativeLanguage));
      });

      test('persists all fields to DB', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .applyFromUserProfile(
              const UserProfile(
                id: 'user-1',
                email: 'test@example.com',
                name: 'Test',
                locale: 'zh-CN',
                learningLanguage: 'ko-KR',
                nativeLanguage: 'en-US',
              ),
            );

        final storedLocale = await db.settingsDao.getValue(
          SettingsKeys.prefsLocale,
        );
        final storedLearn = await db.settingsDao.getValue(
          SettingsKeys.prefsLearningLanguage,
        );
        final storedNative = await db.settingsDao.getValue(
          SettingsKeys.prefsNativeLanguage,
        );
        expect(storedLocale, 'zh-CN');
        expect(storedLearn, 'ko-KR');
        expect(storedNative, 'en-US');
      });

      test('patches server when profile tags differ from canonical', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .applyFromUserProfile(
              const UserProfile(
                id: 'user-1',
                email: 'test@example.com',
                name: 'Test',
                learningLanguage: 'eng',
                nativeLanguage: 'zho',
              ),
            );

        final authCtrl =
            container.read(authCtrlProvider.notifier) as _SignedInAuthCtrl;
        expect(authCtrl.updateProfileCalls, isNotEmpty);
      });

      test(
        'does not patch server when profile tags are already canonical',
        () async {
          final container = await signedInContainer();
          addTearDown(container.dispose);
          await container.read(appPreferencesCtrlProvider.future);
          await _pump();

          final authCtrl =
              container.read(authCtrlProvider.notifier) as _SignedInAuthCtrl;
          final callsBefore = authCtrl.updateProfileCalls.length;

          await container
              .read(appPreferencesCtrlProvider.notifier)
              .applyFromUserProfile(
                const UserProfile(
                  id: 'user-1',
                  email: 'test@example.com',
                  name: 'Test',
                  learningLanguage: 'ja-JP',
                  nativeLanguage: 'zh-CN',
                ),
              );

          expect(authCtrl.updateProfileCalls.length, callsBefore);
        },
      );

      test('uses previous learning when profile learning is null', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'ko-KR',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'zh-CN',
        );

        final container = await signedInContainer(profile: _kEmptyProfile);
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .applyFromUserProfile(
              const UserProfile(
                id: 'user-1',
                email: 'test@example.com',
                name: 'Test',
                nativeLanguage: 'zh-CN',
              ),
            );

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.learningLanguage, 'ko-KR');
      });

      test('uses previous native when profile native is null', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'ja-JP',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'en-US',
        );

        final container = await signedInContainer(profile: _kEmptyProfile);
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);
        await _pump();

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .applyFromUserProfile(
              const UserProfile(
                id: 'user-1',
                email: 'test@example.com',
                name: 'Test',
                learningLanguage: 'ja-JP',
              ),
            );

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.nativeLanguage, 'en-US');
      });
    });

    group('setThemeMode', () {
      test('persists when signed in', () async {
        final container = await signedInContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setThemeMode(ThemeMode.light);

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.themeMode, ThemeMode.light);
        expect(
          await db.settingsDao.getValue(SettingsKeys.prefsThemeMode),
          'light',
        );
      });

      test('updates memory but does not write DB when signed out', () async {
        final container = await signedOutContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setThemeMode(ThemeMode.dark);

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.themeMode, ThemeMode.dark);
        expect(
          await db.settingsDao.getValue(SettingsKeys.prefsThemeMode),
          isNull,
        );
      });
    });

    group('signed-out server sync', () {
      test(
        'setLearningLanguage does not call server when signed out',
        () async {
          final container = await signedOutContainer();
          addTearDown(container.dispose);
          await container.read(appPreferencesCtrlProvider.future);

          await container
              .read(appPreferencesCtrlProvider.notifier)
              .setLearningLanguage('ko-KR');

          final state = container.read(appPreferencesCtrlProvider).valueOrNull;
          expect(state!.learningLanguage, 'ko-KR');
        },
      );

      test('setNativeLanguage does not call server when signed out', () async {
        await db.settingsDao.setValue(
          SettingsKeys.prefsLearningLanguage,
          'ja-JP',
        );
        await db.settingsDao.setValue(
          SettingsKeys.prefsNativeLanguage,
          'zh-CN',
        );

        final container = await signedOutContainer();
        addTearDown(container.dispose);
        await container.read(appPreferencesCtrlProvider.future);

        await container
            .read(appPreferencesCtrlProvider.notifier)
            .setNativeLanguage('zh-CN');

        final state = container.read(appPreferencesCtrlProvider).valueOrNull;
        expect(state!.nativeLanguage, 'zh-CN');
      });
    });
  });
}
