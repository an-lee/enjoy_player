/// Home: editorial header + hero last-played card + recent media grid.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/presentation/language_labels.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/utils/sliver_key_index.dart';
import 'package:enjoy_player/core/theme/generative_media_cover.dart';
import 'package:enjoy_player/core/layout/enjoy_page_kind.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/editorial_header.dart';
import 'package:enjoy_player/core/theme/widgets/empty_state.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_page.dart';
import 'package:enjoy_player/core/theme/widgets/media_card.dart';
import 'package:enjoy_player/core/theme/widgets/media_card/media_card_sync_badge.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';
import 'package:enjoy_player/core/utils/time_format.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/community/presentation/community_activity_card.dart';
import 'package:enjoy_player/features/library/presentation/todays_goal_card.dart';
import 'package:enjoy_player/features/onboarding/application/onboarding_controller.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_eligibility.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_target.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/youtube_warm.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../application/library_media_provider.dart';
import '../domain/media.dart';
import 'library_actions.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final path = GoRouterState.of(context).uri.path;
      unawaited(
        ref
            .read(onboardingControllerProvider.notifier)
            .tryStartHomeEntries(
              TriggerContext(routePath: path.isEmpty ? '/' : path),
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(libraryHomeRecentsProvider);
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);

    return EnjoyPage(
      kind: EnjoyPageKind.browse,
      body: (context, metrics) {
        final gutter = metrics.gutter;
        return mediaAsync.when(
          data: (recent) {
            return CustomScrollView(
              slivers: [
                // Editorial header
                SliverToBoxAdapter(
                  child: EditorialHeader(
                    title: l10n.homeTitle,
                    trailing: _HomeHeaderActions(
                      onCraft: () => context.push('/craft'),
                      onImport: () => showImportChooser(context, ref),
                    ),
                  ),
                ),

                // Today's goal + community (signed-in, responsive grid) —
                // always rendered, even when the recents grid below is
                // replaced by the empty state, so returning users still
                // see their streak/community progress on a fresh library.
                const SliverToBoxAdapter(child: _HomeInsightCards()),

                if (recent.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.collections_bookmark_rounded,
                      illustrationAsset: EnjoyIllustrations.emptyLibrary,
                      title: l10n.homeEmptyTitle,
                      subtitle: l10n.homeEmptyHint,
                      action: () => showImportChooser(context, ref),
                      actionLabel: l10n.actionImport,
                      secondaryAction: () => context.go('/discover'),
                      secondaryActionLabel: l10n.discoverBrowseAction,
                    ),
                  )
                else ...[
                  // Recents section label
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, t.space12),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        l10n.homeRecentMedia,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ),

                  // Media grid — aspect ratio tracks actual tile width so rows stay tight.
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        return SliverGrid(
                          gridDelegate:
                              mediaCardTileGridDelegateForMinTileWidth(
                                crossAxisExtent: constraints.crossAxisExtent,
                                mainAxisSpacing: t.space12,
                                crossAxisSpacing: t.space12,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final m = recent[index];
                              return Align(
                                key: ValueKey<String>('home-media-${m.id}'),
                                alignment: Alignment.topCenter,
                                child: _HomeMediaTile(media: m),
                              );
                            },
                            childCount: recent.length,
                            findChildIndexCallback: (key) =>
                                findSliverIndexByPrefixedId(
                                  items: recent,
                                  key: key,
                                  prefix: 'home-media-',
                                  idOf: (m) => m.id,
                                ),
                          ),
                        );
                      },
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: t.space24)),
                ],
              ],
            );
          },
          loading: () => const _HomeLoadingScrollView(),
          error: (e, _) {
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: Padding(
                padding: EdgeInsets.all(t.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: cs.error,
                    ),
                    SizedBox(height: t.space16),
                    Text(
                      '${l10n.error}: $e',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(height: t.space16),
                    FilledButton.tonal(
                      onPressed: () =>
                          ref.invalidate(libraryHomeRecentsProvider),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Home layout while [libraryHomeRecentsProvider] has not emitted yet — mirrors the
/// loaded scroll view except insight cards (Today's Goal / community), which
/// mount only after the first media emission to avoid competing with the
/// initial DB query.
class _HomeLoadingScrollView extends ConsumerWidget {
  const _HomeLoadingScrollView();

  static const int _kSkeletonTileCount = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = pageGutterOf(context, constraints.maxWidth);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: EditorialHeader(
                title: l10n.homeTitle,
                trailing: _HomeHeaderActions(
                  onCraft: () => context.push('/craft'),
                  onImport: () => showImportChooser(context, ref),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, t.space12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.homeRecentMedia,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverLayoutBuilder(
                builder: (context, gridConstraints) {
                  return SliverGrid(
                    gridDelegate: mediaCardTileGridDelegateForMinTileWidth(
                      crossAxisExtent: gridConstraints.crossAxisExtent,
                      mainAxisSpacing: t.space12,
                      crossAxisSpacing: t.space12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const _HomeRecentGridSkeletonTile(),
                      childCount: _kSkeletonTileCount,
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: t.space24)),
          ],
        );
      },
    );
  }
}

/// Home header trailing actions — Craft entry + Import — shared by the
/// loaded and loading scroll views so both stay in sync.
class _HomeHeaderActions extends ConsumerWidget {
  const _HomeHeaderActions({required this.onCraft, required this.onImport});

  final VoidCallback onCraft;
  final VoidCallback onImport;

  void _act(WidgetRef ref, OnboardingTipId tip, VoidCallback action) {
    // Persist even if the showcase overlay did not receive the tap (button
    // under the hole) or dismiss raced ahead of onTargetClick.
    unawaited(
      ref.read(onboardingControllerProvider.notifier).onTargetActed(tip),
    );
    action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingTarget(
          tipId: OnboardingTipId.homeCraft,
          onTargetAction: onCraft,
          child: OutlinedButton.icon(
            // Direct taps (overlay hole miss) still resolve the tip.
            onPressed: () => _act(ref, OnboardingTipId.homeCraft, onCraft),
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(l10n.homeCraftAction),
          ),
        ),
        SizedBox(width: t.space8),
        OnboardingTarget(
          tipId: OnboardingTipId.homeImport,
          onTargetAction: onImport,
          child: FilledButton.icon(
            onPressed: () => _act(ref, OnboardingTipId.homeImport, onImport),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.actionImport),
          ),
        ),
      ],
    );
  }
}

