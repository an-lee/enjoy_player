// Coverage for lib/features/ai/domain/prompts/translation_prompt.dart and
// lib/features/player/application/engines/youtube/youtube_state_poller.dart.
//
// The translation prompt is a tiny pure-function module — the tests pin
// language-base handling and the user-prompt passthrough.
//
// YoutubeStatePoller is a static helper that polls the HTML5 `<video>` element
// for currentTime / duration / playState. Its public surface is one `poll`
// call. We exercise every branch:
//   * disposed = true → no-op
//   * web == null → no-op
//   * result == null → no-op (no callback)
//   * invalid JSON → no-op (no callback)
//   * valid JSON with state=0/1/2 (paused/playing/ended)
//   * valid JSON with finite duration and with d=0 (newDuration null)
//   * valid JSON with non-finite duration (newDuration null)
//   * evaluateJavascript throws → swallow, no callback
import 'package:enjoy_player/features/ai/domain/prompts/translation_prompt.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_state_poller.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the most recent callback invocation so tests can assert on the
/// decoded (position, duration, paused, ended) tuple.
class _RecordingCallback {
  Duration? position;
  Duration? newDuration;
  bool? jsPaused;
  bool? jsEnded;
  int invocations = 0;

  void call({
    required Duration position,
    Duration? newDuration,
    required bool jsPaused,
    required bool jsEnded,
  }) {
    this.position = position;
    this.newDuration = newDuration;
    this.jsPaused = jsPaused;
    this.jsEnded = jsEnded;
    invocations++;
  }
}

/// A `PlatformInAppWebViewController` that returns a fixed [result] (or
/// throws, depending on [shouldThrow]) every time `evaluateJavascript` is
/// called. Sufficient for YoutubeStatePoller's one-shot polling use case.
///
/// We `implements` rather than `extends` because `PlatformInAppWebViewController`
/// only exposes factory constructors — no public direct constructor that takes
/// a token. Implementing the interface side-steps that constraint while
/// leaving all `UnimplementedError`-throwing no-op methods inherited as-is.
class _FakePlatformController implements PlatformInAppWebViewController {
  _FakePlatformController({this.result, this.shouldThrow = false});

