import 'client/idz_api_client.dart';
import 'idz_config.dart';

/// Main entry point for the IDz Flutter SDK.
///
/// ```dart
/// final idz = IdzFlutter(
///   config: IdzConfig(apiKey: 'idz_live_…'),
/// );
///
/// final result = await idz.client.verifyDocument(
///   idFront: frontFile,
///   idBack: backFile,
///   documentType: DocumentType.algerianDrivingLicense,
///   idempotencyKey: someUuid,
/// );
///
/// switch (result) {
///   case Right(:final value):
///     print('passed: ${value.id}');
///   case Left(:final value):
///     print('failed: $value');
/// }
///
/// idz.dispose();
/// ```
class IdzFlutter {
  /// Configuration this SDK instance was built with.
  final IdzConfig config;

  late final IdzApiClient _client;

  IdzFlutter({required this.config}) {
    _client = IdzApiClient(config: config);
  }

  /// API client for `/v1/verifications/*` calls.
  IdzApiClient get client => _client;

  /// Release HTTP connections.
  void dispose() => _client.dispose();
}
