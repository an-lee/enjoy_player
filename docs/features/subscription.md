# Subscription & Pro upgrade

## Behavior

Signed-in users open **Subscription** from any of:

- Sidebar account row — Free users see an inline **Upgrade** pill that routes to `/subscription`.
- Profile → Account → **Subscription**.
- Direct route `/subscription`.
- AI credits-limit errors — **View plans & packages** → `/subscription`.

### All platforms

- Live status from `GET /api/v1/subscriptions` (tier, active/inactive, expiration, daily credits limit, optional nested `auto_renew`).
- Free / Lite / Pro tier catalog (`TierCatalog`): a unified 3-card layout (Free / Lite / Pro) that mirrors the web catalog. All tiers share the same AI feature set; differentiation is daily credits (**Free 1,000**, **Lite 12,000 = 12× Free**, **Pro 60,000 = 60× Free**). The card CTAs come from the plans catalog (`GET /api/v1/subscriptions/plans`) — `Choose Lite` / `Extend Lite` (`subscriptionTierCatalogChooseLite` / `subscriptionTierCatalogExtendLite`) for the Lite card and the matching Pro strings for Pro — with a skeleton shown until the plan loads. The card tap surfaces `showUnifiedPurchaseSheet(onChoosePaid: …)` and is disabled until the catalog resolves. Paid tiers also advertise vocabulary flashcard download (Anki CSV, gated by `isPaidTier`) and more features coming.
- Auto-renew plan catalog from `GET /api/v1/subscriptions/plans` (monthly / yearly when configured).
- Cancel auto-renew via `POST /api/v1/subscriptions/cancel` when the billing subscription is cancelable (works on mobile too — no external checkout).
- Credits packages section (`$2` / `$5` / `$50` permanent credits) from Rails `/api/v1/credits/packages`; standing from Worker `GET /credits/summary`.
- Pull-to-refresh on the subscription screen; automatic tier reconciliation on app resume and cold start (see [ADR-0041](../decisions/0041-unified-tier-reconciliation.md)).

### Tier source of truth

All tier indicators (sidebar chip, profile hero card, subscription screen, membership card) read the single synchronous `currentTierProvider`, which prefers live `subscriptionStatusProvider` and falls back to the cached `UserProfile.subscriptionTier` while the live status is loading on cold start. Never read `UserProfile.subscriptionTier` directly in UI — it is a cache, not the source of truth. The rich membership card (`SubscriptionStatusCard`) renders for any paid tier (Lite or Pro) — title and Pro / Lite badge are tier-aware, and the `isPaid` predicate is `status.isPaidTier` (true for either Lite or Pro).

### Feature gating (paid-tier semantics)

The legacy `isPro` / `SubscriptionTier.pro` checks were unified into `isPaidTier` / `tier != free` so Lite members unlock the same features as Pro. Feature gating is gone from the client; the daily credit pool is the only thing that differs by tier. Notable call sites:

- `ProfileHeroCard` Upgrade CTA appears only for Free; the `SubscriptionChip` shows Pro / Lite / Free.
- `SidebarAccountChip` shows a paid badge for any paid tier and the Upgrade CTA for free.
- `VocabularyAnkiExport` (Pro Anki CSV) requires `isPaid`; throws `StateError('paid_required')` for free users, which the dialog surfaces as a friendly upgrade message.
- `ProfileContent` derives the daily credit limit from the live `SubscriptionStatus` rather than `UserProfile.subscriptionTier`.
- `PurchaseRequest` carries the chosen `tier`; `api.purchase` sends it in the body, and `prepaidUnitPriceForTier(tier, plans)` looks up the matching monthly plan from the catalog (replaces the hard-coded `kSubscriptionMonthlyPriceUsd`).
- `purchase_sheet.dart` is deprecated; new UI goes through `showUnifiedPurchaseSheet` with the tier from the catalog.

Legacy `purchase_sheet.dart` remains in the codebase but is no longer the entry point — new flows should call the catalog-driven unified sheet.

### Reconciliation & celebration

- `TierReconcileHost` (mounted in `RootShell`) is a global `WidgetsBindingObserver`. On `AppLifecycleState.resumed` and on (re)sign-in it runs `TierReconcileCtrl.reconcile()`, which refreshes **both** the live status and the cached profile.
- When a genuine `free → any paid tier` transition is detected (Lite or Pro), a tier-aware `AppNotice.success` snackbar is shown: `"You're now Lite — enjoy!"` (`subscriptionUpgradedToLite`) or `"You're now Pro — enjoy!"` (`subscriptionUpgradedToPro`). Free members upgrading from Free to Lite get the Lite toast; Pro upgrades still get the Pro toast. The poll uses `status.isPaidTier` (true for either Lite or Pro) rather than `== SubscriptionTier.pro`.
- App-initiated paid-tier checkout: `markPurchasePending()` → eager resume poll until the user lands on any paid tier (Lite or Pro) via `_pollPaidOnce` / `_pollUntilPaidOrTimeout`.
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
