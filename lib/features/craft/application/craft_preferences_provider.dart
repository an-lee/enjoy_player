/// Persisted Craft preferences (Drift settings KV, JSON blob).
library;

import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/craft/domain/craft_preferences.dart';
import 'package:enjoy_player/features/craft/domain/craft_screen_mode.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';

part 'craft_preferences_provider.g.dart';

@Riverpod(keepAlive: true)
class CraftPreferencesCtrl extends _$CraftPreferencesCtrl {
  Future<CraftPreferences>? _loadFuture;

  /// Bumped by every setter so an in-flight [load] never clobbers values the
  /// user just chose.
  int _mutation = 0;

  /// Serializes writes; [load] awaits it so it never reads a row older than
  /// a setter that already ran. Each task encodes the latest state.
  Future<void> _persistQueue = Future<void>.value();

  @override
  CraftPreferences build() {
    _loadFuture = null;
    // Watching auth (not selecting) matches AppPreferencesCtrl: a sign-in
    // transition re-hydrates from that user's DB, sign-out drops to defaults.
    final auth = ref.watch(authCtrlProvider).valueOrNull;
    if (auth is AuthSignedIn) {
      unawaited(Future<void>.microtask(load));
    }
    return CraftPreferences.defaults;
  }

  /// Single-flight hydrate. Awaitable so callers never apply a pre-hydration
  /// snapshot; safe to call repeatedly.
  Future<CraftPreferences> load() => _loadFuture ??= _loadFromDb();

  Future<CraftPreferences> _loadFromDb() async {
    // Flush setters that already ran so the row we read includes them.
    await _persistQueue;
    final readGeneration = _mutation;
    CraftPreferences? loaded;
    try {
      final auth = ref.read(authCtrlProvider).valueOrNull;
      if (auth is AuthSignedIn) {
        final raw = await ref
            .read(appDatabaseProvider)
            .settingsDao
            .getValue(SettingsKeys.craftPreferencesV1);
        final decoded = raw == null ? null : jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          loaded = CraftPreferences.fromJson(decoded);
        }
      }
    } catch (e, st) {
      logNamed('craft.prefs').warning('Hydrate failed; using defaults', e, st);
    }
    // The provider went away mid-flight (screen left / container disposed).
    if (!ref.mounted) return loaded ?? CraftPreferences.defaults;
    // A setter ran while we awaited the DB — keep the user's values.
    if (_mutation != readGeneration) return state;
    if (loaded != null) state = loaded;
    return state;
  }

  Future<void> _persist() {
    final auth = ref.read(authCtrlProvider).valueOrNull;
    if (auth is! AuthSignedIn) return Future<void>.value();

    final userId = auth.profile.id;
    final task = _persistQueue.then((_) async {
      if (!ref.mounted) return;

      final cur = ref.read(authCtrlProvider).valueOrNull;
      if (cur is! AuthSignedIn || cur.profile.id != userId) return;

      await ref
          .read(appDatabaseProvider)
          .settingsDao
          .setValue(
            SettingsKeys.craftPreferencesV1,
            jsonEncode(state.toJson()),
          );
    });

    // Keep the chain alive even if a write fails.
    _persistQueue = task.then((_) {}, onError: (_) {});
    return task;
  }

  Future<void> setScreenMode(CraftScreenMode mode) async {
    _mutation++;
    state = state.copyWith(screenMode: mode);
    await _persist();
  }

  Future<void> setStyleFor(CraftScreenMode mode, TranslationStyle style) async {
    _mutation++;
    state = mode == CraftScreenMode.express
        ? state.copyWith(expressStyle: style)
        : state.copyWith(advancedStyle: style);
    await _persist();
  }

  Future<void> setCustomPrompt(String? prompt) async {
    _mutation++;
    state = prompt == null || prompt.isEmpty
        ? state.copyWith(clearCustomPrompt: true)
        : state.copyWith(customPrompt: prompt);
    await _persist();
  }

  /// Remembers the voice the user picked for [baseLang] (e.g. `'en'`).
  /// A null [voiceId] removes the remembered voice for that language.
  Future<void> setVoice(String baseLang, String? voiceId) async {
    _mutation++;
    final base = baseLang.toLowerCase();
    final voices = Map<String, String>.of(state.voices);
    if (voiceId == null) {
      voices.remove(base);
    } else {
      voices[base] = voiceId;
    }
    state = state.copyWith(voices: voices);
    await _persist();
  }
}
