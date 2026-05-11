/// Configuration for the IDz Flutter SDK.
class IdzConfig {
  /// Your IDz API key, prefix `idz_…`. Required.
  ///
  /// Sent on every request as `Authorization: Bearer <apiKey>`. Never
  /// commit this to source control or ship it in a public client build —
  /// keys are billed and tied to your org. For mobile clients, fetch a
  /// scoped key from your own backend at runtime.
  final String apiKey;

  /// The base URL of the IDz API.
  ///
  /// Defaults to the production host. Override for local development
  /// (`http://localhost:8000`) or staging.
  final String baseUrl;

  /// HTTP request timeout. Defaults to 60 seconds.
  final Duration timeout;

  /// Maximum image dimension (longest edge) in pixels — uploads are
  /// resized down to this. Defaults to 1920.
  final int maxImageDimension;

  /// JPEG compression quality (0–100). Defaults to 85.
  final int imageQuality;

  /// Maximum video resolution height. Defaults to 720.
  final int maxVideoResolutionHeight;

  /// Maximum video duration for liveness recording. Defaults to 30s.
  final Duration maxVideoDuration;

  /// Maximum upload size in megabytes. Defaults to 10.
  final int maxFileSizeMb;

  /// Log every HTTP request/response to console. Defaults to false.
  final bool enableLogging;

  const IdzConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.idz.holool.dev',
    this.timeout = const Duration(seconds: 60),
    this.maxImageDimension = 1920,
    this.imageQuality = 85,
    this.maxVideoResolutionHeight = 720,
    this.maxVideoDuration = const Duration(seconds: 30),
    this.maxFileSizeMb = 10,
    this.enableLogging = false,
  });
}
