# Feature Specification: Friendly AI Credits-Exhausted Errors

**Feature Branch**: `045-ai-credits-error-ux`

**Created**: 2026-08-30

**Status**: Draft

**Input**: User description: "When the AI service requesting fail with error 402, the error notifications should be user friendly. Only 402 error is super confusing. User should know how to resolve it. It's because the credits insufficient, we should have a CTA, guide user to subscribe plan or buy credits package. Help me to design this error system, make it user friendly."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Understandable error on every AI feature (Priority: P1)

Ana is generating a transcript for a long podcast. Mid-session, the AI service rejects the request because her Enjoy credits are used up. Today she sees a bare "HTTP 402" (or a raw server string) and has no idea what went wrong, whether it is her network, or what to do next. With this feature, every AI capability in the app — transcript generation, translation (standard and contextual), dictionary lookup, pronunciation/TTS, AI craft/chat, and AI assessment — replaces that raw error with one consistent, plain-language message: the action could not complete because AI credits are insufficient. The message never shows status codes, server payloads, or developer-facing text.

**Why this priority**: This is the core of the feature. Removing the confusing raw error is the minimum that makes every other improvement meaningful; it is deliverable and testable on its own and already reduces user confusion.

**Independent Test**: Force an AI request to fail with a credits-exhausted rejection on each AI surface and verify the user sees the friendly localized message and no raw code/payload anywhere. Delivering only this story already removes the "super confusing 402" experience.

**Acceptance Scenarios**:

1. **Given** Ana has zero remaining AI credits, **When** she triggers transcript generation, **Then** the error surface shows a plain-language "credits insufficient" message with no HTTP status code or server payload visible.
2. **Given** the same condition, **When** she triggers dictionary lookup, translation, pronunciation, craft generation, or assessment, **Then** the same consistent message pattern appears on each surface.
3. **Given** the AI request fails for a different reason (network offline, server error, rate limit), **When** the failure is shown, **Then** the credits message is NOT shown and the existing behavior for those failures is unchanged.
4. **Given** the app language is set to a non-English locale, **When** the credits error appears, **Then** the message and CTA are fully translated in that locale.

---

### User Story 2 - One-tap path to resolve: subscribe or buy credits (Priority: P2)

Ana reads the friendly message and wants to continue immediately. The error presentation includes a clear call-to-action — for example "View plans & packages" — that takes her in one tap to the existing subscription screen where she can subscribe to a plan or purchase a credits package. The CTA uses the same label and destination on every AI surface, so she learns the recovery path once.

**Why this priority**: Understanding the cause is only half the fix; the CTA converts a dead end into a recovery flow. It depends on Story 1's message but is independently testable as a navigation/CTA behavior.

**Independent Test**: Trigger a credits-exhausted error on any AI surface, tap the CTA, and verify the user lands on the subscription/purchase screen; verify the CTA appears on every AI surface that can show the credits error.

**Acceptance Scenarios**:

1. **Given** a credits-exhausted error is visible, **When** Ana taps the CTA, **Then** she is taken directly to the screen where she can view plans and buy credits packages.
2. **Given** the error appears on different AI surfaces (transcript, lookup, craft), **When** she taps the CTA from each, **Then** each lands on the same purchase destination.
3. **Given** the credits error fires repeatedly (Ana retries without purchasing), **When** she dismisses and retries, **Then** she is not shown duplicated or stacked error notifications for a single failure.

---

### User Story 3 - Painless resume after resolving (Priority: P3)

Ana subscribes or buys a credits package from the screen the CTA opened. When she returns to what she was doing, her in-progress work is intact — the half-finished transcript job, the word she looked up, the craft draft she was generating — and she can retry the failed action without re-entering or re-selecting anything, and without restarting the app.

**Why this priority**: The recovery loop is not complete until the user finishes the original task; preserving context and offering retry turns a purchase into a completed action. It depends on Stories 1–2 but is independently verifiable per surface.

**Independent Test**: Trigger the credits error mid-task, complete a (simulated) purchase, return to the surface, and verify prior state is preserved and the failed action can be retried successfully.

**Acceptance Scenarios**:

1. **Given** Ana's transcript generation failed with the credits error, **When** she purchases credits and returns to the player, **Then** the media item and her place are unchanged and she can restart generation in one action.
2. **Given** a lookup or craft attempt failed with the credits error, **When** she returns after purchasing, **Then** her previous input/selection is still present and retry needs no re-entry.

---

### Edge Cases

