/// Typed HTTP client: bearer auth, JSON, camelCase ↔ snake_case.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:enjoy_player/core/json/json_cast.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/api/case_conversion.dart';
import 'package:enjoy_player/data/api/json_isolate.dart';

final Logger _log = logNamed('api');

/// Request/response lines at [Level.INFO] so they appear when
/// [Logger.root.level] is [Level.INFO] (profile/release), not only [Level.ALL].
void _apiHttpTrace(String message) {
  _log.info(message);
}

typedef GetBaseUrl = Future<String> Function();
typedef GetAccessToken = Future<String?> Function();
typedef RefreshAccessToken = Future<bool> Function();

/// Shared alias for decoded JSON objects; import from here instead of
/// redeclaring per service file.
typedef JsonMap = Map<String, dynamic>;

class ApiClient {
  ApiClient({
    required http.Client httpClient,
    required this.getBaseUrl,
    required this.getAccessToken,
    this.sendAuthHeader = true,
    this.refreshAccessToken,
  }) : _client = httpClient;

  final http.Client _client;
  final GetBaseUrl getBaseUrl;
  final GetAccessToken getAccessToken;
  final bool sendAuthHeader;
  final RefreshAccessToken? refreshAccessToken;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) => _sendMap(
    method: 'GET',
    path: path,
    queryParameters: queryParameters,
    body: null,
    requireAuth: requireAuth,
  );

  /// For endpoints that return a JSON array (e.g. Rails `render json: @items`).
  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) => _sendList(
    method: 'GET',
    path: path,
    queryParameters: queryParameters,
    body: null,
    requireAuth: requireAuth,
  );

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) => _sendMap(
    method: 'POST',
    path: path,
    queryParameters: null,
    body: body,
    requireAuth: requireAuth,
  );

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    bool transformBody = true,
  }) => _sendMap(
    method: 'PATCH',
    path: path,
    queryParameters: null,
    body: body,
    requireAuth: requireAuth,
    transformBody: transformBody,
  );

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    bool transformBody = true,
  }) => _sendMap(
    method: 'PUT',
    path: path,
    queryParameters: null,
    body: body,
    requireAuth: requireAuth,
    transformBody: transformBody,
  );

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool requireAuth = true,
  }) => _sendMap(
    method: 'DELETE',
    path: path,
    queryParameters: null,
    body: null,
    requireAuth: requireAuth,
    allowEmptyBody: true,
  );

  /// PUT raw bytes to a relative API path with optional bearer auth.
  ///
  /// Used for Worker media upload (`PUT /audio/media/:ref`). Returns decoded
  /// JSON object with camelCase keys when the body is a JSON object.
  Future<Map<String, dynamic>> putBytesJson(
    String path, {
    required List<int> bytes,
    required String contentType,
    bool requireAuth = true,
  }) async {
    final base = _trimTrailingSlash(await getBaseUrl());
    final uriBase = Uri.parse(base);
    final pathUri = Uri.parse(path);
    final merged = uriBase.resolveUri(pathUri);

    final bearer = await _ensureAuthenticated(requireAuth);

    final request = http.Request('PUT', merged)..bodyBytes = bytes;
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = contentType;
    if (bearer != null) {
      request.headers['Authorization'] = 'Bearer $bearer';
    }

    final sw = Stopwatch()..start();
    _apiHttpTrace('HTTP → PUT $merged (bytes len=${bytes.length})');
    try {
      final streamed = await _client.send(request);
      final bodyBytes = await streamed.stream.toBytes();
      sw.stop();
      final response = http.Response.bytes(
        bodyBytes,
        streamed.statusCode,
        headers: streamed.headers,
        request: request,
      );
      _apiHttpTrace(
        'HTTP ← PUT $merged ${response.statusCode} '
        '${sw.elapsedMilliseconds}ms len=${bodyBytes.length}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = await _decodeResponseBody(response);
        final map = castJsonObjectOrNull(decoded);
        if (map == null) {
          throw ApiException(
            message: 'Expected JSON object',
            statusCode: response.statusCode,
            body: decoded,
          );
        }
        return map;
      }
      await _throwApiError(response);
      throw AssertionError('unreachable');
    } catch (e, st) {
      sw.stop();
      _log.warning(
        'HTTP ✗ PUT $merged after ${sw.elapsedMilliseconds}ms: $e',
        e,
        st,
      );
      rethrow;
    }
  }

  /// PUT raw bytes to an absolute URL (e.g. Active Storage direct-upload target).
  ///
  /// Does not attach the Enjoy bearer token — storage backends use [headers]
  /// from the direct-upload create response.
  Future<void> putBytesAbsolute(
    Uri url, {
    required List<int> bytes,
    Map<String, String> headers = const {},
  }) async {
    final request = http.Request('PUT', url)..bodyBytes = bytes;
    request.headers.addAll(headers);

    final sw = Stopwatch()..start();
    _apiHttpTrace('HTTP → PUT $url (bytes len=${bytes.length})');
    try {
      final streamed = await _client.send(request);
      final bodyBytes = await streamed.stream.toBytes();
      sw.stop();
      _apiHttpTrace(
        'HTTP ← PUT $url ${streamed.statusCode} '
        '${sw.elapsedMilliseconds}ms len=${bodyBytes.length}',
      );
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw ApiException(
          message: 'Direct upload failed (${streamed.statusCode})',
          statusCode: streamed.statusCode,
          body: utf8.decode(bodyBytes, allowMalformed: true),
        );
      }
    } catch (e, st) {
      sw.stop();
      _log.warning(
        'HTTP ✗ PUT $url after ${sw.elapsedMilliseconds}ms: $e',
        e,
        st,
      );
      rethrow;
    }
  }

  /// Multipart POST (e.g. Whisper) returning a JSON object with camelCase keys.
  Future<Map<String, dynamic>> postMultipartJson(
    String path, {
    required String fileFieldName,
    required List<int> fileBytes,
    String? fileFilename,
    Map<String, String> fields = const {},
    bool requireAuth = true,
  }) async {
    final base = _trimTrailingSlash(await getBaseUrl());
    final uriBase = Uri.parse(base);
    final pathUri = Uri.parse(path);
    final merged = uriBase.resolveUri(pathUri);

    final bearer = await _ensureAuthenticated(requireAuth);

    final request = http.MultipartRequest('POST', merged);
    request.headers['Accept'] = 'application/json';
    if (bearer != null) {
      request.headers['Authorization'] = 'Bearer $bearer';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        fileFieldName,
        fileBytes,
        filename: fileFilename,
      ),
    );
    for (final e in fields.entries) {
      request.fields[e.key] = e.value;
    }

    final sw = Stopwatch()..start();
    _apiHttpTrace('HTTP → POST $merged (multipart)');
    try {
      final streamed = await _client.send(request);
      final bodyBytes = await streamed.stream.toBytes();
      sw.stop();
      final response = http.Response.bytes(
        bodyBytes,
        streamed.statusCode,
        headers: streamed.headers,
        request: request,
      );
      _apiHttpTrace(
        'HTTP ← POST $merged ${response.statusCode} '
        '${sw.elapsedMilliseconds}ms len=${bodyBytes.length}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = await _decodeResponseBody(response);
        final map = castJsonObjectOrNull(decoded);
        if (map == null) {
          throw ApiException(
            message: 'Expected JSON object',
            statusCode: response.statusCode,
            body: decoded,
          );
        }
        return map;
      }
      await _throwApiError(response);
      throw AssertionError('unreachable');
    } catch (e, st) {
      sw.stop();
      _log.warning(
        'HTTP ✗ POST $merged (multipart) after ${sw.elapsedMilliseconds}ms: $e',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<Object?> _decodeResponseBody(http.Response response) async {
    final raw = response.body;
    if (raw.isEmpty) return null;
    if (raw.length > 8 * 1024) {
      return compute(decodeJsonToCamel, raw);
    }
    return decodeJsonToCamel(raw);
  }

  /// Returns a bearer token to attach to the outgoing request, or `null`
  /// when auth is disabled / not required for this call.
  ///
  /// When the cached token is missing or empty, attempts a single
  /// [refreshAccessToken] and re-reads the token. If no usable token is
  /// available after that, throws [ApiException] with status 401 — matching
  /// the auth posture callers relied on before the three call sites were
  /// deduplicated.
  Future<String?> _ensureAuthenticated(bool requireAuth) async {
    if (!sendAuthHeader || !requireAuth) return null;

    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) return token;

    if (refreshAccessToken != null) {
      final ok = await refreshAccessToken!();
      if (ok) {
        final newToken = await getAccessToken();
        if (newToken != null && newToken.isNotEmpty) return newToken;
      }
    }

    throw const ApiException(message: 'Not authenticated', statusCode: 401);
  }

  Future<Map<String, dynamic>> _sendMap({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    required bool requireAuth,
    bool allowEmptyBody = false,
    bool transformBody = true,
  }) async {
    return _sendMapWithOptionalRefresh(
      method: method,
      path: path,
      queryParameters: queryParameters,
      body: body,
      requireAuth: requireAuth,
      allowEmptyBody: allowEmptyBody,
      transformBody: transformBody,
      allowRefreshRetry: true,
    );
  }

  Future<Map<String, dynamic>> _sendMapWithOptionalRefresh({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    required bool requireAuth,
    bool allowEmptyBody = false,
    bool transformBody = true,
    required bool allowRefreshRetry,
  }) async {
    final response = await _dispatch(
      method: method,
      path: path,
      queryParameters: queryParameters,
      body: body,
      requireAuth: requireAuth,
      transformBody: transformBody,
    );

    if (response.statusCode == 401 &&
        requireAuth &&
        allowRefreshRetry &&
        refreshAccessToken != null) {
      final refreshed = await refreshAccessToken!();
      if (refreshed) {
        return _sendMapWithOptionalRefresh(
          method: method,
          path: path,
          queryParameters: queryParameters,
          body: body,
          requireAuth: requireAuth,
          allowEmptyBody: allowEmptyBody,
          transformBody: transformBody,
          allowRefreshRetry: false,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty && allowEmptyBody) {
        return const <String, dynamic>{};
      }
      final decoded = await _decodeResponseBody(response);
      final map = castJsonObjectOrNull(decoded);
      if (map == null) {
        throw ApiException(
          message: 'Expected JSON object',
          statusCode: response.statusCode,
          body: decoded,
        );
      }
      return map;
    }

    await _throwApiError(response);
    throw AssertionError('unreachable');
  }

  Future<List<Map<String, dynamic>>> _sendList({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    required bool requireAuth,
  }) async {
    final response = await _dispatch(
      method: method,
      path: path,
      queryParameters: queryParameters,
      body: body,
      requireAuth: requireAuth,
      transformBody: true,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = await _decodeResponseBody(response);
      if (decoded is! List) {
        throw ApiException(
          message: 'Expected JSON array',
          statusCode: response.statusCode,
          body: decoded,
        );
      }
      return decoded.map<Map<String, dynamic>>((e) {
        final map = castJsonObjectOrNull(e);
        if (map == null) {
          throw ApiException(
            message: 'Array element is not an object',
            statusCode: response.statusCode,
            body: e,
          );
        }
        return map;
      }).toList();
    }

    await _throwApiError(response);
    throw AssertionError('unreachable');
  }

  Future<http.Response> _dispatch({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    required bool requireAuth,
    bool transformBody = true,
  }) async {
    final base = _trimTrailingSlash(await getBaseUrl());
    final uriBase = Uri.parse(base);
    final pathUri = Uri.parse(path);
    final merged = uriBase.resolveUri(pathUri);
    final uri = queryParameters == null || queryParameters.isEmpty
        ? merged
        : merged.replace(queryParameters: _snakeCaseQuery(queryParameters));

    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json; charset=UTF-8',
    };

    final bearer = await _ensureAuthenticated(requireAuth);
    if (bearer != null) {
      headers['Authorization'] = 'Bearer $bearer';
    }

    final bodyBytes = body == null
        ? null
        : utf8.encode(
            jsonEncode(transformBody ? convertKeysToSnake(body) : body),
          );

    final sw = Stopwatch()..start();
    _apiHttpTrace('HTTP → $method $uri');

    try {
      final http.Response response;
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers);
        case 'POST':
          response = await _client.post(uri, headers: headers, body: bodyBytes);
        case 'PATCH':
          response = await _client.patch(
            uri,
            headers: headers,
            body: bodyBytes,
          );
        case 'PUT':
          response = await _client.put(uri, headers: headers, body: bodyBytes);
        case 'DELETE':
          response = await _client.delete(uri, headers: headers);
        default:
          throw ApiException(message: 'Unsupported method $method');
      }
      sw.stop();
      _apiHttpTrace(
        'HTTP ← $method $uri ${response.statusCode} '
        '${sw.elapsedMilliseconds}ms len=${response.bodyBytes.length}',
      );
      return response;
    } catch (e, st) {
      sw.stop();
      _log.warning(
        'HTTP ✗ $method $uri after ${sw.elapsedMilliseconds}ms: $e',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> _throwApiError(http.Response response) async {
    Object? errBody;
    try {
      errBody = response.body.isEmpty
          ? null
          : (response.body.length > 8 * 1024
                ? await compute(decodeJsonToCamel, response.body)
                : decodeJsonToCamel(response.body));
    } catch (_) {
      errBody = response.body;
    }

    throw ApiException(
      message: 'HTTP ${response.statusCode}',
      statusCode: response.statusCode,
      body: errBody,
    );
  }

  Map<String, String> _snakeCaseQuery(Map<String, String> query) {
    final out = <String, String>{};
    query.forEach((k, v) {
      out[_camelQueryKeyToSnake(k)] = v;
    });
    return out;
  }

  static String _camelQueryKeyToSnake(String key) {
    final b = StringBuffer();
    for (var i = 0; i < key.length; i++) {
      final c = key[i];
      final code = c.codeUnitAt(0);
      final isUpper = code >= 65 && code <= 90;
      if (isUpper && i > 0) {
        b.write('_');
      }
      b.write(c.toLowerCase());
    }
    return b.toString();
  }

  static String _trimTrailingSlash(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }
}
