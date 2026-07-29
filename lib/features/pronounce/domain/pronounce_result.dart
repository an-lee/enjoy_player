/// Worker `POST /pronounce` success body.
library;

final class PronounceResult {
  const PronounceResult({
    required this.audioUrl,
    required this.cached,
    required this.locale,
    required this.voice,
    required this.format,
    required this.text,
    required this.provider,
  });

  factory PronounceResult.fromJson(Map<String, dynamic> json) {
    final audioUrl = (json['audio_url'] ?? json['audioUrl']) as String? ?? '';
    return PronounceResult(
      audioUrl: audioUrl,
      cached: json['cached'] as bool? ?? false,
      locale: (json['locale'] as String?) ?? '',
      voice: (json['voice'] as String?) ?? '',
      format: (json['format'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
    );
  }

  final String audioUrl;
  final bool cached;
  final String locale;
  final String voice;
  final String format;
  final String text;
  final String provider;
}
