# Data Model: PostHog Product Analytics Integration

**Feature**: `046-posthog-analytics-integration` | **Date**: 2026-09-03
**Companion artifacts**: [research.md](research.md) (decisions D1–D10), [contracts/analytics-facade.md](contracts/analytics-facade.md), [contracts/event-catalog.md](contracts/event-catalog.md)

None of these entities enter `AppDatabase`'s user-facing tables — analytics data lives in the vendor SDK's on-device queue and PostHog cloud. The only locally persisted state is one device-global settings key.

---

## Entities

### E1. Usage Event *(transient — vendor queue only, never persisted app-side)*

| Field | Type / Values | Rules |
|---|---|---|
| `name` | String, one of the catalog names in [event-catalog.md](contracts/event-catalog.md) or vendor autocapture (`Application Opened`, `Application Backgrounded`, `Application Installed`, `Application Updated`, `$screen`) | Compile-time constant from `analytics_events.dart`; free-form names rejected at call sites |
| `timestamp` | ISO-8601 | Set by the vendor SDK; not caller-supplied |
| `distinctId` | String | Identity in force at capture time (see E2); managed by SDK |
| `properties` | `Map<String, Object?>` | Keys restricted to the per-event allowlist in the catalog + common context (E5). **MUST NOT contain user-generated content** — enforced by (a) closed property-key constants, (b) coarse failure-reason enum `network|credits|auth|server|cancelled`, (c) `beforeSend` drop-guard as last resort (D1) |

**Validation**: A unit test enumerates `analytics_events.dart` and asserts every name/property key appears in the catalog contract (II — tests define the contract; prevents doc/code drift).

### E2. Person Identity *(vendor-managed, derived from auth state)*

| Field | Type / Values | Rules |
|---|---|---|
| `distinctId` | `UserProfile.id` (server-assigned String, e.g. from `GET /api/v1/profile`) when signed in; vendor-generated UUID when anonymous | **Never the email address** (spec FR-005) |
| `personProperties` | `email`, `name`, `learningLanguage`, `nativeLanguage`, `subscriptionTier` | Written via `identify(userProperties:)`; optional, metadata only |
| `setOnceProperties` | `firstSeenAt` (SDK-managed), `distributionChannel` | `userPropertiesSetOnce:` — never overwritten after first sign-in |

**State transitions** (driven by `authCtrlProvider` listening in `analytics_bootstrap.dart`, D5):

```
AuthSignedOut ──sign-in──▶ AuthSignedIn(profile)   ⇒ identify(userId: profile.id, …)
AuthSignedIn ──sign-out──▶ AuthSignedOut           ⇒ reset()   // next events are anonymous again
```

- Repeated `AuthSignedIn` emissions for the *same* id (profile refresh) MUST NOT re-`identify` (compare previous id; vendor treats re-identify as a merge signal — avoid churn).
- `reset()` MUST run before the next user can emit events; the listener fires on the `AuthSignedOut` transition emitted inside `AuthCtrl.signOut()` before the sign-in screen renders (auth_router_tick redirect).

### E3. Capture Preference *(the only locally persisted entity)*

| Field | Type | Storage | Rules |
|---|---|---|---|
| `enabled` | bool | Drift key/value, `deviceGlobalAppDatabaseProvider` DB, key `analytics.capture_enabled` (`SettingsKeys` + `_staticKeys`), values `'true'`/`'false'`, **default `true`** | Device-global scope: covers anonymous pre-sign-in events and survives sign-out/account switch (spec FR-007, identity-switch edge case) |

**State transitions**:

```
ON  ──user toggles off──▶ OFF ⇒ Posthog().disable()  + facade stops all Dart-side capture (queued events dropped per D4 verification note)
OFF ──user toggles on───▶ ON  ⇒ Posthog().enable()   + capture resumes in-session (no restart)
```

- Persisted **before** the vendor call effect is surfaced in UI (toggle reflects DB truth on restart).
- Unknown/absent key ⇒ default ON (no migration needed).

### E4. Feature Flag Read *(capability only — no gating in this feature)*

| Field | Type / Values | Rules |
|---|---|---|
| `key` | String | Caller-supplied flag key |
| `value` | bool / String variant / null | `NoopAnalytics` returns the caller-supplied built-in default **always**; `PosthogAnalytics` returns vendor value, falling back to the default on error/timeout/unloaded flags |
| `default` | bool or String | Required parameter at every call site — no call site may omit a safe fallback (spec FR-011) |

### E5. Common Event Context *(super properties registered once at init)*

| Key | Source | Notes |
|---|---|---|
| `display_locale` | app preferences locale | Metadata only |
| `learning_language` | profile/preferences | Metadata only |
| `distribution_channel` | `distribution_channel.dart` (`store`/`direct`) | `setOnce` semantics via super property refresh on sign-in |
| *(vendor-added)* | app version, OS, device class, `$session_id` | Added by the native SDK automatically; not duplicated app-side |

---

## Not modeled (explicitly out of scope, per spec Assumptions)

- Session replay snapshots, surveys, push-notification tokens — vendor capabilities excluded from v1.
- Any dashboard/insight configuration — lives in PostHog cloud, not the app.
- Per-user database rows, sync-queue interaction, or Drift table changes — the settings key reuses the existing generic `SettingsDao` key/value mechanism.
