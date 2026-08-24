/// Primary navigation sidebar — flat tonal panel with hairline border.
/// Glass is intentionally absent here; it lives only on the transport bar.
library;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_logo.dart';
import 'package:enjoy_player/core/theme/widgets/nav_item_pill.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/sidebar_account_chip.dart';
import 'package:enjoy_player/features/hotkeys/presentation/hotkey_tooltip_label.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../../../library/application/library_search_focus.dart';
import '../../../library/application/library_search_focus_provider.dart';
import '../../../library/application/library_search_provider.dart';

class AppSidebar extends ConsumerStatefulWidget {
  const AppSidebar({super.key});

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  late final TextEditingController _searchController;
  FocusNode? _attachedSearchFocusNode;
  VoidCallback? _searchFocusListener;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(librarySearchProvider),
    );
  }

  @override
  void dispose() {
    _detachSearchFocusListener();
    _searchController.dispose();
    super.dispose();
  }

  void _detachSearchFocusListener() {
    if (_searchFocusListener != null && _attachedSearchFocusNode != null) {
      _attachedSearchFocusNode!.removeListener(_searchFocusListener!);
    }
    _searchFocusListener = null;
    _attachedSearchFocusNode = null;
  }

  void _attachSearchFocusListener(FocusNode node) {
    if (identical(node, _attachedSearchFocusNode)) return;
    _detachSearchFocusListener();
    _attachedSearchFocusNode = node;
    _searchFocusListener = () {
      if (!node.hasFocus || !mounted) return;
      ensureLibraryRouteForSearch(GoRouter.of(context));
    };
    node.addListener(_searchFocusListener!);
  }

  @override
  Widget build(BuildContext context) {
    final searchFocusNode = ref.watch(librarySearchFocusNodeProvider);
    _attachSearchFocusListener(searchFocusNode);

    ref.listen(librarySearchFocusRequestProvider, (previous, next) {
      searchFocusNode.requestFocus();
    });

    ref.listen(librarySearchProvider, (previous, next) {
      if (_searchController.text != next) {
        _searchController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    final t = EnjoyThemeTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final path = GoRouterState.of(context).uri.path;
    final searchTooltip = hotkeyTooltipLabel(
      ref,
      'library.search',
      l10n.hotkeysDescLibrarySearch,
    );

    return Material(
      color: cs.surfaceContainerLow,
      child: SizedBox(
        width: t.sidebarWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
          ),
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDesktop && defaultTargetPlatform == TargetPlatform.macOS)
                  SizedBox(height: t.space8),
                // Brand row
                SizedBox(
                  height: t.sidebarBrandHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: t.space16),
                    child: Row(
                      children: [
                        const EnjoyLogo(size: 28),
                        SizedBox(width: t.space12),
                        Expanded(
                          child: Text(
                            l10n.appTitle,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: t.heroTitleLetterSpacing * 0.35,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space16,
                    0,
                    t.space16,
                    t.space16,
                  ),
                  child: Tooltip(
                    message: searchTooltip,
                    child: TextField(
                      focusNode: searchFocusNode,
                      controller: _searchController,
                      onTap: () =>
                          ensureLibraryRouteForSearch(GoRouter.of(context)),
                      onChanged: (v) =>
                          ref.read(librarySearchProvider.notifier).setQuery(v),
                      onSubmitted: (_) =>
                          ref.read(librarySearchProvider.notifier).commit(),
                      style: tt.bodyMedium,
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(t.radiusSm),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: t.space12,
                          vertical: t.space8,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),

                // Nav items
                NavItemPill(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  iconWidget: const EnjoyChromeIcon(EnjoyChromeGlyph.home),
                  selectedIconWidget: const EnjoyChromeIcon(
                    EnjoyChromeGlyph.home,
                  ),
                  label: l10n.homeTitle,
                  selected: path == '/',
                  iconSize: 22,
                  onTap: () => context.go('/'),
                ),
                NavItemPill(
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore_rounded,
                  iconWidget: const EnjoyChromeIcon(EnjoyChromeGlyph.compass),
                  selectedIconWidget: const EnjoyChromeIcon(
                    EnjoyChromeGlyph.compass,
                  ),
                  label: l10n.discoverTitle,
                  selected: path.startsWith('/discover'),
                  iconSize: 22,
                  onTap: () => context.go('/discover'),
                ),
                NavItemPill(
                  icon: Icons.collections_bookmark_outlined,
                  selectedIcon: Icons.collections_bookmark_rounded,
                  iconWidget: const EnjoyChromeIcon(EnjoyChromeGlyph.library),
                  selectedIconWidget: const EnjoyChromeIcon(
                    EnjoyChromeGlyph.library,
                  ),
                  label: l10n.libraryTitle,
                  selected:
                      path.startsWith('/library') || path.startsWith('/cloud'),
                  iconSize: 22,
                  onTap: () => context.go('/library'),
                ),

                const Spacer(),

                // Account chip at bottom
                const SidebarAccountChip(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
