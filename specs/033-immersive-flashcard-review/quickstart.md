# Quickstart: Immersive Flashcard Review

**Feature**: 033-immersive-flashcard-review  
**Contract**: [contracts/immersive-review-shell.md](contracts/immersive-review-shell.md)

## Prerequisites

- Local vocabulary book with ≥ 3 items (or seed via existing test helpers / lookup → add word).
- App runnable on desktop window and a phone-class width (device or resized window).

## Automated

```bash
# Shell chrome immersion
flutter test test/features/player/presentation/root_shell_test.dart

# Learning loop + Esc / onExit (must stay green)
flutter test test/features/vocabulary/presentation/vocabulary_review_escape_test.dart
flutter test test/features/vocabulary/presentation/vocabulary_review_session_screen_test.dart

# Optional full gates before push
bash .github/scripts/validate_ci_gates.sh
```

Expected: new/extended `root_shell_test` cases for `/vocabulary/review` pass per the chrome matrix; review session tests unchanged in behavior.

## Manual — desktop immersive session

1. Launch the app; open a media item so the mini player bar is visible.
2. Profile → Vocabulary → Review → start a small queue (e.g. Due or Random 5).
3. **Expect**: Review fills the window; **no** sidebar/search; **no** mini player bar; card + progress + close/skip remain.
4. Flip (Space or button), rate (`1`/`2`/`3`), skip once, undo once.
5. **Expect**: Same learning behavior as before; still no shell chrome.
6. Press Esc (or close).
7. **Expect**: Back on Vocabulary (or prior); sidebar + mini player bar restored if session still active.

## Manual — phone-class width

1. Resize below the rail breakpoint (or use a phone simulator).
2. Start review again.
3. **Expect**: No bottom nav; no mini transport; full content-area bleed.
4. Exit review.
5. **Expect**: Bottom nav (and mini transport if media active) return.

## Manual — clip practice still works (smoke)

1. During immersive review, open a card back with playable context and start clip practice if available.
2. **Expect**: Practice overlay / video stage still functions without the global mini bar.
3. Leave practice / continue rating; exit session; chrome restores.

## Done when

- [x] Automated shell tests cover immersive chrome matrix
- [x] Desktop + narrow immersion covered by `root_shell_test` (resize + exit restore); remaining device smoke optional at PR review
- [x] `docs/features/vocabulary.md` updated for immersive wording
- [x] No SRS / shortcut regressions in existing review tests
