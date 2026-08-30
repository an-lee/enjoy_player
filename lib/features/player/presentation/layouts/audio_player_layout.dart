/// Audio-only expanded player: floating collapse control + transcript body.
///
/// Unlike video, there is no separate media stage — playback chrome lives in
/// the global transport bar. Collapse is the same floating frosted control as
/// the video stage's, layered over the transcript; cues scroll under its blur
/// and there is no reserved toolbar slot (ADR-0085 supersedes ADR-0077).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_collapse_control.dart';

class AudioPlayerLayout extends ConsumerWidget {
  const AudioPlayerLayout({required this.transcript, super.key});

  final Widget transcript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = EnjoyThemeTokens.of(context);

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: t.contentMaxWidth),
              child: Padding(
                // Desktop windows have no status-bar inset — add a roomier
                // top inset so the column doesn't hug the window edge.
                padding: isDesktop
                    ? EdgeInsets.fromLTRB(
                        t.space12,
                        t.space32,
                        t.space12,
                        t.space16,
                      )
                    : EdgeInsets.fromLTRB(
                        t.space12,
                        t.space16,
                        t.space12,
                        t.space16,
                      ),
                child: transcript,
              ),
            ),
          ),
          // Safe-area inset comes from the layout-level [SafeArea] above, so
          // the control only carries its own on-stage edge inset.
          PlayerCollapseControl(
            inset: EdgeInsets.only(left: t.space8, top: t.space8),
          ),
        ],
      ),
    );
  }
}
