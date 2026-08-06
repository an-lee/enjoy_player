/// Tip completion status and progress snapshot.
library;

import 'dart:convert';

import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';

enum TipStatus {
  pending,
  completed,
  skipped;

  static TipStatus parse(String? raw) {
    return switch (raw) {
      'completed' => TipStatus.completed,
      'skipped' => TipStatus.skipped,
      _ => TipStatus.pending,
    };
  }

  String get storageValue => switch (this) {
    TipStatus.pending => 'pending',
    TipStatus.completed => 'completed',
    TipStatus.skipped => 'skipped',
  };

  bool get isResolved =>
      this == TipStatus.completed || this == TipStatus.skipped;
}

/// In-memory tip progress for the signed-in user.
class TipProgressSnapshot {
  const TipProgressSnapshot({
    this.global = const {},
    this.emptyTranscriptByMediaId = const {},
  });

  final Map<String, TipStatus> global;
  final Map<String, TipStatus> emptyTranscriptByMediaId;

  TipStatus statusOfGlobal(OnboardingTipId tip) =>
      global[tip.id] ?? TipStatus.pending;

  TipStatus statusOfEmptyTranscript(String mediaId) =>
      emptyTranscriptByMediaId[mediaId] ?? TipStatus.pending;

  TipProgressSnapshot copyWith({
    Map<String, TipStatus>? global,
    Map<String, TipStatus>? emptyTranscriptByMediaId,
  }) {
    return TipProgressSnapshot(
      global: global ?? this.global,
      emptyTranscriptByMediaId:
          emptyTranscriptByMediaId ?? this.emptyTranscriptByMediaId,
    );
  }

  static Map<String, TipStatus> decodeGlobalJson(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final out = <String, TipStatus>{};
      for (final entry in decoded.entries) {
        final key = entry.key?.toString();
        if (key == null || key.isEmpty) continue;
        // Ignore unknown tip ids for forward compatibility.
        if (OnboardingTipId.tryParse(key) == null) continue;
        out[key] = TipStatus.parse(entry.value?.toString());
      }
      return out;
    } on Object {
      return const {};
    }
  }

  static String encodeGlobalJson(Map<String, TipStatus> global) {
    final map = <String, String>{};
    for (final e in global.entries) {
      if (e.value == TipStatus.pending) continue;
      map[e.key] = e.value.storageValue;
    }
    return jsonEncode(map);
  }
}
