/// Audio-only expanded player: collapse chevron + transcript body.
///
/// Unlike video, there is no separate media stage — playback chrome lives in
/// the global transport bar. Collapse is a compact top-left control in the
/// body (not a blank [AppBar]) so transcript never sits under floating chrome
/// (ADR-0077).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/player/application/player_collapse.dart';

class AudioPlayerLayout extends ConsumerWidget {
  const AudioPlayerLayout({required this.transcript, super.key});

  final Widget transcript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          left: false,
          right: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: cs.onSurface,
                  size: 28,
                ),
                onPressed: () =>
                    unawaited(collapseExpandedPlayer(ref, context)),
              ),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: t.contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space12,
                  t.space8,
                  t.space12,
                  t.space16,
                ),
                child: transcript,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
