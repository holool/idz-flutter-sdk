import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/idz_flutter.dart';

void main() {
  group('IdzConfig', () {
    test('requires apiKey, defaults baseUrl to production', () {
      final config = IdzConfig(apiKey: 'idz_test_abc');
      expect(config.apiKey, 'idz_test_abc');
      expect(config.baseUrl, 'https://api.idz.holool.dev');
    });

    test('has sensible defaults', () {
      final config = IdzConfig(apiKey: 'k');
      expect(config.timeout, const Duration(seconds: 60));
      expect(config.maxImageDimension, 1920);
      expect(config.imageQuality, 85);
      expect(config.maxVideoResolutionHeight, 720);
      expect(config.maxVideoDuration, const Duration(seconds: 30));
      expect(config.maxFileSizeMb, 10);
      expect(config.enableLogging, false);
    });

    test('accepts overrides', () {
      final config = IdzConfig(
        apiKey: 'k',
        baseUrl: 'http://localhost:8000',
        timeout: const Duration(seconds: 30),
        maxImageDimension: 1024,
        imageQuality: 75,
        maxVideoResolutionHeight: 480,
        maxVideoDuration: const Duration(seconds: 15),
        maxFileSizeMb: 5,
        enableLogging: true,
      );
      expect(config.baseUrl, 'http://localhost:8000');
      expect(config.timeout, const Duration(seconds: 30));
      expect(config.maxFileSizeMb, 5);
      expect(config.enableLogging, true);
    });
  });

  group('IdzFlutter', () {
    test('exposes the configured client', () {
      final sdk = IdzFlutter(config: IdzConfig(apiKey: 'k'));
      expect(sdk.client, isNotNull);
      expect(sdk.client.config.apiKey, 'k');
      sdk.dispose();
    });
  });
}
