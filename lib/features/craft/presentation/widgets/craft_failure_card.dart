/// Shared failure card used by every Craft stage (audio, capture, rewrite).
///
/// Centralises the icon + localized message + action button layout so the
/// three stages render identical failure UX and route the same way:
///
/// * [CraftFailureAction.openAiSettings] → push `/settings/ai-providers`
/// * [CraftFailureAction.signIn]         → push `/sign-in`
/// * anything else (including the
///   [CraftFailureAction.switchToSpeakDirectly] case inherited from the
///   duplicated originals) falls back to the supplied [onRetry] callback.
///
/// Previously the same widget lived three times — one private copy each in
/// `audio_stage.dart`, `capture_stage.dart`, and `rewrite_stage.dart` —
/// see [issue #506](https://github.com/baizhiheizi/enjoy_player/issues/506).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/features/craft/domain/craft_failure.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class CraftFailureCard extends StatelessWidget {
  const CraftFailureCard({
    required this.failure,
    required this.l10n,
    required this.onRetry,
    super.key,
  });

  final CraftFailure failure;
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  String _actionLabel() {
    switch (failure.action) {
      case CraftFailureAction.openAiSettings:
        return l10n.craftOpenAiSettings;
      case CraftFailureAction.signIn:
        return l10n.craftSignInRequired;
      default:
        return l10n.craftRetry;
    }
  }

  void _handleAction(BuildContext context) {
    switch (failure.action) {
      case CraftFailureAction.openAiSettings:
        unawaited(context.push('/settings/ai-providers'));
      case CraftFailureAction.signIn:
        unawaited(context.push('/sign-in'));
      default:
        onRetry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              failure.message(l10n),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _handleAction(context),
              child: Text(_actionLabel()),
            ),
          ],
        ),
      ),
    );
  }
}
