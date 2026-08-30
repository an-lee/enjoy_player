library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/lookup_markdown_style.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/auth_required_callout.dart';
import 'package:enjoy_player/features/ai/application/ai_cache_fingerprint.dart';
import 'package:enjoy_player/features/ai/application/ai_result_cache.dart';
import 'package:enjoy_player/features/ai/application/ai_services.dart';
import 'package:enjoy_player/features/ai/domain/ai_kind.dart';
import 'package:enjoy_player/features/ai/domain/models/contextual_translation_result.dart';
import 'package:enjoy_player/features/lookup/application/lookup_section_params.dart';
import 'package:enjoy_player/features/subscription/presentation/credits_failure_actions.dart';
import 'package:enjoy_player/features/lookup/domain/lookup_request.dart';
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_error_row.dart';
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_expansion_card.dart';
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_refresh_icon_button.dart';
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_section_auth_gate.dart';
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_section_shimmer.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

final Logger _log = logNamed('lookup.contextual');

class ContextualTranslationLookupSection extends ConsumerWidget {
  const ContextualTranslationLookupSection({required this.request, super.key});

  final LookupRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final params = LookupContextualParams(
      text: request.selectedText,
      sourceLanguage: request.sourceLanguage,
      targetLanguage: request.targetLanguage,
      context: request.contextualContext,
    );
    final theme = Theme.of(context);
    final t = EnjoyThemeTokens.of(context);
    final mdStyle = buildLookupMarkdownStyleSheet(theme, t);

    return LookupExpansionCard(
      title: l10n.lookupSectionContextualTranslation,
      initiallyExpanded: false,
      leading: const Icon(Icons.article_outlined),
      bodyBuilder: (ctx) => LookupSectionAuthGate(
        surface: AuthRequiredSurface.lookupContextual,
        child: _ContextualFetchBody(
          params: params,
          theme: theme,
          mdStyle: mdStyle,
          l10n: l10n,
        ),
      ),
    );
  }
}

/// Loads contextual translation outside an autoDispose [FutureProvider].
///
/// Riverpod can dispose/cancel an autoDispose future while the HTTP/LLM call is
/// still running; when the response arrives, state is never applied and the UI
/// stays on the loading shimmer. This widget keeps a single [Future] tied to
/// [ConsumerState] instead. Completed values are stored in
/// [AiContextualTranslationCache].
class _ContextualFetchBody extends ConsumerStatefulWidget {
  const _ContextualFetchBody({
    required this.params,
    required this.theme,
    required this.mdStyle,
    required this.l10n,
  });

  final LookupContextualParams params;
  final ThemeData theme;
  final MarkdownStyleSheet mdStyle;
  final AppLocalizations l10n;

  @override
  ConsumerState<_ContextualFetchBody> createState() =>
      _ContextualFetchBodyState();
}

class _ContextualFetchBodyState extends ConsumerState<_ContextualFetchBody> {
  static const Duration _timeout = Duration(seconds: 120);

  Future<ContextualTranslationResult>? _future;

  /// Last successful result; kept visible while a refresh is in flight.
  ContextualTranslationResult? _staleSuccess;

  /// Last error message; shown with a busy retry control until the retry completes.
  String? _lastErrorUserMessage;

  bool _retryInFlight = false;

  @override
  void initState() {
    super.initState();
    _beginFetch(forceRefresh: false, notifyPostFrameOnly: true);
  }

  @override
  void dispose() {
    _silenceDetachedFuture(_future);
    super.dispose();
  }

