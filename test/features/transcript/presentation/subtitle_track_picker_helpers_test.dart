// Pure-helper coverage for lib/features/transcript/presentation/subtitle_track_picker_helpers.dart.
//
// The file holds:
//   * a tiny enum + a max-height constant
//   * `sheetHorizontalPadding`, `trackOptionPadding` — token math
//   * `trackPickerRadioTheme` — ThemeData builder
//   * `trackLabel`, `findTrack` — track metadata lookups
//   * `providerLabel`, `providerBadgeColors` — source-switch tables
//
// Most of these are exercised transitively by widget tests. We pin them
// directly so the contracts (e.g. "und" → empty label fallback, default
// source → UPPERCASE label, missing id → null) don't drift under refactor.
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_track.dart';
import 'package:enjoy_player/features/transcript/presentation/subtitle_track_picker_helpers.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TranscriptTrack _t({
  String id = 'a',
  String language = 'en',
  String source = 'official',
  String label = '',
  int? trackIndex,
  String targetType = 'Video',
  String targetId = 'video-1',
}) => TranscriptTrack(
  id: id,
  targetType: targetType,
  targetId: targetId,
  language: language,
  source: source,
  label: label,
  trackIndex: trackIndex,
);

void main() {
  group('constants + helpers', () {
    test('kExpandedTrackListMaxHeight is 280 (matches design spec)', () {
      expect(kExpandedTrackListMaxHeight, 280);
    });

    test('sheetHorizontalPadding = space16 + space4', () {
      final t = EnjoyThemeTokens.build(const ColorScheme.light());
      expect(sheetHorizontalPadding(t), t.space16 + t.space4);
    });

    test('trackOptionPadding returns a thin vertical-only edge inset', () {
      final t = EnjoyThemeTokens.build(const ColorScheme.light());
      final p = trackOptionPadding(t);
      expect(p.start, 0);
      expect(p.top, 2);
      expect(p.end, 0);
      expect(p.bottom, 2);
    });
  });

  group('trackLabel', () {
    test('returns the label when non-empty', () {
      expect(trackLabel(_t(label: 'English (US)')), 'English (US)');
    });

    test('falls back to language when label is empty', () {
      expect(trackLabel(_t(label: '', language: 'es')), 'es');
    });
  });

  group('findTrack', () {
    test('returns null when the id is null', () {
      expect(findTrack([_t(id: 'a')], null), isNull);
    });

    test('returns the matching track', () {
      final t1 = _t(id: 'a');
      final t2 = _t(id: 'b');
      expect(findTrack([t1, t2], 'b'), same(t2));
    });

    test('returns null when the track is not in the list', () {
      expect(findTrack([_t(id: 'a')], 'missing'), isNull);
    });
  });

  group('providerLabel', () {
    test('returns the localized string for each known source', () {
      final AppLocalizations l10n = _FakeL10n();
      expect(providerLabel(l10n, 'official'), 'Official');
      expect(providerLabel(l10n, 'auto'), 'Auto');
      expect(providerLabel(l10n, 'ai'), 'AI');
      expect(providerLabel(l10n, 'user'), 'User');
    });

    test('uppercases unknown source names', () {
      final AppLocalizations l10n = _FakeL10n();
      expect(providerLabel(l10n, 'experimental'), 'EXPERIMENTAL');
      // Empty source uppercases to empty string.
      expect(providerLabel(l10n, ''), '');
    });
  });

  group('providerBadgeColors', () {
    ColorScheme scheme() => ColorScheme.fromSeed(seedColor: Colors.indigo);

    test('official → primaryContainer/onPrimaryContainer', () {
      final cs = scheme();
      expect(providerBadgeColors(cs, 'official').bg, cs.primaryContainer);
      expect(providerBadgeColors(cs, 'official').fg, cs.onPrimaryContainer);
    });

    test('auto → tertiaryContainer/onTertiaryContainer', () {
      final cs = scheme();
      expect(providerBadgeColors(cs, 'auto').bg, cs.tertiaryContainer);
      expect(providerBadgeColors(cs, 'auto').fg, cs.onTertiaryContainer);
    });

    test('ai → secondaryContainer/onSecondaryContainer', () {
      final cs = scheme();
      expect(providerBadgeColors(cs, 'ai').bg, cs.secondaryContainer);
      expect(providerBadgeColors(cs, 'ai').fg, cs.onSecondaryContainer);
    });

    test('user → surfaceContainerHighest/onSurfaceVariant', () {
      final cs = scheme();
      expect(providerBadgeColors(cs, 'user').bg, cs.surfaceContainerHighest);
      expect(providerBadgeColors(cs, 'user').fg, cs.onSurfaceVariant);
    });

    test('unknown source → surfaceContainerHigh/onSurfaceVariant', () {
      final cs = scheme();
      expect(providerBadgeColors(cs, 'whatever').bg, cs.surfaceContainerHigh);
      expect(providerBadgeColors(cs, 'whatever').fg, cs.onSurfaceVariant);
    });
  });

  group('trackPickerRadioTheme', () {
    testWidgets('returns a ThemeData with customised splash/highlight/hover', (
      tester,
    ) async {
      // Build a minimal Theme to source the ColorScheme from.
      late ThemeData built;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, _) {
            built = trackPickerRadioTheme(context);
            return const SizedBox.shrink();
          },
          home: const SizedBox.shrink(),
        ),
      );
      expect(built.colorScheme, isNotNull);
      expect(built.splashColor, isNotNull);
      expect(built.highlightColor, Colors.transparent);
      expect(built.hoverColor, isNotNull);
      expect(built.radioTheme, isNotNull);
      expect(built.listTileTheme, isNotNull);
    });
  });
}

// Stand-in for [AppLocalizations] that only carries the strings read by
// `providerLabel`. All other members throw so unintended access is loud.
class _FakeL10n implements AppLocalizations {
  @override
  String get subtitlesProviderOfficial => 'Official';
  @override
  String get subtitlesProviderAuto => 'Auto';
  @override
  String get subtitlesProviderAi => 'AI';
  @override
  String get subtitlesProviderUser => 'User';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Stub missing for ${invocation.memberName}.');
  }
}
