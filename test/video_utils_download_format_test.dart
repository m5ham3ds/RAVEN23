import 'package:better_player_plus/better_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/functions/video_utils.dart';
import 'package:raven23/video_providers/common.dart';

void main() {
  test(
    'keeps same-resolution download choices separate for each server',
    () {
      expect(
        VideoUtils.uniqueQualityKeys(<String>[
          '1080p · Jett',
          '1080p · Sova',
          '720p · Jett',
          '480p',
          '480p · Phoenix',
        ]),
        <String>[
          '1080p · Jett',
          '1080p · Sova',
          '720p · Jett',
          '480p',
          '480p · Phoenix',
        ],
      );
    },
  );

  test(
    'removes provider Auto and adaptive choices without merging real sources',
    () {
      expect(
        VideoUtils.uniqueQualityKeys(<String>[
          'unknown quality 0',
          'unknown quality 1',
          'Auto',
          'Auto (2)',
          'Adaptive · Phoenix',
          'HD · Jett',
          'HD · Sova',
        ]),
        <String>[
          'unknown quality 0',
          'unknown quality 1',
          'HD · Jett',
          'HD · Sova',
        ],
      );
    },
  );

  test('uses explicit stream declarations before URL suffixes', () {
    expect(
      VideoUtils.downloadFormat(
        url: 'https://stream.example/signed?token=abc',
        link: RegularVideoLinks(isM3U8: true),
      ),
      'hls',
    );
    expect(
      VideoUtils.downloadFormat(
        url: 'https://stream.example/signed?token=abc',
        link: RegularVideoLinks(streamContainer: 'mp4'),
      ),
      'mp4',
    );
  });

  test('detects manifest and progressive containers from URL paths', () {
    expect(
      VideoUtils.downloadFormat(url: 'https://cdn.example/master.m3u8?x=1'),
      'hls',
    );
    expect(
      VideoUtils.downloadFormat(url: 'https://cdn.example/manifest.mpd'),
      'dash',
    );
    expect(
      VideoUtils.downloadFormat(url: 'https://cdn.example/movie.mp4?token=1'),
      'mp4',
    );
    expect(
      VideoUtils.downloadFormat(url: 'https://cdn.example/movie.webm'),
      'webm',
    );
    expect(
      VideoUtils.downloadFormat(url: 'https://cdn.example/play?id=7'),
      'progressive',
    );
  });

  test('explicit Better Player manifest formats take precedence', () {
    expect(
      VideoUtils.downloadFormat(
        url: 'https://cdn.example/opaque',
        declaredFormat: BetterPlayerVideoFormat.dash,
      ),
      'dash',
    );
  });
}
