// Auth sync (spec 046 US2): events attribute to UserProfile.id (never the
// email), re-identify is deduped, and sign-out resets attribution.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/analytics/analytics.dart';
import 'package:enjoy_player/core/analytics/analytics_bootstrap.dart';
import 'package:enjoy_player/core/analytics/analytics_provider.dart';
import 'package:enjoy_player/core/analytics/analytics_events.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';

/// Records facade calls instead of talking to a vendor.
final class _RecordingAnalytics implements Analytics {
  final List<String> captures = [];
  final List<String> identifies = [];
  final List<String> screens = [];
  int resets = 0;

  @override
  void capture(String name, {Map<String, Object>? properties}) =>
      captures.add(name);

  @override
  void screen(String name) => screens.add(name);

  @override
  void identify(String userId, {Map<String, Object>? userProperties}) =>
      identifies.add(userId);

  @override
  void reset() => resets++;

  @override
  void setEnabled(bool enabled) {}

  @override
  Future<T> flag<T extends Object>({
    required String key,
    required T fallback,
  }) async => fallback;

  @override
  Future<void> flush() async {}
}

final class _FakeAuthCtrl extends AuthCtrl {
  _FakeAuthCtrl(this._initial);

  AuthState _initial;

  @override
  Future<AuthState> build() async => _initial;

  void emitState(AuthState state) {
    _initial = state;
    this.state = AsyncValue.data(state);
  }
}

UserProfile _profile(String id) =>
    const UserProfile(id: 'u-1', email: 'ana@example.com', name: 'Ana');

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'sign-in identifies by account id with metadata-only properties',
    () async {
      final recording = _RecordingAnalytics();
      final container = ProviderContainer(
        overrides: [
          analyticsProvider.overrideWithValue(recording),
          authCtrlProvider.overrideWith(
            () => _FakeAuthCtrl(AuthSignedIn(profile: _profile('u-1'))),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(analyticsAuthSyncProvider);
      await container.read(authCtrlProvider.future);
      await _settle();

      expect(recording.identifies, ['u-1']);
      // The email must never be the identity key (spec FR-005).
      expect(recording.identifies, isNot(contains('ana@example.com')));
    },
  );

  test('sign-out resets attribution; next sign-in identifies afresh', () async {
    final recording = _RecordingAnalytics();
    final auth = _FakeAuthCtrl(AuthSignedIn(profile: _profile('u-1')));
    final container = ProviderContainer(
      overrides: [
        analyticsProvider.overrideWithValue(recording),
        authCtrlProvider.overrideWith(() => auth),
      ],
    );
    addTearDown(container.dispose);

    container.read(analyticsAuthSyncProvider);
    await container.read(authCtrlProvider.future);
    await _settle();
    expect(recording.identifies, ['u-1']);

    auth.emitState(const AuthSignedOut());
    await _settle();
    expect(recording.resets, 1);

    // A different user signs in on the shared device: attribution switches.
    auth.emitState(
      const AuthSignedIn(
        profile: UserProfile(
          id: 'u-2',
          email: 'other@example.com',
          name: 'Other',
        ),
      ),
    );
    await _settle();
    expect(recording.identifies, ['u-1', 'u-2']);
    expect(recording.resets, 1);
  });

  test('journey captures route through the same facade', () async {
    final recording = _RecordingAnalytics();
    final container = ProviderContainer(
      overrides: [
        analyticsProvider.overrideWithValue(recording),
        authCtrlProvider.overrideWith(
          () => _FakeAuthCtrl(AuthSignedIn(profile: _profile('u-1'))),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(analyticsProvider)
        .capture(
          AnalyticsEvents.transcriptGenerationRequested,
          properties: AnalyticsEvents.transcriptRequested(
            source: AnalyticsEvents.sourceAsr,
          ),
        );
    expect(recording.captures, [AnalyticsEvents.transcriptGenerationRequested]);
  });
}