class _HomeRecentGridSkeletonTile extends StatelessWidget {
  const _HomeRecentGridSkeletonTile();

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final base = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(t.radiusXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: base),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space12,
              t.space8,
              t.space12,
              t.space12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: t.space4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 12,
                    width: 88,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeInsightCards extends ConsumerWidget {
  const _HomeInsightCards();

  static const double _kStripSplitMinWidth = 420;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authCtrlProvider);
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;

    final isSignedIn = authAsync.maybeWhen(
      data: (s) => s is AuthSignedIn,
      orElse: () => false,
    );

    if (!isSignedIn) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _kStripSplitMinWidth;
        final gutter = pageGutterOf(context, constraints.maxWidth);
        final pad = wide
            ? EdgeInsets.fromLTRB(gutter, t.space20, gutter, t.space20)
            : EdgeInsets.fromLTRB(gutter, t.space12, gutter, t.space12);

        final strip = Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(
                        flex: 5,
                        child: TodaysGoalCard(
                          variant: TodaysGoalCardVariant.bar,
                          containedInParentCard: true,
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                      const Expanded(
                        flex: 4,
                        child: CommunityActivityCard(
                          outerPadding: EdgeInsets.zero,
                          variant: CommunityActivityCardVariant.summary,
                          containedInParentCard: true,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TodaysGoalCard(
                      variant: TodaysGoalCardVariant.bar,
                      containedInParentCard: true,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                    const CommunityActivityCard(
                      outerPadding: EdgeInsets.zero,
                      variant: CommunityActivityCardVariant.summary,
                      containedInParentCard: true,
                    ),
                  ],
                ),
        );

        return Padding(padding: pad, child: strip);
      },
    );
  }
}

class _HomeMediaTile extends ConsumerWidget {
  const _HomeMediaTile({required this.media});

  final Media media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playingId = ref.watch(
      playerControllerProvider.select((s) => s?.mediaId),
    );
    final isVideo = media.kind == MediaKind.video;
    final thumb = localThumbnailFileForMedia(media);
    final netThumb = networkThumbnailForMedia(media);
    final dur = formatDurationHmsMs(media.durationMs);
    // Grid tiles use the deterministic generative accent — running
    // `PaletteGenerator.fromImageProvider` per tile decodes + analyses pixels
    // on the main isolate (palette_generator 0.3.x predates isolate
    // support), and with 15+ tiles the parallel completions serialize into
    // multi-second UI freezes on Windows debug builds. The artwork-derived
    // palette is still used for the active player (hero artwork).
    final accent = generativeAccentForSeed(media.coverSeed);

    return MediaCardTile(
      title: media.title,
      subtitle: isVideo
          ? l10n.miniPlayerMediaVideo
          : '${l10n.miniPlayerMediaAudio} · $dur',
      badge: focusLanguageLabel(l10n, media.language),
      onBadgeTap: () => editMediaLanguage(context, ref, media),
      durationLabel: isVideo && media.durationMs > 0 ? dur : null,
      thumbnailFile: thumb,
      providerBadge: media.provider == 'youtube'
          ? l10n.youtubeBadge
          : media.provider == 'craft'
          ? l10n.libraryProviderCraftBadge
          : null,
      cloudSyncBadge: resolveMediaCardSyncBadge(
        provider: media.provider,
        mediaUrl: media.mediaUrl,
        syncStatus: media.syncStatus,
      ),
      thumbnailNetworkUrl: netThumb,
      coverSeed: media.coverSeed,
      isVideo: isVideo,
      accentColor: accent,
      heroArtworkMediaId: playingId == media.id ? null : media.id,
      deleteTooltip: l10n.libraryDeleteMediaTooltip,
      onDelete: () => confirmAndDeleteMedia(context, ref, media),
      onTap: () {
        warmYoutubeSurfaceIfNeeded(ref, provider: media.provider);
        openPlayerRoute(context, media.id);
      },
    );
  }
}
