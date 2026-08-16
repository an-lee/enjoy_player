/// Isolated-test overrides so transcript tiles never open SettingsDao.
library;

import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:enjoy_player/features/settings/application/ipa_overlay_settings.dart';
import 'package:enjoy_player/features/settings/application/word_practice_settings.dart';

class IpaOverlaySettingsOverride extends IpaOverlaySettings {
  IpaOverlaySettingsOverride(this.enabled);

  final bool enabled;

  @override
  Future<bool> build() async => enabled;
}

class WordPracticeSettingsOverride extends WordPracticeSettings {
  WordPracticeSettingsOverride(this.enabled);

  final bool enabled;

  @override
  Future<bool> build() async => enabled;
}

/// Default-off gates for existing tile tests (US1 / karaoke / blur).
List<Override> transcriptWordPracticeOffOverrides() => [
  ipaOverlaySettingsProvider.overrideWith(
    () => IpaOverlaySettingsOverride(false),
  ),
  wordPracticeSettingsProvider.overrideWith(
    () => WordPracticeSettingsOverride(false),
  ),
];

List<Override> transcriptIpaOverlayOnOverrides({bool practice = false}) => [
  ipaOverlaySettingsProvider.overrideWith(
    () => IpaOverlaySettingsOverride(true),
  ),
  wordPracticeSettingsProvider.overrideWith(
    () => WordPracticeSettingsOverride(practice),
  ),
];

List<Override> transcriptWordPracticeOnOverrides({bool overlay = false}) => [
  ipaOverlaySettingsProvider.overrideWith(
    () => IpaOverlaySettingsOverride(overlay),
  ),
  wordPracticeSettingsProvider.overrideWith(
    () => WordPracticeSettingsOverride(true),
  ),
];
