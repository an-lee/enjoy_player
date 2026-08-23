# Quickstart Validation Guide: Home Continue Practice

**Date**: 2026-08-23  
**Feature**: [spec.md](./spec.md) | [plan.md](./plan.md) | [research.md](./research.md)

Validate resume-from-Home and no mini player. Automated tests in the table are required for implementation; manual scenarios prove SC-001–SC-007.

## Prerequisites

- Flutter SDK matching `pubspec.yaml` on PATH.
- A debug app on at least one supported target (Windows, macOS, Linux, Android, or iOS).
- At least one library item that can open in the player (local file, Craft, or YouTube as available on that machine).

## Setup

```bash
flutter pub get
# Only if a @Riverpod / Drift annotation changed:
dart run build_runner build --delete-conflicting-outputs
bash .github/scripts/validate_ci_gates.sh
```

## Required automated tests

| Test file | What it proves | Maps to |
|---|---|---|
| `test/data/db/daos/echo_session_dao_test.dart` (extend) | Latest-by-`last_active_at` query; skip / look past missing targets | FR-006, FR-011 |
| `test/features/library/application/home_continue_practice_provider_test.dart` | Resume item follows last session, not recents `updatedAt`; null when no session; progress omitted when duration 0 | FR-001, FR-002, FR-006, FR-011 |
| `test/features/library/presentation/continue_practice_card_test.dart` | Card hidden when resume is null; shows title, progress, Echo when active; tap calls open-player | FR-001–FR-005, FR-013, US3 |
| `test/features/library/home_screen_test.dart` (extend) | Continue sits above recents; empty recents still hides Continue without a fake hero | FR-010, US3, US4 |
| `test/features/player/presentation/root_shell_test.dart` (update) | No mini `GlobalTransportBar` on `/`, `/library`, `/vocabulary` even if a session is injected; still shows transport on `/player/` | FR-007, FR-009 |
| `test/features/player/application/leave_player_clears_session_test.dart` | Collapse / off-player route triggers `clear()` unless `practiceOwnsVideoStage` | FR-008, FR-015 |
| `test/features/player/global_transport_bar_test.dart` (update) | Remove collapsed expand (US3) / mini-route cases; keep in-player always-on packing (US1/US2) | FR-009, spec 007 remainder |
| `test/features/player/player_collapse_test.dart` (update) | Collapse pops route and does not leave a live session | FR-008 |
| `test/features/hotkeys/app_hotkeys_keyboard_listener_test.dart` (update) | Play/expand-from-mini do not require mini chrome; off-player with null session is a no-op | FR-015 |

Run focused:

```bash
flutter test test/features/library/home_screen_test.dart
flutter test test/features/player/presentation/root_shell_test.dart
flutter test test/features/player/global_transport_bar_test.dart
```

Full gates:

```bash
flutter analyze
flutter test
bash .github/scripts/validate_ci_gates.sh
```

## Manual scenarios

### A — Resume from Home (SC-001, SC-005, US1)

1. Open a media item, play into the middle, enable Echo, leave the player (collapse or back).
2. Confirm Home shows **Continue practicing** with that title, Echo, and a progress fill — not a mini bar.
3. Tap the card. Expected: player opens at the same cue / saved time, Echo still on.

### B — No background audio (SC-002, US2)

1. Start playback, leave to Home, then Library, then Discover.
2. Expected: no mini bar, no audio, no OS now-playing of that item.
3. Recents / Library tap still opens the player.

### C — Empty Continue (SC-003, US3)

1. Fresh profile / empty library (or delete the only practiced item).
2. Expected: no Continue card; existing empty Home still offers Import / Discover.

### D — Continue ≠ first recent (US4)

1. Practice item A. Import or browse-touch item B so B is first in recents.
2. Expected: Continue is still A; recents can show B first. Tapping B opens B.

### E — Player transport intact (FR-009)

1. Open `/player/:id`. Expected: full transport bar still present; narrow always-on five controls still visible on a phone-width window.
