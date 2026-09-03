# Feature Specification: PostHog Product Analytics Integration

**Feature Branch**: `046-posthog-analytics-integration`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "Help me to integrate the posthog into this project, follow the official docs: https://posthog.com/docs/libraries/flutter"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - App usage is measured from first launch (Priority: P1)

Ana installs Enjoy Player and opens it. Without her doing anything special, her app session — the open itself and subsequent foreground/background sessions — is recorded in the team's PostHog dashboard. The team can finally see how many people actually use the app, on which platforms, and how often, without asking anyone or shipping a survey.

**Why this priority**: This is the foundation. Initialization plus automatic session/lifecycle capture delivers standalone value (real usage numbers) and every other story builds on it. It requires no changes to any feature surface.

**Independent Test**: Install on a supported platform, open the app, and observe the session event appear in the analytics dashboard. Delivering only this story already answers "is anyone using the app?"

**Acceptance Scenarios**:

1. **Given** a fresh install on a supported platform, **When** Ana opens the app for the first time, **Then** an app-open/session event appears in the analytics dashboard within a few minutes of launch.
2. **Given** the app is running, **When** Ana backgrounds it and returns later, **Then** the return is recorded as a new session rather than silently merged.
3. **Given** a fresh install on Windows or Linux, **When** the app is used normally, **Then** the app behaves exactly as before — nothing is sent, and there are no errors, log noise, or slowdowns.

---

### User Story 2 - Usage is attributed to the signed-in account (Priority: P2)

Enjoy Player is login-only: every user has an Enjoy account. After Ana signs in, her usage is attributed to her stable account identity, so her phone, tablet, and desktop all count as one person and her history survives reinstalls. On a shared device, signing out and signing in as someone else switches attribution cleanly — the previous user is never credited with the next user's activity.

**Why this priority**: Login-only access makes identity nearly free and dramatically increases the value of the data (retention per person, cross-device behavior). It is the highest-value refinement of the P1 stream but depends on initialization existing first.

**Independent Test**: Sign in as a known account on a new device (or after reinstall), use the app, and verify the dashboard shows the events under the same person as that account's earlier activity; then sign out, sign in as a different account, and verify attribution switches.

**Acceptance Scenarios**:

1. **Given** Ana signs in on a second device, **When** she uses the app, **Then** events attribute to her existing identity — one person across both devices, not a new stranger.
2. **Given** Ana reinstalls the app and signs in again, **When** she uses it, **Then** her history continues under the same person instead of starting a new one.
3. **Given** a shared device where one user signs out and another signs in, **When** the second user uses the app, **Then** events from that point attribute only to the new account.

---

### User Story 3 - Core product journeys are measurable (Priority: P2)

The team wants more than raw session counts: which features do people actually use, where do they drop off, what do paid users do differently? A documented, consistently named catalog of events covers the app's core journeys — starting and completing practice, generating a transcript, translating and looking up words, creating and refining a craft project, completing a vocabulary review, and purchasing a subscription or credits package — each with its outcome (completed, failed, and failure reason category where applicable). With the catalog in place, funnels, adoption, and retention views can be built in the dashboard with no further app changes.

**Why this priority**: This is where analytics turns into product decisions. It builds directly on the P1 stream but touches feature surfaces, so it lands after the foundation is proven.

**Independent Test**: Walk each documented journey in the app and verify exactly one well-named event with outcome metadata arrives per occurrence, with no duplicate or missing events.

**Acceptance Scenarios**:

1. **Given** Ana completes a practice session, **When** the session ends, **Then** a single event records the journey and its outcome.
2. **Given** an AI-backed journey fails (for example, credits exhausted), **When** the failure is surfaced to her, **Then** the event records the outcome and a coarse reason category — never raw server payloads or message content.
3. **Given** the documented catalog, **When** the team builds a funnel or feature-adoption view in the dashboard, **Then** every listed journey is measurable without adding new instrumentation.

---

### User Story 4 - Users can turn analytics off (Priority: P2)

