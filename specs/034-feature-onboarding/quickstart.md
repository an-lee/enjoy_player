# Quickstart: Feature Onboarding Guides

**Feature**: 034-feature-onboarding  
**Contracts**: [contracts/README.md](./contracts/README.md) · **Model**: [data-model.md](./data-model.md)

## Prerequisites

- Flutter SDK per repo README
- Signed-in session
- At least one local media item (for empty-transcript local path) and optionally a YouTube library item
- Desktop recommended for resize / multi-window smoke (Windows or macOS)

## Setup

```bash
flutter pub get
# After adding showcaseview + @Riverpod providers:
dart run build_runner build
flutter gen-l10n
```

## Automated checks (implementation phase)

```bash
flutter analyze
flutter test test/features/onboarding
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected: analyze clean; unit tests for eligibility + progress scopes + reset; widget tests for Home sequence, empty-transcript per-media, About reset row.

## Manual scenarios

### M1 — Home Craft & Import (US1 / FR-002, FR-005a)

1. Reset product tips (or fresh profile).
2. Open Home → tips introduce Import then Craft (or catalog order).
3. Skip → Home usable; tips do not return this session/later until reset.
4. Reset again → tap highlighted Import → import chooser opens; tip advances/closes without stuck overlay.
5. Reset → tap highlighted Craft → Craft opens cleanly.

### M2 — Empty transcript local + per-media (US2 / FR-003, FR-006a)

1. Reset tips. Open local media with no transcript → local obtain tip appears.
2. Dismiss → reopen same media → tip does not re-nag.
3. Open different no-transcript local media → tip may show again.
4. Tap highlighted obtain control → real extract/import/generate flow starts.
5. Successfully add transcript → tip progress for that media is completed.

### M3 — Empty transcript YouTube (US2 / FR-003)

1. Reset tips. Open YouTube media with no transcript → **Fetch transcript** tip/CTA visible.
2. Tap CTA → cloud fetch path runs; tip closes/advances.
3. Media with transcript already → empty tip does not show.

### M4 — Practice chain same visit (US3 / FR-004, FR-004a)

1. Reset tips. Open media with transcript.
2. Echo tip → complete or skip → record tip can appear same visit when ready.
3. Record → after a take, assess tip can appear same visit.
4. Skip any step → playback remains usable; no overlay stack.

### M5 — Reset product tips (US4 / FR-009)

1. Complete Home tips + dismiss empty tip on media A.
2. Settings → About → Reset product tips → confirm.
3. Library/account intact; Home tips and media A empty tip can show again.
4. Cancel on confirm dialog → progress unchanged.

### M6 — Desktop chrome (FR-013, SC-005)

1. Show a tip on Windows/macOS; resize window mid-tip → highlight stays sane or dismisses safely.
2. Dismiss → full control restored in &lt;2s.
3. Navigate away mid-tip → no stuck barrier on next screen.

## Definition of done (planning → implement)

- [ ] Contracts C1–C4 implemented
- [ ] ADR + `docs/features/onboarding.md` updated
- [ ] Automated tests above green
- [ ] Manual M1–M5 on at least one mobile + one desktop target; M6 on desktop
