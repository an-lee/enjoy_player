/// Video endpoints (ported from `@enjoy/api` video service).
library;

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/query_params.dart';
import 'package:enjoy_player/data/api/rest_api.dart';

class VideoApi extends RestApi {
  VideoApi(super.client);

  static const _minePath = '/api/v1/mine/videos';

  Future<List<JsonMap>> videos({
    String? provider,
    int? limit,
    String? updatedAfter,
  }) {
    return client.getJsonList(
      _minePath,
      queryParameters: buildQuery({
        'provider': provider,
        'limit': limit,
        'updatedAfter': updatedAfter,
      }),
    );
  }

  Future<JsonMap> video(String id) => client.getJson('$_minePath/$id');

  Future<JsonMap> uploadVideo(JsonMap video) =>
      client.postJson(_minePath, body: {'video': video});

  Future<JsonMap> deleteVideo(String id) => client.deleteJson('$_minePath/$id');
}
