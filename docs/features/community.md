# Feature: Community activity (signed-in home dashboard)

## Summary

The community activity card surfaces **active learners** on the signed-in **Home** screen. It only renders for `AuthSignedIn` users (the Home body itself stays unchanged for signed-out users). The card is sourced from the same `GET /api/v1/users/active` endpoint that the web app uses, returning a small avatar roster plus an aggregated **today's practice** stat.

## MVP behavior

### Endpoint

- **Endpoint**: `GET /api/v1/users/active`, called with the device **IANA** timezone id (e.g. `Asia/Shanghai` via `clientTimezoneId()` / `flutter_timezone`). Abbreviations like `HKT`/`CST` are not sent — Rails rejects them and falls back to UTC. If the native plugin fails, the client sends a UTC offset (`+08:00`). The JSON shape is camelCase and decoded via the shared `convertKeysToCamel` helper (`lib/data/api/case_conversion.dart`).
- **Timeout**: the request uses an **8-second client timeout**; on timeout (or any other error), the card hides / shows no data rather than a retry affordance (matches web parity).
- **Variants**: `CommunityActivityCardVariant.card` (full stats + up to 8 avatars; tablet/desktop) and `CommunityActivityCardVariant.summary` (compact headline + up to 4 avatars; mobile insight strip).
- **Today stats**: when the server returns `recordingsCountToday` / `recordingsDurationToday`, the card shows the aggregated practice volume; otherwise the stat row is hidden.
- **Avatars**: rendered with `CachedNetworkImage` from `avatarUrl` (Dicebear SVG URLs are rewritten to PNG via `rasterAvatarUrl` in `lib/core/utils/avatar_url.dart` because Flutter cannot decode SVG with raster image widgets); missing avatars fall back to **initials** derived from the user's name (`initials` helper in `community_activity_avatars.dart`).
- **Layout**: on wide viewports (≈720px+) Today's Goal and Community Activity cards share a responsive two-column row above the recent media grid; on narrow screens they stack.

## Signed-in gating

The card is only mounted on Home when `authCtrlProvider` reports `AuthSignedIn`. The Home screen otherwise renders the existing recents grid with no community / today's-goal section. No retry affordance for the community API: a transient error → empty card.

## Code map

| Area | Path |
|------|------|
| Domain models | [`lib/features/community/domain/active_user.dart`](../../lib/features/community/domain/active_user.dart) |
| Riverpod provider | [`lib/features/community/application/active_users_provider.dart`](../../lib/features/community/application/active_users_provider.dart) |
| Client IANA timezone | [`lib/core/utils/client_timezone.dart`](../../lib/core/utils/client_timezone.dart) |
| Card UI (card + summary variants) | [`lib/features/community/presentation/community_activity_card.dart`](../../lib/features/community/presentation/community_activity_card.dart) |
| └ avatars (initials, wrap grid, overlapping stack) | [`community_activity_avatars.dart`](../../lib/features/community/presentation/community_activity_avatars.dart) |
| └ bodies (card + summary content) | [`community_activity_bodies.dart`](../../lib/features/community/presentation/community_activity_bodies.dart) |
| └ metrics (today's practice stat row) | [`community_activity_metrics.dart`](../../lib/features/community/presentation/community_activity_metrics.dart) |
| └ stats (headline summary content) | [`community_activity_stats.dart`](../../lib/features/community/presentation/community_activity_stats.dart) |

## Related

- Home screen: [`docs/features/library.md`](library.md) (Home / Today's Goal block shares the responsive two-column row)
- Auth: [`docs/features/auth.md`](auth.md)
- ADR: [`docs/decisions/0010-cloud-sync-mvp.md`](../decisions/0010-cloud-sync-mvp.md)