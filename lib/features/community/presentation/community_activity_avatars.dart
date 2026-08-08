/// Avatar rendering for the community activity card: initials extraction,
/// individual avatars, and avatar groups (wrap grid + overlapping stack).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:enjoy_player/core/utils/text_normalization.dart';
import 'package:enjoy_player/features/community/domain/active_user.dart';

const int kMaxAvatarsCard = 8;
const int kMaxAvatarsSummary = 4;
const double kSummaryAvatarSize = 28;
const double kSummaryAvatarOverlap = 8;

/// Internal building block for `CommunityActivityCard`; not public API.
String initials(String name) {
  if (name.trim().isEmpty) return 'U';
  final parts = name.trim().split(whitespaceRunRegExp);
  final buf = StringBuffer();
  for (final n in parts) {
    if (n.isEmpty) continue;
    final c = n[0];
    final code = c.codeUnitAt(0);
    final isAlnum =
        (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5a) ||
        (code >= 0x61 && code <= 0x7a);
    if (isAlnum) {
      buf.write(c);
    }
    if (buf.length >= 2) break;
  }
  final s = buf.toString();
  return s.isEmpty ? 'U' : s;
}

/// Internal building block for `CommunityActivityCard`; not public API.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    required this.size,
    required this.fontSize,
  });

  final ActiveUser user;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = initials(user.name);
    final url = user.avatarUrl;

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: cs.onPrimaryContainer,
          ),
        ),
      );
    }

    if (url == null || url.isEmpty) {
      return fallback();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => fallback(),
      ),
    );
  }
}

/// Internal building block for `CommunityActivityCard`; not public API.
class AvatarBorder extends StatelessWidget {
  const AvatarBorder({super.key, required this.cs, required this.child});

  final ColorScheme cs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.surface, width: 2),
      ),
      child: child,
    );
  }
}

/// Internal building block for `CommunityActivityCard`; not public API.
class OverlappingAvatarStack extends StatelessWidget {
  const OverlappingAvatarStack({
    super.key,
    required this.users,
    required this.totalCount,
    required this.maxShown,
    required this.cs,
  });

  final List<ActiveUser> users;
  final int totalCount;
  final int maxShown;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final shown = users.take(maxShown).toList();
    final extra = totalCount > maxShown ? totalCount - maxShown : 0;
    final slots = shown.length + (extra > 0 ? 1 : 0);
    if (slots == 0) return const SizedBox.shrink();

    final step = kSummaryAvatarSize - kSummaryAvatarOverlap;
    final width = kSummaryAvatarSize + (slots - 1) * step;

    return SizedBox(
      width: width,
      height: kSummaryAvatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: AvatarBorder(
                cs: cs,
                child: UserAvatar(
                  user: shown[i],
                  size: kSummaryAvatarSize,
                  fontSize: 10,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * step,
              child: AvatarBorder(
                cs: cs,
                child: Container(
                  width: kSummaryAvatarSize,
                  height: kSummaryAvatarSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Internal building block for `CommunityActivityCard`; not public API.
class AvatarWrap extends StatelessWidget {
  const AvatarWrap({
    super.key,
    required this.users,
    required this.totalCount,
    required this.dense,
    required this.maxShown,
  });

  final List<ActiveUser> users;
  final int totalCount;
  final bool dense;
  final int maxShown;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = dense ? 32.0 : 40.0;
    final fontSize = dense ? 10.0 : 12.0;
    final shown = users.take(maxShown).toList();
    final extra = totalCount > maxShown ? totalCount - maxShown : 0;

    return Wrap(
      spacing: dense ? 6 : 8,
      runSpacing: dense ? 6 : 8,
      children: [
        for (final u in shown)
          UserAvatar(user: u, size: size, fontSize: fontSize),
        if (extra > 0)
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              '+$extra',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
