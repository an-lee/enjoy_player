import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/alignment_language.dart';

void main() {
  test('YouTube InnerTube en maps onto the alignment catalog', () {
    expect(alignmentLanguageForTranscript('en'), 'en-US');
    expect(alignmentLanguageForTranscript('en-US'), 'en-US');
    expect(alignmentLanguageForTranscript('en-GB'), 'en-GB');
  });

  test('unsupported transcript languages fail closed', () {
    expect(alignmentLanguageForTranscript('zh-CN'), isNull);
    expect(alignmentLanguageForTranscript('zh-Hans'), isNull);
    expect(alignmentLanguageForTranscript('und'), isNull);
    expect(alignmentLanguageForTranscript(''), isNull);
  });
}
