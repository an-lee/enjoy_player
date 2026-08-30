import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/craft/application/craft_preferences_provider.dart';
import 'package:enjoy_player/features/craft/domain/craft_preferences.dart';
import 'package:enjoy_player/features/craft/domain/craft_screen_mode.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';

class _SignedInAuthCtrl extends AuthCtrl {
  _SignedInAuthCtrl(this.profile);
  final UserProfile profile;
  @override
  Future<AuthState> build() async => AuthSignedIn(profile: profile);
}

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

const _profile = UserProfile(id: 'user-1', email: 'a@b.com', name: 'Tester');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<String?> storedRaw() =>
      db.settingsDao.getValue(SettingsKeys.craftPreferencesV1);

  ProviderContainer container({UserProfile? profile = _profile}) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        if (profile == null)
          authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new)
        else
          authCtrlProvider.overrideWith(() => _SignedInAuthCtrl(profile)),
      ],
    );
  }

  group('load', () {
    test('hydrates a persisted blob', () async {
      const persisted = CraftPreferences(
        screenMode: CraftScreenMode.advanced,
        advancedStyle: TranslationStyle.formal,
        customPrompt: 'keep it short',
        voices: {'en': 'en-US-GuyNeural'},
      );
      await db.settingsDao.setValue(
        SettingsKeys.craftPreferencesV1,
        jsonEncode(persisted.toJson()),
      );

      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final prefs = await c.read(craftPreferencesCtrlProvider.notifier).load();

      expect(prefs, persisted);
      expect(c.read(craftPreferencesCtrlProvider), persisted);
    });

    test('returns defaults when nothing is stored', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final prefs = await c.read(craftPreferencesCtrlProvider.notifier).load();
      expect(prefs, CraftPreferences.defaults);
    });

    test('falls back to defaults on a corrupt blob', () async {
      await db.settingsDao.setValue(
        SettingsKeys.craftPreferencesV1,
        'not json at all',
      );
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final prefs = await c.read(craftPreferencesCtrlProvider.notifier).load();
      expect(prefs, CraftPreferences.defaults);
    });

    test('is single-flight', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final notifier = c.read(craftPreferencesCtrlProvider.notifier);
      expect(identical(notifier.load(), notifier.load()), isTrue);
      await notifier.load();
    });

    test('returns defaults without touching the DB when signed out', () async {
      final c = container(profile: null);
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final prefs = await c.read(craftPreferencesCtrlProvider.notifier).load();
      expect(prefs, CraftPreferences.defaults);
      expect(await storedRaw(), isNull);
    });
  });

  group('setters', () {
    test('setScreenMode persists', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final notifier = c.read(craftPreferencesCtrlProvider.notifier);
      await notifier.setScreenMode(CraftScreenMode.advanced);
      final prefs = c.read(craftPreferencesCtrlProvider);
      expect(prefs.screenMode, CraftScreenMode.advanced);
      expect(
        CraftPreferences.fromJson(
          jsonDecode((await storedRaw())!) as Map<String, dynamic>,
        ),
        prefs,
      );
    });

    test('setStyleFor persists per mode', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final notifier = c.read(craftPreferencesCtrlProvider.notifier);
      await notifier.setStyleFor(
        CraftScreenMode.express,
        TranslationStyle.casual,
      );
      await notifier.setStyleFor(
        CraftScreenMode.advanced,
        TranslationStyle.formal,
      );
      final prefs = c.read(craftPreferencesCtrlProvider);
      expect(prefs.expressStyle, TranslationStyle.casual);
      expect(prefs.advancedStyle, TranslationStyle.formal);
      expect(
        CraftPreferences.fromJson(
          jsonDecode((await storedRaw())!) as Map<String, dynamic>,
        ),
        prefs,
      );
    });

    test('setCustomPrompt persists; empty clears', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final notifier = c.read(craftPreferencesCtrlProvider.notifier);
      await notifier.setCustomPrompt('be poetic');
      expect(c.read(craftPreferencesCtrlProvider).customPrompt, 'be poetic');

      await notifier.setCustomPrompt('');
      expect(c.read(craftPreferencesCtrlProvider).customPrompt, isNull);
      expect(
        CraftPreferences.fromJson(
          jsonDecode((await storedRaw())!) as Map<String, dynamic>,
        ).customPrompt,
        isNull,
      );
    });

    test('setVoice persists per base language; null removes', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final notifier = c.read(craftPreferencesCtrlProvider.notifier);
      await notifier.setVoice('en', 'en-US-GuyNeural');
      await notifier.setVoice('JA', 'ja-JP-NanamiNeural');
      expect(c.read(craftPreferencesCtrlProvider).voices, {
        'en': 'en-US-GuyNeural',
        'ja': 'ja-JP-NanamiNeural',
      });

      await notifier.setVoice('en', null);
      final prefs = c.read(craftPreferencesCtrlProvider);
      expect(prefs.voices, {'ja': 'ja-JP-NanamiNeural'});
      expect(
        CraftPreferences.fromJson(
          jsonDecode((await storedRaw())!) as Map<String, dynamic>,
        ).voices,
        {'ja': 'ja-JP-NanamiNeural'},
      );
    });

    test('setters update state but write nothing when signed out', () async {
      final c = container(profile: null);
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final notifier = c.read(craftPreferencesCtrlProvider.notifier);
      await notifier.setScreenMode(CraftScreenMode.advanced);
      await notifier.setStyleFor(
        CraftScreenMode.advanced,
        TranslationStyle.formal,
      );
      expect(
        c.read(craftPreferencesCtrlProvider).screenMode,
        CraftScreenMode.advanced,
      );
      expect(
        c.read(craftPreferencesCtrlProvider).advancedStyle,
        TranslationStyle.formal,
      );
      expect(await storedRaw(), isNull);
    });
  });
}
