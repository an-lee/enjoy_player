/// Stable tip identities and sequences for product onboarding.
library;

/// Catalog tip id (persisted in global progress JSON).
enum OnboardingTipId {
  homeImport('home.import'),
  homeCraft('home.craft'),
  playerEmptyTranscriptLocal('player.empty_transcript.local'),
  playerEmptyTranscriptYoutube('player.empty_transcript.youtube'),
  playerEcho('player.echo'),
  playerRecord('player.record'),
  playerAssess('player.assess');

  const OnboardingTipId(this.id);
  final String id;

  static OnboardingTipId? tryParse(String raw) {
    for (final tip in OnboardingTipId.values) {
      if (tip.id == raw) return tip;
    }
    return null;
  }
}

/// Ordered tip groups.
enum OnboardingSequenceId { homeEntries, playerEmptyTranscript, playerPractice }

extension OnboardingTipIdX on OnboardingTipId {
  OnboardingSequenceId get sequenceId => switch (this) {
    OnboardingTipId.homeImport ||
    OnboardingTipId.homeCraft => OnboardingSequenceId.homeEntries,
    OnboardingTipId.playerEmptyTranscriptLocal ||
    OnboardingTipId.playerEmptyTranscriptYoutube =>
      OnboardingSequenceId.playerEmptyTranscript,
    OnboardingTipId.playerEcho ||
    OnboardingTipId.playerRecord ||
    OnboardingTipId.playerAssess => OnboardingSequenceId.playerPractice,
  };

  bool get isPerMedia => switch (this) {
    OnboardingTipId.playerEmptyTranscriptLocal ||
    OnboardingTipId.playerEmptyTranscriptYoutube => true,
    _ => false,
  };
}

/// Home showcase order: Import then Craft (catalog pedagogy).
const List<OnboardingTipId> kHomeEntriesOrder = [
  OnboardingTipId.homeImport,
  OnboardingTipId.homeCraft,
];

/// Practice showcase order.
const List<OnboardingTipId> kPracticeOrder = [
  OnboardingTipId.playerEcho,
  OnboardingTipId.playerRecord,
  OnboardingTipId.playerAssess,
];
