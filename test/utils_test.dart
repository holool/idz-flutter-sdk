import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/src/utils/video_config.dart';
import 'package:camera/camera.dart';

void main() {
  group('VideoConfig', () {
    test('recordingResolution returns medium preset', () {
      expect(VideoConfig.recordingResolution, ResolutionPreset.medium);
    });

    test('maxDurationSeconds is 30', () {
      expect(VideoConfig.maxDurationSeconds, 30);
    });

    test('maxSizeMb is 50', () {
      expect(VideoConfig.maxSizeMb, 50);
    });
  });
}