Ana cares about privacy. A clearly labeled control in Settings lets her turn usage capture off. From the moment she does, nothing further is collected or sent — including anything still queued — and the choice survives restarts. She can turn it back on at any time. This keeps the default experience measurable while giving every user a visible, respected off switch.

**Why this priority**: A personal media-learning library is sensitive territory; shipping capture without a user-facing off switch is a trust and distribution risk. It is independent of the instrumentation stories and can land any time after the P1 foundation.

**Independent Test**: Toggle the setting off, use the app across sessions, and verify the dashboard receives zero events from that device; toggle back on and verify capture resumes.

**Acceptance Scenarios**:

1. **Given** capture is on, **When** Ana turns the toggle off, **Then** no further events are collected or sent from that moment, including events captured earlier but not yet delivered.
2. **Given** the toggle is off, **When** she restarts the app and uses it, **Then** nothing is sent and the toggle still shows off.
3. **Given** the toggle is off, **When** she turns it back on, **Then** capture resumes within the same session without restarting the app.

---

### User Story 5 - Releases can be gated by remote flags (Priority: P3)

The team wants to roll future features out gradually — to a percentage of users, or per platform — and to switch behavior without shipping a new build. The app can evaluate remotely defined feature flags at startup and on demand, and every flag read has a built-in safe default for when the service is unreachable or the platform doesn't support the integration. No existing behavior is gated behind a flag in this change; this story delivers the capability so the next feature can use it.

**Why this priority**: Valuable, but the app ships fine without remote gating today. It is a capability enablement story, deliberately last and explicitly not wired into any existing surface.

**Independent Test**: Define a flag remotely, read it from the app (a debug-only readout is acceptable), change its value remotely, and verify the app sees the new value after a refresh without an app update.

**Acceptance Scenarios**:

1. **Given** a flag defined remotely, **When** the app starts, **Then** the app can read the flag's value for the current user without an app update.
2. **Given** the analytics service is unreachable at startup, **When** the app reads a flag, **Then** the built-in default is used instantly and nothing blocks or retries visibly.
3. **Given** a flag-controlled behavior, **When** the app runs on Windows or Linux, **Then** the built-in default applies with no errors.

---

### Edge Cases

- **Unsupported platforms**: The analytics vendor's SDK offers native support for Android, iOS, and macOS only; the app also ships Windows and Linux (first-class per ADR-0048). On those platforms the whole integration must be inert — no capture, no errors, no crash, no measurable startup or memory cost.
- **Offline or blocked network**: Events captured while offline must be delivered when connectivity returns, via a bounded queue that cannot grow unbounded or block app features; a permanently unreachable service must remain invisible to the user.
- **Opt-out with queued events**: Turning capture off must also discard not-yet-delivered events, not just stop new collection, so an opting-out user's pending data doesn't arrive afterward.
- **Identity switching**: Sign-out (or account switch) must reset attribution before the next user's first event; on a fresh sign-in the previous person must never receive the new session's events.
- **Development builds**: Debug/development builds must not pollute production analytics data — capture must be isolated or disabled by default outside release builds.
- **Startup cost**: Initialization must stay off the app's critical path; a slow analytics endpoint must never delay the first meaningful frame.
- **Payload privacy**: Event properties must never contain user-generated content — media, transcripts, subtitles, notes, craft drafts, prompts, or lookups — only coarse metadata (surface, outcome, counts, durations).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST initialize product analytics at app startup on every supported platform (Android, iOS, macOS) so usage is recorded from the very first launch.
- **FR-002**: The system MUST automatically record app-open/session and lifecycle (foreground/background) events without requiring per-surface code.
- **FR-003**: The system MUST capture a documented, consistently named catalog of events for the core product journeys — practice, transcript generation, translation and dictionary lookup, craft creation and refinement, vocabulary review, and subscription/credits purchase — including outcome (completed/failed) and coarse failure-reason categories. Every event MUST carry common context (app version, platform, locale).
- **FR-004**: Event payloads MUST NOT contain user-generated content (media, transcript or subtitle text, notes, prompts, lookups, account email as event content); properties are limited to coarse metadata.
- **FR-005**: After sign-in, events MUST be attributed to a stable account identifier that is the same across devices and reinstalls; the raw email address MUST NOT be used as the identity key.
- **FR-006**: On sign-out or account switch, the system MUST reset attribution so subsequent events are not credited to the previous account.
- **FR-007**: The system MUST provide an in-app opt-out control in Settings that stops all capture immediately, discards not-yet-delivered events, persists across restarts, and resumes capture when re-enabled; the control defaults to ON; its user-visible strings MUST be localized in all supported locales.
- **FR-008**: On platforms without vendor support (Windows, Linux) the integration MUST be completely inert: no events, no errors, no crash, no measurable behavior or performance difference versus not having the integration.
- **FR-009**: All analytics activity MUST be non-blocking and failure-tolerant: analytics calls must never block, delay, or break any user-facing feature; undeliverable events are queued (bounded) and delivered when connectivity returns.
- **FR-010**: Development/debug builds MUST NOT report into production analytics data; the analytics destination MUST be configurable per build environment without code changes.
- **FR-011**: The system MUST be able to evaluate remotely defined feature flags at startup and on demand, always falling back to built-in defaults when the service is unreachable, the user is opted out of a flag's requirements, or the platform doesn't support the integration; no existing behavior MAY be placed behind a flag by this feature.

