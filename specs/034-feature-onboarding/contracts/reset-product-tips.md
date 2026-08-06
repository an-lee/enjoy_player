# Contract C4: Reset product tips

## Purpose

Settings → About control that clears all tip progress (FR-009, US4).

## UI

| Element | Behavior |
|---------|----------|
| Location | `AboutSectionCard` (`SettingsSectionIds.about`) |
| Control | `SettingsRow` (title + subtitle explaining tips will show again) |
| Confirm | Dialog: cancel / confirm reset |
| Success | Optional snackbar/notice; no navigation away required |

### ARB (illustrative)

- `settingsResetProductTipsTitle`
- `settingsResetProductTipsSubtitle`
- `settingsResetProductTipsConfirmTitle`
- `settingsResetProductTipsConfirmBody`
- `settingsResetProductTipsConfirmAction`
- `settingsResetProductTipsDone` (optional)

## Behavior

1. Confirm → call `OnboardingProgress.resetAll()`.
2. Clears global tip JSON **and** all per-media empty-transcript onboarding keys.
3. MUST NOT sign out, clear library, wipe diagnostics prefs, or alter player preferences.
4. After reset, returning to Home / eligible Player contexts MAY auto-show tips again when eligibility holds.

## Tests

- Widget: row visible in About; confirm calls reset; cancel does not.
- Unit/integration: after seeding progress + one media key, reset leaves unrelated `SettingsKeys` intact.
