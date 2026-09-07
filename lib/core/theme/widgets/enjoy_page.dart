/// Adaptive page scaffold — chrome + width family for shell content.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/layout/enjoy_page_kind.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_subpage_app_bar.dart';

typedef EnjoyPageBodyBuilder =
    Widget Function(BuildContext context, EnjoyPageMetrics metrics);

/// Scaffold that applies [EnjoyPageKind] width rules and optional page chrome.
///
/// - Push routes with [title] + [showBack]: [EnjoySubpageAppBar].
/// - Body receives [EnjoyPageMetrics] for gutters / centering insets.
class EnjoyPage extends StatelessWidget {
  const EnjoyPage({
    super.key,
    required this.kind,
    required this.body,
    this.title,
    this.actions,
    this.showBack = false,
    this.onBack,
    this.backgroundColor,
  });

  final EnjoyPageKind kind;
  final EnjoyPageBodyBuilder body;

  /// Subpage / app-bar title.
  final String? title;
  final List<Widget>? actions;

  /// When true, shows [EnjoySubpageAppBar] with a back affordance.
  final bool showBack;

  /// Optional custom back handler for [EnjoySubpageAppBar].
  final VoidCallback? onBack;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final PreferredSizeWidget? appBar = showBack && title != null
        ? EnjoySubpageAppBar(title: title!, actions: actions, onBack: onBack)
        : null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = EnjoyPageMetrics.of(
            context,
            kind: kind,
            paneWidth: constraints.maxWidth,
          );

          return body(context, metrics);
        },
      ),
    );
  }
}
