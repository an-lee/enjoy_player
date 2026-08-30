import 'dart:convert';

import 'package:enjoy_player/core/validation/byok_http.dart';
import 'package:enjoy_player/data/api/api_exception.dart';

/// Shared guard for BYOK HTTP base URLs. Validates [baseUrl] via
/// [isByokBaseUrlAllowed], normalizes trailing slashes, and joins
/// [path] (if non-empty) to produce the final [Uri]. Throws
/// [ApiException] (400) with a [purpose]-specific message on rejection.
Uri guardByokBaseUrl({
  required String baseUrl,
  required String path,
  required String purpose,
}) {
  if (!isByokBaseUrlAllowed(baseUrl)) {
    throw ApiException(
      message: 'Invalid base URL for $purpose',
      statusCode: 400,
    );
  }
  final root = normalizeByokBaseUrl(baseUrl);
  final uri = path.isEmpty
      ? Uri.parse(root)
      : Uri.parse('$root/${path.startsWith('/') ? path.substring(1) : path}');
  return uri;
}

/// Standard `Authorization: Bearer <apiKey>` header for OpenAI-compatible
/// BYOK endpoints.
Map<String, String> byokBearerHeaders({
  required String apiKey,
  String accept = 'application/json',
}) => {'Authorization': 'Bearer ${apiKey.trim()}', 'Accept': accept};

/// Decode the body of a non-2xx BYOK response. JSON-decoded payloads are
/// returned as-is; non-JSON payloads fall back to the raw string so callers
/// can surface the server's plain-text error to users without losing it.
Object? decodeByokErrorBody(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    return body;
  }
}

/// Throw [ApiException] for a non-2xx BYOK response. Always `Never` so it
/// can be used as the terminating arm of an `if`/`else` without a synthetic
/// return.
Never throwByokHttpError({
  required String purpose,
  required int statusCode,
  required String body,
}) {
  throw ApiException(
    message: '$purpose failed ($statusCode)',
    statusCode: statusCode,
    body: decodeByokErrorBody(body),
    byokProvider: true,
  );
}
