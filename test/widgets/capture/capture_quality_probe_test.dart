import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/src/widgets/capture/capture_quality_probe.dart';

/// Helpers — synthetic frames so the math is exercised without a real
/// camera plane.
Uint8List _constantY(int w, int h, int value) =>
    Uint8List(w * h)..fillRange(0, w * h, value);

Uint8List _checkerboardY(int w, int h, {int squareSize = 2}) {
  final buf = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final on = ((x ~/ squareSize) + (y ~/ squareSize)).isOdd;
      buf[y * w + x] = on ? 255 : 0;
    }
  }
  return buf;
}

Uint8List _verticalGradientY(int w, int h) {
  final buf = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final v = ((y / (h - 1)) * 255).round();
    for (var x = 0; x < w; x++) {
      buf[y * w + x] = v;
    }
  }
  return buf;
}

void main() {
  group('CaptureQualityProbe.disabled', () {
    test('reports everything green regardless of input', () {
      final probe = const CaptureQualityProbe.disabled();
      expect(probe.isEnabled, isFalse);
      final report = probe.evaluate(
        currentY: _constantY(64, 64, 0),
        width: 64,
        height: 64,
      );
      expect(report.allGood, isTrue);
      expect(report.sharp, isTrue);
      expect(report.noGlare, isTrue);
      expect(report.steady, isTrue);
    });
  });

  group('CaptureQualityProbe.standard', () {
    test('flags a constant-color frame as blurry (variance ≈ 0)', () {
      final probe = CaptureQualityProbe.standard();
      final report = probe.evaluate(
        currentY: _constantY(160, 90, 128),
        width: 160,
        height: 90,
      );
      expect(report.blurVariance, lessThan(1.0));
      expect(report.sharp, isFalse,
          reason: 'flat grey frame has no edges, cannot be sharp');
    });

    test('passes blur check on a high-contrast checkerboard', () {
      final probe = CaptureQualityProbe.standard();
      final report = probe.evaluate(
        currentY: _checkerboardY(160, 90),
        width: 160,
        height: 90,
      );
      expect(report.blurVariance, greaterThan(1000.0),
          reason: 'alternating 0/255 produces huge Laplacian response');
      expect(report.sharp, isTrue);
    });

    test('all-white frame trips glare (fraction = 1.0)', () {
      final probe = CaptureQualityProbe.standard();
      final report = probe.evaluate(
        currentY: _constantY(160, 90, 255),
        width: 160,
        height: 90,
      );
      expect(report.glareFraction, closeTo(1.0, 0.001));
      expect(report.noGlare, isFalse);
    });

    test('mid-grey frame passes the glare check', () {
      final probe = CaptureQualityProbe.standard();
      final report = probe.evaluate(
        currentY: _constantY(160, 90, 128),
        width: 160,
        height: 90,
      );
      expect(report.glareFraction, closeTo(0.0, 0.001));
      expect(report.noGlare, isTrue);
    });

    test('identical frames report steady with delta 0', () {
      final probe = CaptureQualityProbe.standard();
      final frame = _verticalGradientY(160, 90);
      final first = probe.evaluate(
        currentY: frame,
        width: 160,
        height: 90,
      );
      expect(first.steady, isTrue,
          reason: 'first frame is always steady — no previous to compare');
      expect(first.downscaledY, isNotNull);

      final second = probe.evaluate(
        currentY: frame,
        width: 160,
        height: 90,
        previousY: first.downscaledY,
      );
      expect(second.steadinessDelta, closeTo(0.0, 0.001));
      expect(second.steady, isTrue);
    });

    test('a flipped frame trips steadiness', () {
      final probe = CaptureQualityProbe.standard();
      final a = _constantY(160, 90, 0);
      final b = _constantY(160, 90, 255);
      final first = probe.evaluate(
        currentY: a,
        width: 160,
        height: 90,
      );
      final second = probe.evaluate(
        currentY: b,
        width: 160,
        height: 90,
        previousY: first.downscaledY,
      );
      expect(second.steadinessDelta, closeTo(255.0, 0.5));
      expect(second.steady, isFalse);
    });

    test('mismatched previous buffer length is treated as steady', () {
      final probe = CaptureQualityProbe.standard();
      final report = probe.evaluate(
        currentY: _constantY(160, 90, 128),
        width: 160,
        height: 90,
        previousY: Uint8List(7),
      );
      expect(report.steady, isTrue,
          reason: 'we cannot compare frames of different sizes — fail open');
    });
  });

  group('individual probes', () {
    test('blur-only probe leaves glare + steady true regardless of input',
        () {
      final probe = const CaptureQualityProbe(blurMinVariance: 80);
      final report = probe.evaluate(
        currentY: _constantY(160, 90, 255),
        width: 160,
        height: 90,
      );
      expect(report.sharp, isFalse);
      expect(report.noGlare, isTrue,
          reason: 'glare probe disabled — flag stays green');
      expect(report.steady, isTrue);
    });

    test('glare-only probe ignores edges', () {
      final probe = const CaptureQualityProbe(glareMaxFraction: 0.03);
      final report = probe.evaluate(
        currentY: _checkerboardY(160, 90),
        width: 160,
        height: 90,
      );
      expect(report.sharp, isTrue,
          reason: 'blur probe disabled — flag stays green');
      expect(report.glareFraction, greaterThan(0.4),
          reason: 'checkerboard with 255 squares is "hot" on ~half pixels');
      expect(report.noGlare, isFalse);
    });
  });

  group('region selection', () {
    test('a white border outside the central region does not trip glare', () {
      // Put a hot ring around a calm grey centre. With the default
      // central-60% region, the probe should only see the grey.
      const w = 200, h = 200;
      final buf = _constantY(w, h, 255);
      for (var y = 40; y < 160; y++) {
        for (var x = 40; x < 160; x++) {
          buf[y * w + x] = 128;
        }
      }
      final probe = CaptureQualityProbe.standard();
      final report = probe.evaluate(
        currentY: buf,
        width: w,
        height: h,
      );
      // Default region.left=0.20 → x ∈ [32, 128) on the downscaled
      // buffer; entirely inside the grey middle, so glare ≈ 0.
      expect(report.glareFraction, lessThan(0.05));
      expect(report.noGlare, isTrue);
    });
  });

  group('QualityReport.allGood', () {
    test('only true when every flag is true', () {
      const r = QualityReport(
        sharp: true,
        noGlare: false,
        steady: true,
        blurVariance: 0,
        glareFraction: 0,
        steadinessDelta: 0,
      );
      expect(r.allGood, isFalse);
    });
  });

  group('edge cases', () {
    test('empty frame returns allGreen, not a math error', () {
      final probe = CaptureQualityProbe.standard();
      final report = probe.evaluate(
        currentY: Uint8List(0),
        width: 0,
        height: 0,
      );
      expect(report.allGood, isTrue);
    });

    test('toString includes all three scores', () {
      final probe = CaptureQualityProbe.standard();
      final report = probe.evaluate(
        currentY: _verticalGradientY(160, 90),
        width: 160,
        height: 90,
      );
      final s = report.toString();
      expect(s, contains('sharp'));
      expect(s, contains('noGlare'));
      expect(s, contains('steady'));
    });

    test('downscale preserves dimensions when source is already small', () {
      final probe = CaptureQualityProbe.standard();
      // 32x32 < default downscale=160 → no downscale.
      final report = probe.evaluate(
        currentY: _constantY(32, 32, 200),
        width: 32,
        height: 32,
      );
      expect(report.downscaledY, isNotNull);
      expect(report.downscaledY!.length, 32 * 32);
    });

    test('downscale shrinks frames larger than target', () {
      final probe = CaptureQualityProbe.standard();
      final w = 1920, h = 1080;
      final report = probe.evaluate(
        currentY: _constantY(w, h, 128),
        width: w,
        height: h,
      );
      final down = report.downscaledY!;
      // 1920 / 160 = 12 → new W=160, new H≈90. We accept ±2.
      final ratio = math.sqrt(down.length / (w * h));
      expect(ratio, closeTo(160 / 1920, 0.02));
    });
  });
}
