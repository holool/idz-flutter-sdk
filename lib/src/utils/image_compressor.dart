import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../exceptions/idz_exception.dart';

/// Utility class for compressing images with configurable dimensions and quality.
class ImageCompressor {
  /// Compresses an image file to specified dimensions and quality.
  ///
  /// If the image's longest edge exceeds [maxDimension], it will be resized
  /// while maintaining aspect ratio. The output is always JPEG format.
  ///
  /// Parameters:
  /// - [file]: The image file to compress
  /// - [maxDimension]: Maximum pixel dimension for the longest edge (default: 1920)
  /// - [quality]: JPEG quality percentage 0-100 (default: 85)
  ///
  /// Returns: A [File] pointing to the compressed image
  /// Throws: [IdzException] if compression fails
  static Future<File> compressImage(
    File file, {
    int maxDimension = 1920,
    int quality = 85,
  }) async {
    if (!await file.exists()) {
      throw IdzException('Image file does not exist: ${file.path}');
    }

    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        throw IdzException('Image compression returned null');
      }

      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(result);
      return compressedFile;
    } catch (e) {
      throw IdzException('Image compression failed: $e');
    }
  }

  /// Checks if an image needs compression based on its dimensions.
  ///
  /// Returns true if the image's longest edge exceeds [maxDimension].
  /// This is a heuristic check and does not guarantee exact dimensions.
  ///
  /// Parameters:
  /// - [file]: The image file to check
  /// - [maxDimension]: The maximum allowed dimension (default: 1920)
  ///
  /// Returns: true if compression is recommended, false otherwise
  static bool needsCompression(File file, {int maxDimension = 1920}) {
    // Note: Accurate dimension checking requires decoding the image,
    // which is expensive. For now, we use file size as a heuristic.
    // Files larger than 2MB are likely to benefit from compression.
    final fileSizeInMb = file.lengthSync() / (1024 * 1024);
    return fileSizeInMb > 2.0;
  }
}
