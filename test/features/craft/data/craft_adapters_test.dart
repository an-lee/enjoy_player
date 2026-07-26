// Tests for `lib/features/craft/data/craft_asr_service_transcriber.dart` and
// `craft_tts_service_synthesizer.dart` — thin adapters that wrap the Riverpod
// `AsrService` / `TtsService` to the Craft domain ports so the controller
// stays testable without a live AI capability stack.
import 'dart:typed_data';

import 'package:enjoy_player/features/ai/application/ai_capability_providers.dart';
import 'package:enjoy_player/features/ai/application/ai_services.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/asr_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/tts_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_request.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_result.dart';
import 'package:enjoy_player/features/ai/domain/models/tts_request.dart';
import 'package:enjoy_player/features/ai/domain/models/tts_result.dart';
import 'package:enjoy_player/features/craft/data/craft_asr_service_transcriber.dart';
import 'package:enjoy_player/features/craft/data/craft_tts_service_synthesizer.dart';
import 'package:enjoy_player/features/craft/domain/craft_synthesizer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _wavBytes() => Uint8List.fromList(const <int>[82, 73, 70, 70]);

final class _RecordingAsrCapability implements AsrCapability {
  _RecordingAsrCapability(this.result);

  final AsrResult result;
  AsrRequest? lastRequest;

  @override
  Future<AsrResult> transcribe(AsrRequest request) async {
    lastRequest = request;
    return result;
  }
}

final class _RecordingTtsCapability implements TtsCapability {
  _RecordingTtsCapability(this.result);

  final TtsResult result;
  TtsRequest? lastRequest;

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    lastRequest = request;
    return result;
  }
}

void main() {
  group('CraftAsrServiceTranscriber', () {
    test(
      'forwards audio bytes to AsrService with a fixed wav filename',
      () async {
        final asrCap = _RecordingAsrCapability(const AsrResult(text: 'hola'));
        final container = ProviderContainer(
          overrides: [asrCapabilityProvider.overrideWithValue(asrCap)],
        );
        addTearDown(container.dispose);

        final asrService = container.read(asrServiceProvider);
        final transcriber = CraftAsrServiceTranscriber(asrService);

        final bytes = _wavBytes();
        final text = await transcriber.transcribe(
          audioBytes: bytes,
          language: 'es',
        );

        expect(text, 'hola');
        final sent = asrCap.lastRequest!;
        expect(sent.audioBytes, same(bytes));
        expect(sent.filename, 'craft_capture.wav');
        expect(sent.mimeType, 'audio/wav');
        expect(sent.language, 'es');
      },
    );

    test('passes through a null language when none is provided', () async {
      final asrCap = _RecordingAsrCapability(const AsrResult(text: 'ok'));
      final container = ProviderContainer(
        overrides: [asrCapabilityProvider.overrideWithValue(asrCap)],
      );
      addTearDown(container.dispose);

      final transcriber = CraftAsrServiceTranscriber(
        container.read(asrServiceProvider),
      );

      await transcriber.transcribe(audioBytes: _wavBytes());

      expect(asrCap.lastRequest!.language, isNull);
      expect(asrCap.lastRequest!.filename, 'craft_capture.wav');
    });

    test('surfaces empty recognized text as an empty string', () async {
      final asrCap = _RecordingAsrCapability(const AsrResult(text: ''));
      final container = ProviderContainer(
        overrides: [asrCapabilityProvider.overrideWithValue(asrCap)],
      );
      addTearDown(container.dispose);

      final text = await CraftAsrServiceTranscriber(
        container.read(asrServiceProvider),
      ).transcribe(audioBytes: _wavBytes());

      expect(text, '');
    });
  });

  group('CraftTtsServiceSynthesizer', () {
    test('maps TtsResult fields to CraftSynthesisResult', () async {
      final ttsCap = _RecordingTtsCapability(
        TtsResult(
          audioBytes: Uint8List.fromList(<int>[0, 1, 2]),
          format: 'riff-16khz-16bit-mono-pcm',
          durationMs: 1234,
          wordBoundaries: <TtsWordBoundary>[
            const TtsWordBoundary(
              text: 'hello',
              audioOffsetMs: 0,
              durationMs: 200,
            ),
            const TtsWordBoundary(
              text: 'world',
              audioOffsetMs: 200,
              durationMs: 250,
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [ttsCapabilityProvider.overrideWithValue(ttsCap)],
      );
      addTearDown(container.dispose);

      final result = await CraftTtsServiceSynthesizer(
        container.read(ttsServiceProvider),
      ).synthesize(text: 'hello world', language: 'en', voice: 'en-US-Aria');

      expect(result.audioBytes, equals(<int>[0, 1, 2]));
      expect(result.format, 'riff-16khz-16bit-mono-pcm');
      expect(result.wordBoundaries, hasLength(2));
      expect(result.wordBoundaries[0].text, 'hello');
      expect(result.wordBoundaries[0].audioOffsetMs, 0);
      expect(result.wordBoundaries[0].durationMs, 200);
      expect(result.wordBoundaries[1].text, 'world');
      expect(result.wordBoundaries[1].audioOffsetMs, 200);
      expect(result.wordBoundaries[1].durationMs, 250);

      final sent = ttsCap.lastRequest!;
      expect(sent.text, 'hello world');
      expect(sent.language, 'en');
      expect(sent.voice, 'en-US-Aria');
    });

    test(
      'defaults format to "wav" when TtsService returns null format',
      () async {
        final ttsCap = _RecordingTtsCapability(
          TtsResult(audioBytes: Uint8List.fromList(<int>[9])),
        );
        final container = ProviderContainer(
          overrides: [ttsCapabilityProvider.overrideWithValue(ttsCap)],
        );
        addTearDown(container.dispose);

        final result = await CraftTtsServiceSynthesizer(
          container.read(ttsServiceProvider),
        ).synthesize(text: 'hi', language: 'en');

        expect(result.format, 'wav');
        expect(result.wordBoundaries, isEmpty);
        expect(result.audioBytes, equals(<int>[9]));
      },
    );

    test(
      'returns an empty word-boundary list when none are returned',
      () async {
        final ttsCap = _RecordingTtsCapability(
          TtsResult(audioBytes: Uint8List.fromList(<int>[1]), format: 'wav'),
        );
        final container = ProviderContainer(
          overrides: [ttsCapabilityProvider.overrideWithValue(ttsCap)],
        );
        addTearDown(container.dispose);

        final result = await CraftTtsServiceSynthesizer(
          container.read(ttsServiceProvider),
        ).synthesize(text: '...', language: 'en');

        expect(result.wordBoundaries, isEmpty);
        expect(result.audioBytes, equals(<int>[1]));
      },
    );
  });
}
