/// Surfaces [CreditsFailure] with navigation to subscription management.
///
/// The single presentation seam for credits-exhausted rejections across all
/// AI surfaces (spec 045): a shared localized message builder (with credit
/// numbers when the worker envelope was parsed), the unified CTA label, and
/// the snackbar helper. Inline idioms reuse [creditsFailureMessage] and
/// [creditsCtaLabel] with the same `/subscription` destination.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Builds the user-facing message for [failure].
///
/// When the worker envelope was parsed (`required` + `used`/`limit`), the
/// message spells out the numbers ("This action needs 750 credits, but only
/// 200 are left today."), optionally with the reset time. Otherwise it falls
/// back to the generic `subscriptionCreditsLimitMessageWithPackages` copy.
/// Never returns [CreditsFailure.message] — that is the raw internal string
/// (e.g. `HTTP 402`).
String creditsFailureMessage(CreditsFailure failure, AppLocalizations l10n) {
  final required = failure.requiredCredits;
  final remaining = failure.remainingCredits;

  if (required != null && remaining != null && remaining >= 0) {
    final body = l10n.creditsExhaustedDetailed(required, remaining);
    final resetAt = failure.resetAt;
    if (resetAt != null) {
      final time = DateFormat.jm().add_MEd().format(resetAt.toLocal());
      return '$body ${l10n.creditsExhaustedResets(time)}';
    }
    return body;
  }

  return l10n.subscriptionCreditsLimitMessageWithPackages;
}

/// Unified CTA label for every credits-error surface (spec 045 FR-003).
String creditsCtaLabel(AppLocalizations l10n) =>
    l10n.subscriptionViewPlansAndPackages;

/// Shows the credits error as an [AppNotice.error] snackbar with the
/// one-tap CTA to the subscription screen (plans + credits packages).
void showCreditsFailureNotice(BuildContext context, CreditsFailure failure) {
  final l10n = AppLocalizations.of(context)!;
  AppNotice.error(
    context,
    creditsFailureMessage(failure, l10n),
    action: SnackBarAction(
      label: creditsCtaLabel(l10n),
      onPressed: () => context.push('/subscription'),
    ),
  );
}
