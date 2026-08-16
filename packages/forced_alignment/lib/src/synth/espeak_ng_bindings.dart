import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Subset of `espeak-ng/speak_lib.h` used for spoken-reference synthesis.
const int audioOutputSynchronous = 2;

const int espeakCharsUtf8 = 1;

const int espeakInitializePhonemeEvents = 0x0001;
const int espeakInitializePhonemeIpa = 0x0002;
const int espeakInitializeDontExit = 0x8000;

const int espeakEventListTerminated = 0;
const int espeakEventWord = 1;
const int espeakEventPhoneme = 7;

const int espeakOk = 0;

/// 64-bit layout of `espeak_EVENT` (pointer-sized `user_data` + 8-byte `id`).
final class EspeakEvent extends Struct {
  @Int32()
  external int type;

  @Uint32()
  external int uniqueIdentifier;

  @Int32()
  external int textPosition;

  @Int32()
  external int length;

  @Int32()
  external int audioPosition;

  @Int32()
  external int sample;

  external Pointer<Void> userData;

  /// `id.string[8]` for phonemes; do not treat as a pointer.
  @Array(8)
  external Array<Uint8> idBytes;
}

typedef EspeakCallbackNative =
    Int32 Function(
      Pointer<Int16> wav,
      Int32 numsamples,
      Pointer<EspeakEvent> events,
    );
typedef EspeakCallbackDart =
    int Function(
      Pointer<Int16> wav,
      int numsamples,
      Pointer<EspeakEvent> events,
    );

typedef InitializeNative =
    Int32 Function(
      Int32 output,
      Int32 buflength,
      Pointer<Utf8> path,
      Int32 options,
    );
typedef InitializeDart =
    int Function(int output, int buflength, Pointer<Utf8> path, int options);

typedef SetVoiceByNameNative = Int32 Function(Pointer<Utf8> name);
typedef SetVoiceByNameDart = int Function(Pointer<Utf8> name);

typedef SetSynthCallbackNative =
    Void Function(Pointer<NativeFunction<EspeakCallbackNative>>);
typedef SetSynthCallbackDart =
    void Function(Pointer<NativeFunction<EspeakCallbackNative>>);

typedef SynthNative =
    Int32 Function(
      Pointer<Utf8> text,
      Size size,
      Uint32 position,
      Int32 positionType,
      Uint32 endPosition,
      Uint32 flags,
      Pointer<Uint32> uniqueIdentifier,
      Pointer<Void> userData,
    );
typedef SynthDart =
    int Function(
      Pointer<Utf8> text,
      int size,
      int position,
      int positionType,
      int endPosition,
      int flags,
      Pointer<Uint32> uniqueIdentifier,
      Pointer<Void> userData,
    );

typedef SynchronizeNative = Int32 Function();
typedef SynchronizeDart = int Function();

final class EspeakNgBindings {
  EspeakNgBindings(DynamicLibrary lib)
    : initialize = lib.lookupFunction<InitializeNative, InitializeDart>(
        'espeak_Initialize',
      ),
      setVoiceByName = lib
          .lookupFunction<SetVoiceByNameNative, SetVoiceByNameDart>(
            'espeak_SetVoiceByName',
          ),
      setSynthCallback = lib
          .lookupFunction<SetSynthCallbackNative, SetSynthCallbackDart>(
            'espeak_SetSynthCallback',
          ),
      synth = lib.lookupFunction<SynthNative, SynthDart>('espeak_Synth'),
      synchronize = lib.lookupFunction<SynchronizeNative, SynchronizeDart>(
        'espeak_Synchronize',
      );

  final InitializeDart initialize;
  final SetVoiceByNameDart setVoiceByName;
  final SetSynthCallbackDart setSynthCallback;
  final SynthDart synth;
  final SynchronizeDart synchronize;
}
