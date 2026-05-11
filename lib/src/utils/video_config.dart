import 'package:camera/camera.dart';

/// Configuration for video recording in the KYC liveness flow.
///
/// This class provides static configuration values for video recording,
/// including resolution preset and duration limits. Video compression
/// happens at recording time via the camera plugin's resolution preset.
class VideoConfig {
  /// The resolution preset for video recording.
  ///
  /// [ResolutionPreset.medium] corresponds to 720p, which provides
  /// a good balance between quality and file size for mobile devices.
  static ResolutionPreset get recordingResolution => ResolutionPreset.medium;

  /// Maximum duration for a single video recording in seconds.
  ///
  /// Liveness videos should be kept short to ensure user engagement
  /// and reduce file size. Default is 30 seconds.
  static const int maxDurationSeconds = 30;

  /// Maximum file size for video uploads in megabytes.
  ///
  /// This limit ensures that videos don't exceed reasonable upload
  /// constraints. Default is 50 MB.
  static const int maxSizeMb = 50;
}
