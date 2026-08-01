import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/interaction/mouse_tracker_safe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'setValueNotifierOutsideMouseTracker applies on the next frame',
    (tester) async {
      final hover = ValueNotifier<bool>(false);
      addTearDown(hover.dispose);

      setValueNotifierOutsideMouseTracker(hover, true);
      expect(hover.value, isFalse);

      await tester.pump();
      expect(hover.value, isTrue);

      setValueNotifierOutsideMouseTracker(hover, false);
      expect(hover.value, isTrue);

      await tester.pump();
      expect(hover.value, isFalse);
    },
  );

  testWidgets(
    'runOutsideMouseTrackerIfMounted skips when not mounted',
    (tester) async {
      var ran = false;
      var mounted = true;

      runOutsideMouseTrackerIfMounted(() => mounted, () => ran = true);
      mounted = false;
      await tester.pump();
      expect(ran, isFalse);

      mounted = true;
      runOutsideMouseTrackerIfMounted(() => mounted, () => ran = true);
      await tester.pump();
      expect(ran, isTrue);
    },
  );
}