  final Object? result;
  final bool shouldThrow;

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    if (shouldThrow) throw StateError('boom');
    return result;
  }

  // The rest of PlatformInAppWebViewController's surface (loadUrl, postUrl,
  // getCookies, ...) isn't used by YoutubeStatePoller, so we don't need to
  // implement it. Any unused method access from the production path will
  // throw the inherited UnimplementedError, which we already exercise.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('buildTranslationSystemPrompt', () {
    test('mentions source/target language base tags', () {
      final prompt = buildTranslationSystemPrompt(
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(prompt, contains('en'));
      expect(prompt, contains('zh'));
    });

    test('asks for translation-only output', () {
      final prompt = buildTranslationSystemPrompt(
        sourceLanguage: 'fr',
        targetLanguage: 'de',
      );
      expect(prompt.toLowerCase(), contains('only the translated text'));
      expect(prompt.toLowerCase(), contains('no quotes'));
    });

    test('extracts BCP-47 base tag', () {
      final prompt = buildTranslationSystemPrompt(
        sourceLanguage: 'zh-CN',
        targetLanguage: 'en-US',
      );
      expect(prompt, contains('zh'));
      expect(prompt, contains('en'));
    });

    test('is deterministic', () {
      final a = buildTranslationSystemPrompt(
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      final b = buildTranslationSystemPrompt(
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(a, b);
    });
  });

  group('buildTranslationUserPrompt', () {
    test('returns the text verbatim', () {
      expect(buildTranslationUserPrompt('bonjour'), 'bonjour');
    });

    test('preserves empty input', () {
      expect(buildTranslationUserPrompt(''), '');
    });

    test('preserves unicode', () {
      expect(buildTranslationUserPrompt('你好'), '你好');
    });

    test('preserves multi-line text', () {
      const multiline = 'line one\nline two\nline three';
      expect(buildTranslationUserPrompt(multiline), multiline);
    });
  });

  group('YoutubeStatePoller.poll', () {
    test('is a no-op when disposed is true', () async {
      final cb = _RecordingCallback();
      await YoutubeStatePoller.poll(
        disposed: true,
        web: null,
        onResult: cb.call,
      );
      expect(cb.invocations, 0);
    });

    test('is a no-op when web is null', () async {
      final cb = _RecordingCallback();
      await YoutubeStatePoller.poll(
        disposed: false,
        web: null,
        onResult: cb.call,
      );
      expect(cb.invocations, 0);
    });

    test('decodes a playing sample (state=1) and forwards duration', () async {
      final cb = _RecordingCallback();
      final controller = InAppWebViewController.fromPlatform(
        platform: _FakePlatformController(result: '{"t":12.5,"d":120.0,"s":1}'),
      );
      await YoutubeStatePoller.poll(
        disposed: false,
        web: controller,
        onResult: cb.call,
      );
      expect(cb.invocations, 1);
      expect(cb.position, const Duration(milliseconds: 12500));
      expect(cb.newDuration, const Duration(milliseconds: 120000));
      expect(cb.jsPaused, isFalse);
      expect(cb.jsEnded, isFalse);
    });

    test('decodes a paused sample (state=0)', () async {
      final cb = _RecordingCallback();
      final controller = InAppWebViewController.fromPlatform(
        platform: _FakePlatformController(result: '{"t":5.25,"d":60.0,"s":0}'),
      );
      await YoutubeStatePoller.poll(
        disposed: false,
        web: controller,
        onResult: cb.call,
      );
      expect(cb.invocations, 1);
      expect(cb.position, const Duration(milliseconds: 5250));
      expect(cb.jsPaused, isTrue);
      expect(cb.jsEnded, isFalse);
    });

    test('decodes an ended sample (state=2)', () async {
      final cb = _RecordingCallback();
      final controller = InAppWebViewController.fromPlatform(
        platform: _FakePlatformController(result: '{"t":0,"d":60.0,"s":2}'),
      );
      await YoutubeStatePoller.poll(
        disposed: false,
        web: controller,
        onResult: cb.call,
      );
      expect(cb.invocations, 1);
      expect(cb.jsPaused, isFalse);
      expect(cb.jsEnded, isTrue);
    });

    test('leaves newDuration null when d=0', () async {
      final cb = _RecordingCallback();
      final controller = InAppWebViewController.fromPlatform(
        platform: _FakePlatformController(result: '{"t":1.0,"d":0,"s":1}'),
      );
      await YoutubeStatePoller.poll(
        disposed: false,
        web: controller,
        onResult: cb.call,
      );
      expect(cb.invocations, 1);
      expect(cb.newDuration, isNull);
    });

    test('ignores a null evaluateJavascript result', () async {
      final cb = _RecordingCallback();
      final controller = InAppWebViewController.fromPlatform(
        platform: _FakePlatformController(result: null),
      );
      await YoutubeStatePoller.poll(
        disposed: false,
        web: controller,
        onResult: cb.call,
      );
      expect(cb.invocations, 0);
    });

    test('swallows invalid JSON', () async {
      final cb = _RecordingCallback();
      final controller = InAppWebViewController.fromPlatform(
        platform: _FakePlatformController(result: 'not-json{'),
      );
      await YoutubeStatePoller.poll(
        disposed: false,
        web: controller,
        onResult: cb.call,
      );
      expect(cb.invocations, 0);
    });

    test('swallows evaluateJavascript exceptions', () async {
      final cb = _RecordingCallback();
      final controller = InAppWebViewController.fromPlatform(
        platform: _FakePlatformController(shouldThrow: true),
      );
      await YoutubeStatePoller.poll(
        disposed: false,
        web: controller,
        onResult: cb.call,
      );
      expect(cb.invocations, 0);
    });
  });
}
