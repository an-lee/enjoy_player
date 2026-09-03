/// Compile-time product analytics configuration (specs/046-posthog-analytics-integration).
///
/// The PostHog project key and host arrive as `--dart-define` values so the
/// same binary is fully inert unless a token is explicitly provided:
/// `flutter test`, plain `flutter run`, and CI builds all resolve to the
/// no-op implementation without any configuration (research D2/D10). Debug
/// builds with defines have deliberately opted in — point them at a test
/// project, never the production one.
library;

/// PostHog project API key (compile-time). Empty ≡ analytics disabled.
const String kPostHogApiKey = String.fromEnvironment('POSTHOG_API_KEY');

/// PostHog ingestion host (compile-time), e.g. `https://eu.i.posthog.com`.
const String kPostHogHost = String.fromEnvironment('POSTHOG_HOST');

/// Whether analytics has everything it needs to run in this build.
bool get postHogConfigured =>
    kPostHogApiKey.isNotEmpty && kPostHogHost.isNotEmpty;
