/// Single subtitle cue line: text + start + duration in milliseconds.
///
/// Nested shape matches enjoy web (`apps/web/src/types/db/transcript.ts`):
/// `timeline?: TranscriptWord[]` with optional `phones?: PhoneTiming[]`.
/// Line-only cues omit [timeline]. Nested data does not change line identity
/// (`cueIdFor`, auto-translate `sourceKey`).
library;

import 'package:enjoy_player/core/json/json_cast.dart';
import 'package:meta/meta.dart';

/// Per-phone timing aligned with `@enjoy/alignment` `PhoneTiming`.
///
/// Times are **seconds** on the media timeline (web persistence). Word
/// `start` / `duration` remain milliseconds relative to the parent line.
@immutable
class TranscriptPhone {
  const TranscriptPhone({
    required this.phone,
    required this.text,
    this.startTime,
    this.endTime,
    this.wordIndex,
  });

  /// IPA / phone label (`PhoneTiming.phone`).
  final String phone;

  /// Display text; often the same as [phone].
  final String text;

  /// Start time in seconds on the media timeline. Null when untimed (IPA-only).
  final double? startTime;

  /// End time in seconds. Null when untimed.
  final double? endTime;

  /// Index of the parent word in the line's [TranscriptLine.timeline].
  final int? wordIndex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptPhone &&
        other.phone == phone &&
        other.text == text &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.wordIndex == wordIndex;
  }

  @override
  int get hashCode => Object.hash(phone, text, startTime, endTime, wordIndex);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'phone': phone, 'text': text};
    final start = startTime;
    if (start != null) map['startTime'] = start;
    final end = endTime;
    if (end != null) map['endTime'] = end;
    final index = wordIndex;
    if (index != null) map['wordIndex'] = index;
    return map;
  }

  /// Returns null when [phone] is missing or empty.
  static TranscriptPhone? fromJson(Map<String, dynamic> json) {
    final phone = _nonEmptyString(json['phone']);
    if (phone == null) return null;
    return TranscriptPhone(
      phone: phone,
      text: _nonEmptyString(json['text']) ?? phone,
      startTime: numOrNull(json['startTime'])?.toDouble(),
      endTime: numOrNull(json['endTime'])?.toDouble(),
      wordIndex: intFromJson(json['wordIndex']),
    );
  }
}

/// Per-word span matching enjoy web `TranscriptWord`.
///
/// [startMs] / [durationMs] are milliseconds **relative to the parent line**
/// (JSON keys `start` / `duration`).
@immutable
class TranscriptWord {
  const TranscriptWord({
    required this.text,
    this.startMs,
    this.durationMs,
    this.phones,
  });

  final String text;

  /// Milliseconds relative to the parent line. Null when untimed.
  final int? startMs;

  /// Duration in milliseconds. Null or `≤ 0` ⇒ not a karaoke / tap-IPA target.
  final int? durationMs;
  final List<TranscriptPhone>? phones;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptWord &&
        other.text == text &&
        other.startMs == startMs &&
        other.durationMs == durationMs &&
        _sameList(other.phones, phones);
  }

  @override
  int get hashCode => Object.hash(
    text,
    startMs,
    durationMs,
    Object.hashAll(phones ?? const []),
  );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'text': text};
    final start = startMs;
    if (start != null) map['start'] = start;
    final duration = durationMs;
    if (duration != null) map['duration'] = duration;
    final nested = phones;
    if (nested != null && nested.isNotEmpty) {
      map['phones'] = nested.map((p) => p.toJson()).toList();
    }
    return map;
  }

  /// Returns null when [text] is missing or empty.
  static TranscriptWord? fromJson(Map<String, dynamic> json) {
    final rawText = json['text'];
    if (rawText is! String || rawText.isEmpty) return null;
    return TranscriptWord(
      text: rawText,
      startMs: intFromJson(json['start']),
      durationMs: intFromJson(json['duration']),
      phones: _phonesFromJson(json['phones']),
    );
  }
}

@immutable
class TranscriptLine {
  const TranscriptLine({
    required this.text,
    required this.startMs,
    required this.durationMs,
    this.sourceKey,
    this.confidence,
    this.timeline,
  });

  final String text;
  final int startMs;
  final int durationMs;

  /// Content fingerprint for AI auto-translate overlays (optional).
  ///
  /// When set, bilingual UI may validate that this cue still matches the
  /// primary line text + language pair before showing [text].
  final String? sourceKey;

  /// Optional ASR / alignment confidence (0–1). Enjoy web field.
  final double? confidence;

  /// Optional word spans (enjoy web `TranscriptLine.timeline`).
  ///
  /// Null when absent or empty (line-only cue).
  final List<TranscriptWord>? timeline;

  double get startSeconds => startMs / 1000.0;

  double get endSeconds => (startMs + durationMs) / 1000.0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptLine &&
        other.text == text &&
        other.startMs == startMs &&
        other.durationMs == durationMs &&
        other.sourceKey == sourceKey &&
        other.confidence == confidence &&
        _sameList(other.timeline, timeline);
  }

  @override
  int get hashCode => Object.hash(
    text,
    startMs,
    durationMs,
    sourceKey,
    confidence,
    Object.hashAll(timeline ?? const []),
  );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'text': text,
      'start': startMs,
      'duration': durationMs,
    };
    final key = sourceKey;
    if (key != null && key.isNotEmpty) {
      map['sourceKey'] = key;
    }
    final conf = confidence;
    if (conf != null) {
      map['confidence'] = conf;
    }
    final nested = timeline;
    if (nested != null && nested.isNotEmpty) {
      map['timeline'] = nested.map((w) => w.toJson()).toList();
    }
    return map;
  }

  static TranscriptLine fromJson(Map<String, dynamic> json) {
    final rawKey = json['sourceKey'] as String?;
    return TranscriptLine(
      text: json['text'] as String? ?? '',
      startMs: (json['start'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration'] as num?)?.toInt() ?? 0,
      sourceKey: (rawKey != null && rawKey.isNotEmpty) ? rawKey : null,
      confidence: numOrNull(json['confidence'])?.toDouble(),
      timeline: _wordsFromJson(json['timeline']),
    );
  }
}

String? _nonEmptyString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

List<TranscriptWord>? _wordsFromJson(Object? raw) {
  if (raw is! List) return null;
  final out = <TranscriptWord>[];
  for (final e in raw) {
    final m = castJsonObjectOrNull(e);
    if (m == null) continue;
    final word = TranscriptWord.fromJson(m);
    if (word == null) continue;
    out.add(word);
  }
  return out.isEmpty ? null : out;
}

List<TranscriptPhone>? _phonesFromJson(Object? raw) {
  if (raw is! List) return null;
  final out = <TranscriptPhone>[];
  for (final e in raw) {
    final m = castJsonObjectOrNull(e);
    if (m == null) continue;
    final phone = TranscriptPhone.fromJson(m);
    if (phone == null) continue;
    out.add(phone);
  }
  return out.isEmpty ? null : out;
}

bool _sameList<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  final aEmpty = a == null || a.isEmpty;
  final bEmpty = b == null || b.isEmpty;
  if (aEmpty || bEmpty) return aEmpty && bEmpty;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
