import 'package:enjoy_player/features/shadow_reading/application/recording_input_device_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  group('RecordingInputDeviceState', () {
    const realMic = InputDevice(id: 'real-mic', label: 'Realtek Microphone');
    const glideX = InputDevice(id: 'glidex', label: 'GlideX Shared Audio');

    test('exposes its three scalar fields', () {
      const state = RecordingInputDeviceState(
        devices: <InputDevice>[],
        selectedId: null,
        persistedId: null,
      );
      expect(state.devices, isEmpty);
      expect(state.selectedId, isNull);
      expect(state.persistedId, isNull);
    });

    test('autoPicked is true when persistedId is null', () {
      const state = RecordingInputDeviceState(
        devices: <InputDevice>[],
        selectedId: null,
        persistedId: null,
      );
      expect(state.autoPicked, isTrue);
    });

    test('autoPicked is false when persistedId is set', () {
      const state = RecordingInputDeviceState(
        devices: <InputDevice>[],
        selectedId: 'real-mic',
        persistedId: 'real-mic',
      );
      expect(state.autoPicked, isFalse);
    });

    test('autoPicked is false even when persistedId is an empty string', () {
      // The upstream `_readPersistedId` treats empty/missing as null, but the
      // state class itself only checks `== null`.
      const state = RecordingInputDeviceState(
        devices: <InputDevice>[],
        selectedId: 'real-mic',
        persistedId: '',
      );
      expect(state.autoPicked, isFalse);
    });

    test('selectedDevice returns null when selectedId is null', () {
      const state = RecordingInputDeviceState(
        devices: <InputDevice>[realMic],
        selectedId: null,
        persistedId: null,
      );
      expect(state.selectedDevice, isNull);
    });

    test('selectedDevice returns the matching device', () {
      final state = RecordingInputDeviceState(
        devices: [realMic, glideX],
        selectedId: 'glidex',
        persistedId: 'glidex',
      );
      expect(state.selectedDevice, glideX);
    });

    test('selectedDevice returns null when id is not in devices list', () {
      final state = RecordingInputDeviceState(
        devices: [realMic],
        selectedId: 'missing',
        persistedId: 'missing',
      );
      expect(state.selectedDevice, isNull);
    });

    test('selectedDevice returns the only device when id matches', () {
      final state = RecordingInputDeviceState(
        devices: [realMic],
        selectedId: 'real-mic',
        persistedId: null,
      );
      expect(state.selectedDevice, realMic);
    });
  });
}
