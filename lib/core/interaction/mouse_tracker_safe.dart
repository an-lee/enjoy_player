/// Helpers to avoid re-entering Flutter's [MouseTracker] device-update phase.
library;

import 'package:flutter/widgets.dart';

/// Runs [action] after the current frame so it cannot re-enter
/// `MouseTracker._deviceUpdatePhase`.
///
/// Calling [State.setState] or notifying a [ValueNotifier] from
/// [MouseRegion.onEnter] / [onExit] can rebuild annotations while the
/// tracker is still updating. On desktop that trips the debug assertion
/// `!_debugDuringDeviceUpdate` and floods logs (often when a platform view
/// such as WebView2 is parked/moved under the cursor).
void runOutsideMouseTracker(VoidCallback action) {
  final binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((_) => action());
  // Hover-only updates may not otherwise schedule a frame.
  binding.scheduleFrame();
}

/// Like [runOutsideMouseTracker], but no-ops when [mounted] is false.
void runOutsideMouseTrackerIfMounted(
  bool Function() mounted,
  VoidCallback action,
) {
  runOutsideMouseTracker(() {
    if (!mounted()) return;
    action();
  });
}

/// Defers assigning [notifier]'s value (last write wins within the frame).
void setValueNotifierOutsideMouseTracker<T>(
  ValueNotifier<T> notifier,
  T value,
) {
  if (notifier.value == value) return;
  runOutsideMouseTracker(() {
    if (notifier.value == value) return;
    notifier.value = value;
  });
}
