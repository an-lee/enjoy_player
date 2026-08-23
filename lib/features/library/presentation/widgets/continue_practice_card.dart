/// Home hero: last practiced item (16:9 Continue practicing card).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/presentation/language_labels.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/media_card/badges.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/library/domain/practice_resume.dart';
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

class ContinuePracticeCard extends ConsumerWidget {
  const ContinuePracticeCard({
    super.key,
    required this.resume,
    this.nativeLanguage,
  });

  final PracticeResume resume;
  final String? nativeLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final media = resume.media;
    final progress = resume.progress;
    final radius = BorderRadius.circular(t.radiusXl);
    final pair = continuePracticeLanguagePair(
      l10n: l10n,
      contentLanguage: media.language,
      nativeLanguage: nativeLanguage,
    );
    final source = _sourceLabel(l10n, media);
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

    return EnjoyTappableSurface(
      borderRadius: radius,
      semanticsLabel: semantics,
      onTap: () {
        warmYoutubeSurfaceIfNeeded(ref, provider: media.provider);
        openPlayerRoute(context, media.id);
      },
      child: ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaCardThumbnail(
                file: localThumbnailFileForMedia(media),
                networkUrl: networkThumbnailForMedia(media),
                coverSeed: media.coverSeed,
                isVideo: media.kind == MediaKind.video,
                cs: cs,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC09090B)],
                  ),
                ),
              ),
              Positioned(
                left: t.space16,
                right: t.space16,
                bottom: t.space16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (metaParts.isNotEmpty) ...[
                      SizedBox(height: t.space8),
                      Text(
                        metaParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                    if (progress != null) ...[
                      SizedBox(height: t.space12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(t.radiusFull),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
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
    );
  }
}

String? _sourceLabel(AppLocalizations l10n, Media media) {
  final source = media.source?.trim();
  if (source != null && source.isNotEmpty) return source;
  if (media.provider == 'youtube') return l10n.youtubeBadge;
  if (media.provider == 'craft') return l10n.libraryProviderCraftBadge;
  return null;
}
