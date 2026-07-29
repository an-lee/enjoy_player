/// `POST /pronounce`.
library;

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/rest_api.dart';

class PronounceApi extends RestApi {
  PronounceApi(super.client);

  static const _path = '/pronounce';

  Future<JsonMap> pronounce({
    required String text,
    required String locale,
    String? voice,
  }) {
    return client.postJson(
      _path,
      body: {
        'text': text,
        'locale': locale,
        if (voice != null && voice.isNotEmpty) 'voice': voice,
      },
    );
  }
}
