/// HTTP / transport failures from [ApiClient].
library;

final class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.body,
    this.byokProvider = false,
  });

  final String message;
  final int? statusCode;
  final Object? body;

  /// The error status came from the user's own AI provider (BYOK) rather
  /// than the Enjoy worker. Classification uses this to keep provider
  /// billing rejections (a provider 402) out of the Enjoy credits path
  /// (spec 045 FR-008).
  final bool byokProvider;

  bool get isUnauthorized => statusCode == 401;

  /// Postgres / Rails unique constraint when uploading an entity id that
  /// already exists on the server (common for deterministic YouTube UUIDs).
  bool get isDuplicateEntity =>
      statusCode != null &&
      statusCode! >= 400 &&
      statusCode! < 500 &&
      _haystack.contains('already exists');

  String get _haystack {
    final buf = StringBuffer(message);
    final value = body;
    if (value != null) buf.write(' $value');
    return buf.toString().toLowerCase();
  }

  @override
  String toString() =>
      'ApiException($statusCode): $message${body != null ? ' body=$body' : ''}';
}
