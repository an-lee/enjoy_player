# Subscription & Pro upgrade

## Behavior

Signed-in users open **Subscription** from any of:

- Sidebar account row — Free users see an inline **Upgrade** pill that routes to `/subscription`.
- Profile → Account → **Subscription**.
- Direct route `/subscription`.
- AI credits-limit errors — **View plans & packages** → `/subscription`.

### All platforms

- Live status from `GET /api/v1/subscriptions` (tier, active/inactive, expiration, daily credits limit, optional nested `auto_renew`).
- Free / Lite / Pro tier catalog (`TierCatalog`): all tiers share the same AI feature set; differentiation is daily credits (**Free 1,000**, **Lite 12,000 = 12× Free**, **Pro 60,000 = 60× Free**). Paid tiers also advertise vocabulary flashcard download (Anki CSV, gated by `isPaidTier`) and more features coming.
- Auto-renew plan catalog from `GET /api/v1/subscriptions/plans` (monthly / yearly when configured).
- Cancel auto-renew via `POST /api/v1/subscriptions/cancel` when the billing subscription is cancelable (works on mobile too — no external checkout).
- Credits packages section (`$2` / `$5` / `$50` permanent credits) from Rails `/api/v1/credits/packages`; standing from Worker `GET /credits/summary`.
- Pull-to-refresh on the subscription screen; automatic tier reconciliation on app resume and cold start (see [ADR-0041](../decisions/0041-unified-tier-reconciliation.md)).

### Tier source of truth

All tier indicators (sidebar chip, profile hero card, subscription screen) read the single synchronous `currentTierProvider`, which prefers live `subscriptionStatusProvider` and falls back to the cached `UserProfile.subscriptionTier` while the live status is loading on cold start. Never read `UserProfile.subscriptionTier` directly in UI — it is a cache, not the source of truth.

### Reconciliation & celebration

- `TierReconcileHost` (mounted in `RootShell`) is a global `WidgetsBindingObserver`. On `AppLifecycleState.resumed` and on (re)sign-in it runs `TierReconcileCtrl.reconcile()`, which refreshes **both** the live status and the cached profile.
- When a genuine `free → pro` transition is detected, an `AppNotice.success` snackbar ("You're now Pro — enjoy!") is shown.
- App-initiated Pro checkout: `markPurchasePending()` → eager resume poll until Pro.
- App-initiated credits-package checkout: `markPackagePurchasePending(expectedCredits:, baselinePermanent:)` → eager poll of Worker credits summary until permanent credits increase.

### Desktop (Windows, macOS, Linux)

- **Upgrade** (Free) opens the **auto-renew plan sheet** (primary): choose monthly ($9.99) or yearly ($99.99), confirm, external Stripe Checkout via `pay_url`.
- **Pay for months once** (secondary on the plan sheet): prepaid months — **hidden while an auto-renew plan is actively renewing** (`hasActiveAutoRenewPlan`).
- **Pro membership card**: renew date / credits; **Cancel auto-renew** is a low-emphasis text action (not a primary/secondary button). Extend appears only when the user is Pro without active auto-renew.
- **Credits packages**: confirm price/credits → external Checkout; subscription unchanged.
- Platform gate: `supportsExternalSubscriptionPurchase` → Windows || macOS || Linux ([ADR-0032](../decisions/0032-platform-scoped-subscription-purchase.md)).

> **Note** — the `mixin` value is preserved on the wire (Rails API still expects `processor=mixin`); only the UI label is **Cryptocurrency** (en) / **虚拟货币** (zh).

### Mobile (iOS, Android)

- Status, comparison, auto-renew cancel, and package catalog (view) in this milestone.
- Purchase taps (auto-renew, prepaid, packages) show **Mobile purchase coming soon** — no external payment URLs.
- StoreKit / Play Billing deferred to a follow-up spec.

## API (client)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/v1/subscriptions` | Current subscription status (+ `auto_renew`) |
| GET | `/api/v1/subscriptions/plans` | Auto-renew catalog |
| POST | `/api/v1/subscriptions` | Prepaid months checkout (`months`, `processor`) |
| POST | `/api/v1/subscriptions/auto_renew` | Start auto-renew (`plan_id`) |
| POST | `/api/v1/subscriptions/cancel` | Cancel auto-renew at period end |
| GET | `/api/v1/credits/packages` | Credits package catalog |
| POST | `/api/v1/credits/packages/purchases` | Start package checkout (`package_id`) |
| GET | `{AI}/credits/summary` | Worker daily + permanent wallet (post-package refresh) |

Rails API base URL (`apiClientProvider`); Worker via `aiApiClientProvider`; bearer auth required.

## Related

- Spec: `specs/027-auto-renew-credit-packages/`
- [ADR-0032](../decisions/0032-platform-scoped-subscription-purchase.md) — platform-scoped purchase (incl. Linux).
- [ADR-0041](../decisions/0041-unified-tier-reconciliation.md) — unified tier reconciliation.
- [credits-usage.md](credits-usage.md) — usage audit; packages/summary also surface on `/subscription`.
