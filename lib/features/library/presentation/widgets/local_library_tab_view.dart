/// Local Drift library lists (audio rows / video grid).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/layout/enjoy_page_kind.dart';
import 'package:enjoy_player/core/presentation/language_labels.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/theme/generative_media_cover.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/empty_state.dart';
import 'package:enjoy_player/core/theme/widgets/media_card.dart';
import 'package:enjoy_player/core/theme/widgets/media_card/media_card_sync_badge.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';
import 'package:enjoy_player/core/utils/time_format.dart';
import 'package:enjoy_player/features/library/application/library_media_provider.dart';
import 'package:enjoy_player/features/library/application/library_search_provider.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/library/presentation/library_actions.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/youtube_warm.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Tab bodies for local library media, driven by a shared [TabController].
class LocalLibraryTabView extends ConsumerWidget {
  const LocalLibraryTabView({required this.tabController, super.key});

  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(libraryFilteredListsProvider);
    final allMediaAsync = ref.watch(libraryMediaProvider);
    final query = ref.watch(librarySearchProvider);
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;

    final allItems = allMediaAsync.asData?.value ?? const <Media>[];
    final totalAudio = allItems.where((m) => m.kind == MediaKind.audio).length;
    final totalVideo = allItems.where((m) => m.kind == MediaKind.video).length;

    return listsAsync.when(
      data: (lists) {
        return TabBarView(
          controller: tabController,
          children: [
            LocalVideoLibraryBody(
              items: lists.video,
              searchQuery: query,
              totalInLibraryOfKind: totalVideo,
            ),
            LocalAudioLibraryBody(
              items: lists.audio,
              searchQuery: query,
              totalInLibraryOfKind: totalAudio,
            ),
          ],
        );
      },
      loading: () => TabBarView(
        controller: tabController,
        children: const [SkeletonMediaGrid(), SkeletonMediaList()],
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(t.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              SizedBox(height: t.space16),
              Text(
                '${l10n.error}: $e',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              SizedBox(height: t.space16),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(libraryFilteredListsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocalAudioLibraryBody extends StatelessWidget {
  const LocalAudioLibraryBody({
    required this.items,
    required this.searchQuery,
    required this.totalInLibraryOfKind,
    super.key,
  });

  final List<Media> items;
  final String searchQuery;
  final int totalInLibraryOfKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);

    if (items.isEmpty) {
      final filteredBySearch =
          searchQuery.isNotEmpty && totalInLibraryOfKind > 0;
      if (filteredBySearch) {
        return EmptyState(
          icon: Icons.search_off_rounded,
          illustrationAsset: EnjoyIllustrations.emptyLibrary,
          title: l10n.librarySearchNoMatchesTitle,
          subtitle: l10n.librarySearchNoMatchesHint,
          action: () {
            final notifier = ProviderScope.containerOf(
              context,
            ).read(librarySearchProvider.notifier);
            notifier.clear();
          },
          actionLabel: l10n.librarySearchClear,
        );
      }
      return EmptyState(
        icon: Icons.graphic_eq_rounded,
        illustrationAsset: EnjoyIllustrations.emptyLibrary,
        title: l10n.libraryEmptyAudioTitle,
        subtitle: l10n.libraryEmptyAudioHint,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = pageGutterOf(context, constraints.maxWidth);
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(gutter, t.space8, gutter, t.space24),
          itemCount: items.length,
          separatorBuilder: (context, _) => SizedBox(height: t.space8),
          itemBuilder: (context, index) {
            return LocalAudioRow(media: items[index]);
          },
        );
      },
    );
  }
}

class LocalAudioRow extends ConsumerWidget {
  const LocalAudioRow({required this.media, super.key});

  final Media media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playingId = ref.watch(
      playerControllerProvider.select((s) => s?.mediaId),
    );
    final thumb = localThumbnailFileForCard(media.thumbnailPath);
    final netThumb = remoteThumbnailForCard(media.thumbnailPath);
    final dur = formatDurationHmsMs(media.durationMs);
    final accent = generativeAccentForSeed(media.coverSeed);

    return MediaCardRow(
      title: media.title,
      subtitle: dur,
      badge: focusLanguageLabel(l10n, media.language),
      onBadgeTap: () => editMediaLanguage(context, ref, media),
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
      thumbnailFile: thumb,
      thumbnailNetworkUrl: netThumb,
      coverSeed: media.coverSeed,
      isVideo: false,
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

class LocalVideoLibraryBody extends StatelessWidget {
  const LocalVideoLibraryBody({
    required this.items,
    required this.searchQuery,
    required this.totalInLibraryOfKind,
    super.key,
  });

  final List<Media> items;
  final String searchQuery;
  final int totalInLibraryOfKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (items.isEmpty) {
      final filteredBySearch =
          searchQuery.isNotEmpty && totalInLibraryOfKind > 0;
      if (filteredBySearch) {
        return EmptyState(
          icon: Icons.search_off_rounded,
          illustrationAsset: EnjoyIllustrations.emptyRecordings,
          title: l10n.librarySearchNoMatchesTitle,
          subtitle: l10n.librarySearchNoMatchesHint,
          action: () {
            final notifier = ProviderScope.containerOf(
              context,
            ).read(librarySearchProvider.notifier);
            notifier.clear();
          },
          actionLabel: l10n.librarySearchClear,
        );
      }
      return EmptyState(
        icon: Icons.movie_outlined,
        illustrationAsset: EnjoyIllustrations.emptyRecordings,
        title: l10n.libraryEmptyVideoTitle,
        subtitle: l10n.libraryEmptyVideoHint,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = pageGutterOf(context, constraints.maxWidth);
        final crossAxisExtent = constraints.maxWidth - gutter * 2;
        return GridView.builder(
          padding: EdgeInsets.all(gutter),
          gridDelegate: mediaCardTileGridDelegateForMaxTileWidth(
            crossAxisExtent: crossAxisExtent,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => Align(
            alignment: Alignment.topCenter,
            child: LocalVideoTile(media: items[index]),
          ),
        );
      },
    );
  }
}

class LocalVideoTile extends ConsumerWidget {
  const LocalVideoTile({required this.media, super.key});

  final Media media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playingId = ref.watch(
      playerControllerProvider.select((s) => s?.mediaId),
    );
    final thumb = localThumbnailFileForMedia(media);
    final netThumb = networkThumbnailForMedia(media);
    final dur = formatDurationHmsMs(media.durationMs);
    final accent = generativeAccentForSeed(media.coverSeed);

    return MediaCardTile(
      title: media.title,
      subtitle: l10n.miniPlayerMediaVideo,
      badge: focusLanguageLabel(l10n, media.language),
      onBadgeTap: () => editMediaLanguage(context, ref, media),
      durationLabel: media.durationMs > 0 ? dur : null,
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
      isVideo: true,
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
