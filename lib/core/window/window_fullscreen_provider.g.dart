// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_fullscreen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks and controls the OS fullscreen state of the application window.
///
/// Listens to [WindowListener] callbacks so that the UI stays in sync even
/// when the user toggles fullscreen via OS mechanisms (e.g. F11 at OS level,
/// title-bar buttons on macOS, Windows keyboard shortcuts).

@ProviderFor(WindowFullscreen)
final windowFullscreenProvider = WindowFullscreenProvider._();

/// Tracks and controls the OS fullscreen state of the application window.
///
/// Listens to [WindowListener] callbacks so that the UI stays in sync even
/// when the user toggles fullscreen via OS mechanisms (e.g. F11 at OS level,
/// title-bar buttons on macOS, Windows keyboard shortcuts).
final class WindowFullscreenProvider
    extends $NotifierProvider<WindowFullscreen, bool> {
  /// Tracks and controls the OS fullscreen state of the application window.
  ///
  /// Listens to [WindowListener] callbacks so that the UI stays in sync even
  /// when the user toggles fullscreen via OS mechanisms (e.g. F11 at OS level,
  /// title-bar buttons on macOS, Windows keyboard shortcuts).
  WindowFullscreenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowFullscreenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowFullscreenHash();

  @$internal
  @override
  WindowFullscreen create() => WindowFullscreen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$windowFullscreenHash() => r'2bb74344d600a6d61e810331ddbaa976d75e94e7';

/// Tracks and controls the OS fullscreen state of the application window.
///
/// Listens to [WindowListener] callbacks so that the UI stays in sync even
/// when the user toggles fullscreen via OS mechanisms (e.g. F11 at OS level,
/// title-bar buttons on macOS, Windows keyboard shortcuts).

abstract class _$WindowFullscreen extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
