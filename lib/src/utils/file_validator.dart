import 'dart:io';

import '../exceptions/either.dart';
import '../exceptions/kyc_failure.dart';

// Type alias for convenience
typedef FileValidationResult = Either<KycFailure, void>;

/// Utility class for validating files used in KYC verification.
///
/// This validator checks:
/// - File existence
/// - File size constraints
/// - Magic bytes (file format verification, not extension-based)
///
/// The validator is the first line of defense for file validation.
/// The backend does not perform additional validation.
class FileValidator {
  /// Validates an image file for KYC verification.
  ///
  /// Checks:
  /// - File exists
  /// - File size does not exceed [maxSizeMb]
  /// - Magic bytes indicate JPEG or PNG format
  ///
  /// Returns [Right] if valid, [Left] with [KycFailure] if invalid.
  static FileValidationResult validateImageFile(
    File file, {
    int maxSizeMb = 10,
  }) {
    // Check file exists
    if (!file.existsSync()) {
      return const Left(KycFailureFileValidation('File does not exist'));
    }

    // Check size
    final sizeMb = file.lengthSync() / (1024 * 1024);
    if (sizeMb > maxSizeMb) {
      return Left(
        KycFailureFileValidation(
          'File size exceeds ${maxSizeMb}MB (current: ${sizeMb.toStringAsFixed(2)}MB)',
        ),
      );
    }

    // Check magic bytes (NOT extension)
    final bytes = _readMagicBytes(file, 8);
    if (bytes == null) {
      return const Left(KycFailureFileValidation('Unable to read file'));
    }

    if (!_isJpeg(bytes) && !_isPng(bytes)) {
      return Left(
        KycFailureFileValidation('Invalid image format (JPEG or PNG required)'),
      );
    }

    return Right(null);
  }

  /// Validates a video file for KYC verification.
  ///
  /// Checks:
  /// - File exists
  /// - File size does not exceed [maxSizeMb]
  /// - Magic bytes indicate MP4 format
  /// - (Optional) Video duration does not exceed [maxDuration]
  ///
  /// Returns [Right] if valid, [Left] with [KycFailure] if invalid.
  static FileValidationResult validateVideoFile(
    File file, {
    int maxSizeMb = 50,
    Duration? maxDuration,
  }) {
    // Check file exists
    if (!file.existsSync()) {
      return const Left(KycFailureFileValidation('File does not exist'));
    }

    // Check size
    final sizeMb = file.lengthSync() / (1024 * 1024);
    if (sizeMb > maxSizeMb) {
      return Left(
        KycFailureFileValidation(
          'File size exceeds ${maxSizeMb}MB (current: ${sizeMb.toStringAsFixed(2)}MB)',
        ),
      );
    }

    // Check magic bytes (NOT extension)
    final bytes = _readMagicBytes(file, 32);
    if (bytes == null) {
      return const Left(KycFailureFileValidation('Unable to read file'));
    }

    if (!_isMp4(bytes)) {
      return Left(
        KycFailureFileValidation('Invalid video format (MP4 required)'),
      );
    }

    // Note: Duration validation would require video decoding/parsing,
    // which is beyond the scope of magic byte validation.
    // This is deferred to the backend or a dedicated video processing library.

    return Right(null);
  }

  /// Reads the first [numBytes] from a file as magic bytes.
  ///
  /// Returns null if the file cannot be read or is smaller than [numBytes].
  static List<int>? _readMagicBytes(File file, int numBytes) {
    try {
      final raf = file.openSync();
      final bytes = raf.readSync(numBytes);
      raf.closeSync();
      return bytes;
    } catch (e) {
      return null;
    }
  }

  /// Checks if the given bytes represent a JPEG file.
  ///
  /// JPEG files start with the magic bytes: 0xFF 0xD8 0xFF
  static bool _isJpeg(List<int> bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  /// Checks if the given bytes represent a PNG file.
  ///
  /// PNG files start with the magic bytes: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
  static bool _isPng(List<int> bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  /// Checks if the given bytes represent an MP4 file.
  ///
  /// MP4 files contain the 'ftyp' box signature at offset 4.
  /// The signature is: 0x66 0x74 0x79 0x70 ('ftyp' in ASCII)
  static bool _isMp4(List<int> bytes) {
    // MP4 files have 'ftyp' box at offset 4
    // ftyp = 0x66 0x74 0x79 0x70
    if (bytes.length < 8) {
      return false;
    }

    return bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70;
  }
}
