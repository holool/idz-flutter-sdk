import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Configures the live capture-quality checks run against document
/// camera preview frames.
///
/// All thresholds are nullable; setting one to `null` disables that
/// individual probe (the corresponding [QualityReport] flag stays
/// `true`). Disabling every probe yields the [CaptureQualityProbe.disabled]
/// factory, which is the right choice if you want the camera UI to
/// keep working without any live analysis.
///
/// Numbers were tuned for hand-held Algerian national ID / DL captures
/// indoors with typical phone cameras. Re-tune by inspecting the raw
/// scores on a [QualityReport] for your own dataset.
class CaptureQualityProbe {
  /// Minimum Laplacian variance of the Y-plane in the analysed region
  /// for the frame to be considered sharp. Lower = more lenient.
  ///
  /// `~80` flags hand-blur on typical phone cameras. Values under 40
  /// will essentially never fail; values over 200 will reject any
  /// hand-held shot without a stabiliser.
  final double? blurMinVariance;

  /// Maximum fraction (`0..1`) of analysed-region pixels with `Y > 240`
  /// before glare is flagged. Higher = more lenient.
  ///
  /// `0.03` (3%) tolerates the small specular highlight you get from
  /// laminated cards under ambient light but catches direct ceiling-
  /// light blow-outs.
  final double? glareMaxFraction;

  /// Maximum mean absolute Y-diff between consecutive downscaled
  /// frames for the camera to be considered steady. Higher = more
  /// lenient.
  ///
  /// `5.0` (out of 255) tolerates micro-tremor but flags a real shake.
  final double? steadinessMaxDelta;

  const CaptureQualityProbe({
    this.blurMinVariance,
    this.glareMaxFraction,
    this.steadinessMaxDelta,
  });

  /// Default thresholds tuned for hand-held ID capture indoors. Use
  /// [CaptureQualityProbe.disabled] to turn the probe off entirely.
  factory CaptureQualityProbe.standard() => const CaptureQualityProbe(
        blurMinVariance: 80.0,
        glareMaxFraction: 0.03,
        steadinessMaxDelta: 5.0,
      );

  /// All probes disabled — [QualityReport.allGood] is always `true`,
  /// and the indicator UI renders nothing.
  const CaptureQualityProbe.disabled()
      : blurMinVariance = null,
        glareMaxFraction = null,
        steadinessMaxDelta = null;

  /// `true` iff at least one probe is configured.
  bool get isEnabled =>
      blurMinVariance != null ||
      glareMaxFraction != null ||
      steadinessMaxDelta != null;

  /// Evaluate all enabled probes against a single Y-plane (luma)
  /// buffer.
  ///
  /// - [currentY] is a raw Y-plane buffer, one byte per pixel, in
  ///   row-major order. Most camera APIs hand this back from a YUV420
  ///   capture's first plane.
  /// - [width] / [height] are the Y-plane dimensions. If the source
  ///   plane has row padding (`bytesPerRow > width`), the caller is
  ///   responsible for stripping it first — otherwise the math will
  ///   read garbage.
  /// - [region] selects the area to analyse, in `0..1` normalised
  ///   coordinates. Defaults to the central 60% box (approximates a
  ///   landscape card centred in the overlay).
  /// - [previousY] is the previous frame's downscaled Y buffer
  ///   returned via [QualityReport.downscaledY]. Pass `null` on the
  ///   first frame; steadiness will report `true` with delta `0`.
  /// - [downscale] is the size of the longer side after sampling.
  ///   `160` is a good balance between accuracy and ~1 ms / frame on
  ///   mid-range Android.
  QualityReport evaluate({
    required Uint8List currentY,
    required int width,
    required int height,
    Rect region = const Rect.fromLTWH(0.20, 0.20, 0.60, 0.60),
    Uint8List? previousY,
    int downscale = 160,
  }) {
    if (!isEnabled) return QualityReport.allGreen();
    if (currentY.isEmpty || width <= 0 || height <= 0) {
      return QualityReport.allGreen();
    }

    final (down, downW, downH) =
        _downscaleY(currentY, width, height, downscale);

    final cropL = (downW * region.left).floor().clamp(0, downW - 1);
    final cropT = (downH * region.top).floor().clamp(0, downH - 1);
    final cropW =
        (downW * region.width).floor().clamp(1, downW - cropL).toInt();
    final cropH =
        (downH * region.height).floor().clamp(1, downH - cropT).toInt();

    final blurVar = blurMinVariance == null
        ? 0.0
        : _laplacianVariance(down, downW, cropL, cropT, cropW, cropH);
    final glareFrac = glareMaxFraction == null
        ? 0.0
        : _overexposedFraction(down, downW, cropL, cropT, cropW, cropH);
    final steadyDelta = steadinessMaxDelta == null
        ? 0.0
        : _meanAbsDiff(down, previousY);

    return QualityReport(
      sharp: blurMinVariance == null || blurVar >= blurMinVariance!,
      noGlare: glareMaxFraction == null || glareFrac <= glareMaxFraction!,
      steady: steadinessMaxDelta == null ||
          previousY == null ||
          previousY.length != down.length ||
          steadyDelta <= steadinessMaxDelta!,
      blurVariance: blurVar,
      glareFraction: glareFrac,
      steadinessDelta: steadyDelta,
      downscaledY: down,
    );
  }