### Key Entities *(include if feature involves data)*

- **Usage event**: A named occurrence of a user action or app lifecycle moment, carrying an event name, timestamp, identity, and metadata properties only (no user-generated content). Held transiently in a delivery queue; not stored as part of the app's user data.
- **Person identity**: Either the signed-in account's stable identifier or an anonymous per-install identity before sign-in; links events into one person across devices and reinstalls.
- **Capture preference**: Per-device enabled/disabled choice persisted locally; gates all capture and delivery.
- **Event catalog**: The documented, versioned list of event names and their properties, maintained in the feature documentation so dashboard builders and future contributors use consistent names.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first launch on a supported platform produces a visible event in the analytics dashboard within 2 minutes of app open, on all three supported platforms.
- **SC-002**: 100% of the documented event catalog fires exactly once per occurrence when the corresponding journey is exercised, verified on at least one mobile and one desktop-supported platform, with zero events containing user-generated content.
- **SC-003**: Zero user-visible failures, crashes, or startup delay are attributable to analytics in a standard session (startup time within normal run-to-run variance), and a simulated analytics outage produces zero user-facing impact.
- **SC-004**: After opting out, zero events from that device reach the dashboard across multiple sessions; the preference survives restart; re-enabling resumes capture in the same session.
- **SC-005**: On Windows and Linux, manual exercise of core flows shows behavior and performance identical with and without the integration (no new errors, no measurable startup or memory difference).
- **SC-006**: The team can answer "how many weekly active users, split by platform, and which features are used most" entirely from the analytics dashboard with no additional engineering.

## Assumptions

- **PostHog cloud is the destination**, configured per the official Flutter integration docs; the project owner supplies the project API key. Self-hosting is not required for v1.
- **Capture defaults to ON with a visible opt-out** (FR-007) rather than requiring opt-in consent first — the industry-standard default for product analytics in a login-only app; revisit if a distribution channel requires explicit consent.
- **Platform split follows vendor support**: Android, iOS, and macOS capture; Windows and Linux are inert (the vendor's Flutter SDK lists only iOS, macOS, Android, and Web). Web is out of scope entirely — the app does not target it.
- **Session replay, surveys, push notifications, and server-side capture are out of scope for v1**; they are separate vendor capabilities with their own setup and can be layered on later.
- **No existing feature is gated behind a flag** in this change; flag evaluation is delivered as capability only (FR-011).
- Dashboard/insight setup inside PostHog is the team's responsibility, not part of the app change; the app ships the events and the documented catalog.