  void _silenceDetachedFuture(Future<ContextualTranslationResult>? previous) {
    if (previous == null) return;
    unawaited(
      previous.then<void>(
        (_) {},
        onError: (Object e, StackTrace st) {
          assert(() {
            _log.finest('superseded contextual future finished', e, st);
            return true;
          }());
        },
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _ContextualFetchBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.params != widget.params) {
      _staleSuccess = null;
      _lastErrorUserMessage = null;
      _retryInFlight = false;
      _beginFetch(forceRefresh: false, notifyPostFrameOnly: false);
    }
  }

  void _beginFetch({
    required bool forceRefresh,
    bool notifyPostFrameOnly = false,
  }) {
    _silenceDetachedFuture(_future);

    final p = widget.params;
    final cache = ref.read(aiContextualTranslationCacheProvider);
    final key = AiCacheFingerprint.fingerprint(
      kind: AiKind.contextualTranslation.wire,
      payload: {
        'text': p.text,
        'sourceLanguage': p.sourceLanguage,
        'targetLanguage': p.targetLanguage,
        'context': p.context ?? '',
      },
    );

    _log.info(
      'contextual translation request '
      'src=${p.sourceLanguage} tgt=${p.targetLanguage} '
      'textLen=${p.text.length} ctxLen=${p.context?.length ?? 0} '
      'forceRefresh=$forceRefresh',
    );

    _future = () async {
      try {
        final r = await cache.lookup(
          kind: AiKind.contextualTranslation,
          key: key,
          loader: () async {
            final svc = ref.read(contextualTranslationServiceProvider);
            return svc
                .translate(
                  text: p.text,
                  sourceLanguage: p.sourceLanguage,
                  targetLanguage: p.targetLanguage,
                  context: p.context,
                )
                .timeout(
                  _timeout,
                  onTimeout: () {
                    throw TimeoutException(
                      'Contextual translation timed out after '
                      '${_timeout.inSeconds}s',
                    );
                  },
                );
          },
          forceRefresh: forceRefresh,
        );
        _log.info(
          'contextual translation ok outChars=${r.translatedText.length}',
        );
        return r;
      } catch (e, st) {
        _log.warning('contextual translation request failed', e, st);
        rethrow;
      }
    }();
    if (notifyPostFrameOnly) {
      _deferSetState();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _deferSetState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _retryAfterError() {
    setState(() => _retryInFlight = true);
    _beginFetch(forceRefresh: true, notifyPostFrameOnly: false);
  }

  Widget _resultStack({
    required bool isRefreshing,
    required VoidCallback onRefresh,
    required Widget body,
  }) {
    final t = EnjoyThemeTokens.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(end: t.space40),
          child: body,
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: LookupRefreshIconButton(
            l10n: widget.l10n,
            isRefreshing: isRefreshing,
            onPressed: onRefresh,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) {
      return const LookupSectionShimmer();
    }
    return FutureBuilder<ContextualTranslationResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          if (_staleSuccess != null) {
            final d = _staleSuccess!;
            return _resultStack(
              isRefreshing: true,
              onRefresh: () => _beginFetch(forceRefresh: true),
              body: d.translatedText.trim().isEmpty
                  ? Text(
                      widget.l10n.lookupEmpty,
                      style: widget.theme.textTheme.bodyMedium,
                    )
                  : MarkdownBody(
                      data: d.translatedText,
                      selectable: true,
                      styleSheet: widget.mdStyle,
                    ),
            );
          }
          if (_retryInFlight &&
              (_lastErrorUserMessage ?? '').trim().isNotEmpty) {
            return LookupErrorRow(
              message: _lastErrorUserMessage!,
              onRetry: _retryAfterError,
              isRetrying: true,
            );
          }
          return const LookupSectionShimmer();
        }
        if (snapshot.hasError) {
          final e = snapshot.error!;
          _staleSuccess = null;
          _retryInFlight = false;
          if (e is AuthFailure) {
            return const AuthRequiredCallout(
              surface: AuthRequiredSurface.lookupContextual,
              compact: true,
            );
          }
          if (e is CreditsFailure) {
            // Same pattern as the sibling lookup sections (spec 045): friendly
            // message + one-tap recovery to plans & packages.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LookupErrorRow(
                  message: creditsFailureMessage(e, widget.l10n),
                  onRetry: _retryAfterError,
                ),
                TextButton(
                  onPressed: () => context.push('/subscription'),
                  child: Text(creditsCtaLabel(widget.l10n)),
                ),
              ],
            );
          }
          final msg = lookupErrorUserMessage(e, widget.l10n);
          _lastErrorUserMessage = msg;
          return LookupErrorRow(message: msg, onRetry: _retryAfterError);
        }
        final d = snapshot.data!;
        _staleSuccess = d;
        _retryInFlight = false;
        return _resultStack(
          isRefreshing: false,
          onRefresh: () =>
              _beginFetch(forceRefresh: true, notifyPostFrameOnly: false),
          body: d.translatedText.trim().isEmpty
              ? Text(
                  widget.l10n.lookupEmpty,
                  style: widget.theme.textTheme.bodyMedium,
                )
              : MarkdownBody(
                  data: d.translatedText,
                  selectable: true,
                  styleSheet: widget.mdStyle,
                ),
        );
      },
    );
  }
}
