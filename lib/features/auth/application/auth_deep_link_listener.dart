/// Listens for OAuth PKCE deep-link callbacks and forwards them to [AuthCtrl].
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';

final Logger _log = logNamed('auth.deeplink');

class AuthDeepLinkListener extends ConsumerStatefulWidget {
  const AuthDeepLinkListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AuthDeepLinkListener> createState() =>
      _AuthDeepLinkListenerState();
}

class _AuthDeepLinkListenerState extends ConsumerState<AuthDeepLinkListener> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _streamSub;

  @override
  void initState() {
    super.initState();
    unawaited(
      _appLinks.getInitialLink().then(_onUri, onError: _onInitialLinkError),
    );
    _streamSub = _appLinks.uriLinkStream.listen(_onUri);
  }

  @override
  void dispose() {
    unawaited(_streamSub?.cancel());
    _streamSub = null;
    super.dispose();
  }

  void _onInitialLinkError(Object error, StackTrace stack) {
    _log.warning('app_links.getInitialLink failed', error, stack);
  }

  Future<void> _onUri(Uri? uri) async {
    if (uri == null || !mounted) return;
    // Never log the query string: it carries the OAuth `code`.
    _log.info(
      'auth deep link received (${uri.scheme}://${uri.host}${uri.path})',
    );
    try {
      await ref.read(authCtrlProvider.notifier).handleAuthCallbackUri(uri);
    } on AuthFailure catch (e) {
      _log.warning('auth deep link failed', e);
      if (!mounted) return;
      AppNotice.error(context, e.message);
    } catch (e, st) {
      _log.warning('auth deep link failed', e, st);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
