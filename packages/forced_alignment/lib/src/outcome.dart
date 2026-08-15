import 'failures.dart';
import 'types.dart';

/// Public return of [align] / [alignSegments].
sealed class AlignmentOutcome {
  const AlignmentOutcome();
}

final class AlignmentSuccess extends AlignmentOutcome {
  const AlignmentSuccess(this.result);

  final AlignmentResult result;
}

final class AlignmentFailed extends AlignmentOutcome {
  const AlignmentFailed(this.failure);

  final AlignmentFailure failure;
}
