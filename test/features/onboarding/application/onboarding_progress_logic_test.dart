import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';

void main() {
  test('global JSON round-trip skips pending', () {
    final encoded = TipProgressSnapshot.encodeGlobalJson({
      OnboardingTipId.homeImport.id: TipStatus.completed,
      OnboardingTipId.homeCraft.id: TipStatus.pending,
    });
    final decoded = TipProgressSnapshot.decodeGlobalJson(encoded);
    expect(decoded[OnboardingTipId.homeImport.id], TipStatus.completed);
    expect(decoded.containsKey(OnboardingTipId.homeCraft.id), isFalse);
  });

  test('per-media status is independent in snapshot maps', () {
    const snap = TipProgressSnapshot(
      emptyTranscriptByMediaId: {
        'a': TipStatus.skipped,
        'b': TipStatus.pending,
      },
    );
    expect(snap.statusOfEmptyTranscript('a'), TipStatus.skipped);
    expect(snap.statusOfEmptyTranscript('b'), TipStatus.pending);
    expect(snap.statusOfEmptyTranscript('c'), TipStatus.pending);
  });
}
