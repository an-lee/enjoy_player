/// Informational dialog when mobile in-app purchase is not yet available.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/platform/subscription_purchase_capability.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Shows the mobile-unavailable dialog and returns `true` when the caller
/// must stop (mobile platform, or external checkout unsupported); `false`
/// when the caller may proceed. Re-check `context.mounted` after awaiting.
Future<bool> guardMobilePurchase(BuildContext context) async {
  if (showsMobilePurchaseUnavailable()) {
    await showMobilePurchaseUnavailableDialog(context);
    return true;
  }
  return !supportsExternalSubscriptionPurchase();
}

Future<void> showMobilePurchaseUnavailableDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showEnjoyAlertDialog<void>(
    context: context,
    title: Text(l10n.subscriptionMobilePurchaseTitle),
    content: Text(l10n.subscriptionMobilePurchaseMessage),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).okButtonLabel),
      ),
    ],
  );
}