  // ----------------------------------------------------------------
  // Math helpers — package-private for tests.
  // ----------------------------------------------------------------

  /// Nearest-neighbour downscale of the Y plane so the longer side is
  /// at most [target] pixels. Cheap and lossless enough for
  /// statistical measurements; we never use the result for rendering.
  static (Uint8List, int, int) _downscaleY(
    Uint8List src,
    int srcW,
    int srcH,
    int target,
  ) {
    final longer = math.max(srcW, srcH);
    if (longer <= target) return (src, srcW, srcH);
    final scale = target / longer;
    final dstW = math.max(1, (srcW * scale).round());
    final dstH = math.max(1, (srcH * scale).round());
    final dst = Uint8List(dstW * dstH);
    for (var y = 0; y < dstH; y++) {
      final sy = (y / scale).floor().clamp(0, srcH - 1);
      final srcRow = sy * srcW;
      final dstRow = y * dstW;
      for (var x = 0; x < dstW; x++) {
        final sx = (x / scale).floor().clamp(0, srcW - 1);
        dst[dstRow + x] = src[srcRow + sx];
      }
    }
    return (dst, dstW, dstH);
  }

  /// Variance of a 4-connected Laplacian applied over the cropped
  /// region. Skips a 1-pixel border. High variance = lots of edges =
  /// sharp; low variance = blurry / out of focus.
  static double _laplacianVariance(
    Uint8List buf,
    int stride,
    int cropL,
    int cropT,
    int cropW,
    int cropH,
  ) {
    if (cropW < 3 || cropH < 3) return 0;
    var sum = 0.0;
    var sumSq = 0.0;
    var n = 0;
    final r1 = cropT + 1;
    final r2 = cropT + cropH - 1;
    final c1 = cropL + 1;
    final c2 = cropL + cropW - 1;
    for (var y = r1; y < r2; y++) {
      final row = y * stride;
      for (var x = c1; x < c2; x++) {
        final v = buf[row + x] * 4 -
            buf[row + x - 1] -
            buf[row + x + 1] -
            buf[row - stride + x] -
            buf[row + stride + x];
        final vd = v.toDouble();
        sum += vd;
        sumSq += vd * vd;
        n++;
      }
    }
    if (n == 0) return 0;
    final mean = sum / n;
    return (sumSq / n) - mean * mean;
  }

  /// Fraction (`0..1`) of cropped-region pixels with `Y > 240` — the
  /// blow-out band where details are unrecoverable.
  static double _overexposedFraction(
    Uint8List buf,
    int stride,
    int cropL,
    int cropT,
    int cropW,
    int cropH,
  ) {
    var hot = 0;
    final r2 = cropT + cropH;
    final c2 = cropL + cropW;
    for (var y = cropT; y < r2; y++) {
      final row = y * stride;
      for (var x = cropL; x < c2; x++) {
        if (buf[row + x] > 240) hot++;
      }
    }
    final total = cropW * cropH;
    return total == 0 ? 0 : hot / total;
  }

  /// Mean absolute difference between current and previous downscaled
  /// Y buffers. Returns `0` when the previous buffer is missing or
  /// shape-mismatched (caller already treats that as "steady").
  static double _meanAbsDiff(Uint8List current, Uint8List? previous) {
    if (previous == null || previous.length != current.length) return 0;
    var sum = 0;
    for (var i = 0; i < current.length; i++) {
      final d = current[i] - previous[i];
      sum += d < 0 ? -d : d;
    }
    return sum / current.length;
  }
}

/// One evaluation of a [CaptureQualityProbe] against a frame.
///
/// Booleans (`sharp`, `noGlare`, `steady`) drive the UI; the raw
/// scores are exposed for analytics, threshold tuning, or surfacing
/// to power users.
class QualityReport {
  final bool sharp;
  final bool noGlare;
  final bool steady;

  final double blurVariance;
  final double glareFraction;
  final double steadinessDelta;

  /// The downscaled Y buffer used to compute the current report.
  /// Pass it back as `previousY` on the next [CaptureQualityProbe.evaluate]
  /// call so steadiness can be measured. `null` for the disabled
  /// probe.
  final Uint8List? downscaledY;

  const QualityReport({
    required this.sharp,
    required this.noGlare,
    required this.steady,
    required this.blurVariance,
    required this.glareFraction,
    required this.steadinessDelta,
    this.downscaledY,
  });

  /// `true` when every enabled probe passes. Convenience for "is it
  /// safe to fire the shutter?".
  bool get allGood => sharp && noGlare && steady;

  /// A green report on every axis. Returned by the disabled probe and
  /// by [evaluate] when given an empty frame.
  factory QualityReport.allGreen() => const QualityReport(
        sharp: true,
        noGlare: true,
        steady: true,
        blurVariance: 0,
        glareFraction: 0,
        steadinessDelta: 0,
      );

  @override
  String toString() => 'QualityReport('
      'sharp:$sharp(${blurVariance.toStringAsFixed(1)}) '
      'noGlare:$noGlare(${(glareFraction * 100).toStringAsFixed(1)}%) '
      'steady:$steady(${steadinessDelta.toStringAsFixed(1)}))';
}