- **402 with a different cause**: The server may reject with 402 for billing blocks other than "credits exhausted" (e.g. expired plan hold). The message must stay truthful for the general case ("billing/credits issue — view plans") rather than over-promising a specific cause, and must never mislead.
- **Purchase doesn't cover the action**: Ana buys the smallest package, retries, and still lacks credits. The friendly error must reappear cleanly (no crash, no duplicate stacking) and the CTA still works.
- **Purchase pending/unconfirmed**: She taps the CTA, completes payment, but entitlement has not landed yet when she returns. Retrying shows a normal in-progress/pending state, not a confusing hard failure.
- **BYOK users**: Users who bring their own AI key (spec 003-byok-ai) can also hit a 402 — from *their* provider's billing. Showing "upgrade your Enjoy plan" would be wrong; these users get a provider-billing message without the Enjoy subscription CTA.
- **Signed-out session expiry**: The 402 arrives while the session has also expired. Auth/session errors take precedence over the credits interpretation so the user is re-authenticated rather than sent shopping.
- **Bulk/background operations**: A multi-item operation (e.g. batch translation) hits credits exhaustion partway through. The error surfaces once with the friendly treatment — not once per item — and completed work is kept.
- **Server error body is empty or garbled**: Classification must not depend on parsing free-form message text; it must work from the status alone so presentation never degrades to raw text. (Confirmed server behavior: the 402 rejection carries a structured payload — error kind, required credits, used/limit, reset time — which the client should consume best-effort.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST classify AI-request failures rejected for insufficient credits/billing (HTTP 402) into a distinct error category, separated from network, authentication, rate-limit, and server errors. Classification MUST prefer the service's structured rejection payload (error kind, credits required, credits used, daily limit, reset time) when present, with the HTTP status alone as the fallback trigger, and MUST NOT depend on parsing free-form message text.
- **FR-002**: When an AI request fails with that category, the system MUST present a plain-language, localized message that names the cause ("AI credits insufficient") and offers the recovery action; when the rejection includes credit numbers (required vs. remaining vs. reset time), the message SHOULD surface them so the user can see exactly what is missing; it MUST NOT display HTTP status codes, raw server payloads, or developer-facing strings.
- **FR-003**: The error presentation MUST include a call-to-action that takes the user in one tap to the existing screen where they can subscribe to a plan or purchase a credits package.
- **FR-004**: All AI capability surfaces in the app — transcript generation, standard translation, contextual translation, dictionary lookup, pronunciation/TTS, craft/AI chat, and AI assessment — MUST apply the same credits-error message and CTA pattern consistently.
- **FR-005**: The classification and presentation MUST NOT alter the behavior of any other failure type; network, authentication, rate-limit, and server errors keep their existing messages and flows.
- **FR-006**: A single failed action MUST produce at most one user-visible credits error (no duplicated or stacked notifications for one failure), including repeated retries before purchase.
- **FR-007**: After the user resolves the shortage (subscribes or buys credits), the originating surface MUST preserve the user's prior in-progress state and allow retrying the failed action without re-entering input and without restarting the app.
- **FR-008**: Failures of AI requests made with a user-supplied AI key (BYOK) MUST NOT show the Enjoy subscription CTA; they MUST show a truthful provider-billing message instead.
- **FR-009**: All user-visible strings added by this feature MUST be localized through the app's standard localization files, shipped in every supported locale.
- **FR-010**: Errors originating from credits-package purchase or subscription management endpoints that return 402 MUST surface with the same friendly treatment when shown to users (no raw codes).

### Key Entities *(include if feature involves data)*

- **Credits-exhausted error (presentation model)**: A user-facing error carrying (a) a plain-language cause message, (b) a recovery action (label + destination), and (c) an indicator of whether the Enjoy-subscription recovery path applies (it does not for BYOK failures). Derived from the raw failure at the boundary where AI/worker responses are translated to app failures; not persisted.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of AI capability surfaces audited show the friendly localized credits message and CTA when a 402 is forced — zero surfaces display raw status codes or server payloads for this failure.
- **SC-002**: A user can go from seeing the error to the plans/packages purchase screen in exactly 1 tap, from every AI surface.
- **SC-003**: A user who purchases after hitting the error can complete their originally-intended action within 1 minute of returning to the app, without re-entering prior input.
- **SC-004**: Non-credits failures (network, auth, rate limit, 5xx) exhibit behavior identical to before this feature, verified per existing tests/screens.
- **SC-005**: Reports/confusion about unexplained "402" errors from users fall to zero — no support feedback referencing a bare 402 without a described cause — after release.

## Assumptions

- The existing subscription screen (plans + credits packages) is the single recovery destination; no new purchase flow is built in this feature.
- Enjoy-hosted AI credits are the default AI backend; BYOK is the exception handled by FR-008 (informed default — confirm if BYOK 402s should instead show Enjoy upsell).
- The service's 402 rejection carries a structured payload (confirmed 2026-08-30 by reading the worker: error kind `credits_exhausted`, `required` credits, `limit.used` / `limit.limit` / `limit.resetAt`); the client consumes it best-effort and falls back to the generic message when absent.
- Scope is client-side presentation and error routing only; no server-side changes to billing or error payloads.
- Users are already signed in when hitting AI limits (signed-out flows are out of scope beyond the session-expiry precedence edge case).
- The friendly treatment covers interactive surfaces first; background/scheduled AI jobs adopt the same message where they surface errors to users.
