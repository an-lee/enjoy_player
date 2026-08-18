import 'package:enjoy_player/core/platform/espeak_android_provisioner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Flutter asset bundle includes eSpeak lang/en-us (SetVoiceByName)',
    () async {
      final files = await loadEspeakDataAssets();
      final keys = files.keys.toList()..sort();

      expect(
        files.keys.toSet().containsAll(kEspeakRequiredDataRelativePaths),
        isTrue,
        reason:
            'Android IPA uses espeak_SetVoiceByName on nested lang/ files. '
            'missing=${kEspeakRequiredDataRelativePaths.where((p) => !files.containsKey(p)).toList()} '
            'keys=$keys',
      );
    },
  );

  test('AssetManifest lists nested espeak lang files', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final espeakKeys =
        manifest
            .listAssets()
            .where(
              (k) => k.startsWith(
                'packages/forced_alignment/native/espeak-ng-data/',
              ),
            )
            .toList()
          ..sort();
    expect(
      espeakKeys.any((k) => k.endsWith('/lang/en-us')),
      isTrue,
      reason: 'manifest espeak keys=$espeakKeys',
    );
  });
}
