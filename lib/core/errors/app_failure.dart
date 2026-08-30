/// Typed failures for UI and repositories.
library;

import 'package:enjoy_player/data/api/api_exception.dart';

sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

final class FileFailure extends AppFailure {
  const FileFailure(super.message);
}

/// Picked file is not an allowed local audio/video type (e.g. image or document).
final class UnsupportedImportFileFailure extends AppFailure {
  const UnsupportedImportFileFailure() : super('');
}

final class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message);
}

final class PlaybackFailure extends AppFailure {
  const PlaybackFailure(super.message);
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {this.statusCode});

  final int? statusCode;
}

/// Categorizes auth failures so the UI can render distinct messages
/// (e.g. "invalid credentials" vs "rate limited" vs "network down") and
/// the auth repository can decide whether to keep the existing session.
enum AuthFailureCode {
  /// User supplied bad credentials (bad OTP, bad email, expired PKCE).
  invalidCredentials,

  /// The server explicitly rejected the session (HTTP 401 or 403). The
  /// refresh-token grant is no longer valid; the local session should
  /// be cleared.
  sessionRevoked,

  /// The server asked the caller to slow down (HTTP 429).
  rateLimited,

  /// The request never reached the server, or the server did not respond
  /// in time. The local session is presumed still valid and must be kept
  /// so the next call can retry.
  networkUnreachable,

  /// The server returned a 5xx that the client cannot classify further.
  /// The local session is presumed still valid; retry later.
  serverError,

  /// Catch-all for unclassified auth errors.
  unknown,
}

final class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {this.code = AuthFailureCode.unknown});

  final AuthFailureCode code;

  bool get isSessionRevoked => code == AuthFailureCode.sessionRevoked;
}

/// Worker returned HTTP 402 (AI credits exhausted or billing block).
///
/// Carries the worker's structured rejection envelope (see
/// `specs/045-ai-credits-error-ux/contracts/worker-402-envelope.md`) so the
/// presentation layer can show *how much* is missing instead of a bare
/// message. All envelope fields are null when the body was empty, garbled,
/// or absent (e.g. non-worker 402s) — callers must fall back to the generic
/// copy in that case.
final class CreditsFailure extends AppFailure {
  const CreditsFailure(
    super.message, {
    this.requiredCredits,
    this.usedCredits,
    this.limitCredits,
    this.resetAt,
  });

  /// Best-effort parse of the camelCased worker 402 envelope from [e]'s body.
  ///
  /// Never throws: a non-map body, missing keys, or malformed values simply
  /// leave the envelope fields null (generic-message fallback). Negative or
  /// non-numeric numbers are treated as absent.
  factory CreditsFailure.fromApiException(ApiException e) {
    final body = e.body;
    if (body is! Map<String, dynamic>) return CreditsFailure(e.message);

    int? positiveInt(Object? value) {
      if (value is int && value >= 0) return value;
      return null;
    }

    final limit = body['limit'];
    final resetAtRaw = limit is Map<String, dynamic> ? limit['resetAt'] : null;
    DateTime? resetAt;
    if (resetAtRaw is String) {
      resetAt = DateTime.tryParse(resetAtRaw)?.toUtc();
    }

    return CreditsFailure(
      e.message,
      requiredCredits: positiveInt(body['required']),
      usedCredits: limit is Map<String, dynamic>
          ? positiveInt(limit['used'])
          : null,
      limitCredits: limit is Map<String, dynamic>
          ? positiveInt(limit['limit'])
          : null,
      resetAt: resetAt,
    );
  }

  /// Credits the rejected request needed (`required` in the envelope).
  final int? requiredCredits;

  /// Credits already consumed in the current window (`limit.used`).
  final int? usedCredits;

  /// Window allowance (`limit.limit`, the tier's daily pool).
  final int? limitCredits;

  /// When the window resets (`limit.resetAt`, UTC).
  final DateTime? resetAt;

  /// Credits still available in the window, when both inputs are known.
  int? get remainingCredits {
    final limit = limitCredits;
    final used = usedCredits;
    if (limit == null || used == null) return null;
    return limit - used;
  }
}

/// A 402 from the user's own AI provider (BYOK), not from the Enjoy worker.
///
/// The rejection is about the provider's billing — showing the Enjoy
/// subscription upsell here would be wrong (spec 045 FR-008). Surfaces
/// without a dedicated branch render it through their generic failure path.
final class ProviderBillingFailure extends AppFailure {
  const ProviderBillingFailure(super.message);
}

/// Rails returned HTTP 409 (e.g. second auto-renew while one is active).
final class SubscriptionConflictFailure extends AppFailure {
  const SubscriptionConflictFailure(super.message);
}
