import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/models/offline_download.dart';

void main() {
  const identity = <String, Object?>{
    'server': 'Jett',
    'providerCode': 'unified:jett',
    'sourceProviderCode': 'unified:sources',
    'sourceKey': 'source-key-1080',
    'quality': '1080p',
    'format': 'mp4',
  };

  test('download request preserves exact selected stream identity', () {
    const request = OfflineDownloadRequest(
      id: 'movie_42',
      url: 'https://cdn.example.test/movie.mp4?token=opaque',
      format: 'mp4',
      title: 'Example movie',
      mediaType: 'movie',
      quality: '1080p',
      streamIdentity: identity,
    );

    expect(request.toMap()['streamIdentity'], identity);
  });

  test('download index metadata restores exact selected stream identity', () {
    final download = OfflineDownload.fromMap(<Object?, Object?>{
      'id': 'movie_42',
      'title': 'Example movie',
      'mediaType': 'movie',
      'quality': '1080p',
      'state': 'completed',
      'progress': 100,
      'createdAt': 1700000000000,
      'streamIdentity': identity,
    });

    expect(download.streamIdentity, identity);
  });
}
