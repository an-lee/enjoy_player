/// Sidebar rail: compact Continue practicing card above the account chip.
///
/// Desktop-only entry point — the sidebar mounts at the rail breakpoint and
/// Home carries no Continue section (the last-practiced item is already the
/// first row of its recents grid).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/presentation/language_labels.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/media_card/badges.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';
import 'package:enjoy_player/features/library/application/continue_practice_provider.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/player/application/youtube_warm.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Content · native labels when at least one side is known.
String? continuePracticeLanguagePair({
  required AppLocalizations l10n,
  required String contentLanguage,
  String? nativeLanguage,
}) {
  final contentUnknown = tagsEqual(contentLanguage, kUnknownMediaLanguageTag);
  final native = nativeLanguage?.trim();
  final nativeMissing = native == null || native.isEmpty;
  if (contentUnknown && nativeMissing) return null;
  if (contentUnknown) return focusLanguageLabel(l10n, native!);
  if (nativeMissing) return focusLanguageLabel(l10n, contentLanguage);
  return '${focusLanguageLabel(l10n, contentLanguage)} · ${focusLanguageLabel(l10n, native)}';
}

/// Item source label, or the provider badge ("YouTube", "Craft") when the
/// item has no user-facing source label.
String? continuePracticeSourceLabel(AppLocalizations l10n, Media media) {
  final source = media.source?.trim();
  if (source != null && source.isNotEmpty) return source;
  if (media.provider == 'youtube') return l10n.youtubeBadge;
  if (media.provider == 'craft') return l10n.libraryProviderCraftBadge;
  return null;
}

class SidebarContinuePracticeCard extends ConsumerWidget {
  const SidebarContinuePracticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resume = ref.watch(continuePracticeResumeProvider);
    if (resume == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final media = resume.media;
    final progress = resume.progress;
    final radius = BorderRadius.circular(t.radiusLg);
    final pair = continuePracticeLanguagePair(
      l10n: l10n,
      contentLanguage: media.language,
      nativeLanguage: ref
          .watch(appPreferencesCtrlProvider)
          .valueOrNull
          ?.effectiveNativeLanguage,
    );
    final source = continuePracticeSourceLabel(l10n, media);
    final metaParts = <String>[
      if (source != null) source,
      if (resume.echoActive) l10n.echoMode,
      if (pair != null) pair,
    ];
    final percent = progress == null
        ? null
        : (progress * 100).round().clamp(0, 100);
    final semantics = [
      l10n.homeContinueOpenSemantics(media.title),
      if (percent != null) l10n.homeContinueProgressSemantics(percent),
    ].join('. ');

    return Padding(
      padding: EdgeInsets.fromLTRB(t.space8, 0, t.space8, t.space8),
      child: EnjoyTappableSurface(
        borderRadius: radius,
        semanticsLabel: semantics,
        onTap: () {
          warmYoutubeSurfaceIfNeeded(ref, provider: media.provider);
          openPlayerRoute(context, media.id);
        },
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: MediaCardThumbnail(
                    file: localThumbnailFileForMedia(media),
                    networkUrl: networkThumbnailForMedia(media),
                    coverSeed: media.coverSeed,
                    isVideo: media.kind == MediaKind.video,
                    cs: cs,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(t.space12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.homeContinuePracticing,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: t.space4),
                      Text(
                        media.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (metaParts.isNotEmpty) ...[
                        SizedBox(height: t.space4),
                        Text(
                          metaParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (progress != null) ...[
                        SizedBox(height: t.space8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(t.radiusFull),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: cs.onSurface.withValues(
                              alpha: 0.15,
                            ),
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
