/// Worker pronounce HTTP via [guardAiCall].
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/api/services/ai/ai_api_providers.dart';
import 'package:enjoy_player/features/ai/application/ai_api_failures.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_result.dart';

part 'pronounce_service.g.dart';

final class PronounceService {
  PronounceService(this._ref);

  final Ref _ref;

  Future<PronounceResult> pronounce({
    required String text,
    required String locale,
  }) => guardAiCall(() async {
    final json = await _ref
        .read(pronounceApiProvider)
        .pronounce(text: text, locale: locale);
    return PronounceResult.fromJson(json);
  });
}

@Riverpod(keepAlive: true)
PronounceService pronounceService(Ref ref) => PronounceService(ref);
