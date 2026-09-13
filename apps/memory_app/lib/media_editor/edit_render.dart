import 'dart:math' as math;

import 'package:memory_domain/memory_domain.dart';

/// Maps an [EditRecipe] to a 4x5 RGBA color matrix for live preview rendering
/// via `ColorFiltered`. Deterministic and unit-testable; the editor and the
/// viewer share this pipeline.
List<double> colorMatrixFor(EditAdjustments adjustments, EditFilter filter) {
  // Base: identity.
  var r = <double>[1, 0, 0, 0, 0];
  var g = <double>[0, 1, 0, 0, 0];
  var b = <double>[0, 0, 1, 0, 0];
  var a = <double>[0, 0, 0, 1, 0];

  (r, g, b, a) = _applySaturation(r, g, b, a, _saturationFor(adjustments));
  (r, g, b, a) = _applyWarmth(r, g, b, a, adjustments.warmth);
  (r, g, b, a) = _applyContrast(r, g, b, a, adjustments.contrast);
  (r, g, b, a) = _applyToneScale(
    r,
    g,
    b,
    a,
    gain: 1 + adjustments.exposure * 0.6 + adjustments.brightness * 0.25,
  );
  (r, g, b, a) = _applyShadowsHighlights(r, g, b, a, adjustments);
  (r, g, b, a) = _applyFilterTint(r, g, b, a, filter);

  return [...r, ...g, ...b, ...a];
}

double _saturationFor(EditAdjustments adjustments) =>
    1 + adjustments.saturation * 0.8;

List<double> _scaleRow(List<double> row, double factor) {
  final result = [...row];
  for (var i = 0; i < 4; i++) {
    result[i] = row[i] * factor;
  }
  return result;
}

(List<double>, List<double>, List<double>, List<double>) _applySaturation(
  List<double> r,
  List<double> g,
  List<double> b,
  List<double> a,
  double saturation,
) {
  if ((saturation - 1).abs() < 0.001) return (r, g, b, a);
  const lumR = 0.213;
  const lumG = 0.715;
  const lumB = 0.072;
  List<double> row(List<double> base) {
    final sr = lumR * (1 - saturation) + (base[0] * saturation);
    final sg = lumG * (1 - saturation) + (base[1] * saturation);
    final sb = lumB * (1 - saturation) + (base[2] * saturation);
    return [sr, sg, sb, base[3], base[4]];
  }

  return (row(r), row(g), row(b), a);
}

(List<double>, List<double>, List<double>, List<double>) _applyWarmth(
  List<double> r,
  List<double> g,
  List<double> b,
  List<double> a,
  double warmth,
) {
  if (warmth == 0) return (r, g, b, a);
  // Positive warmth -> warmer (more red, less blue).
  final rr = [...r];
  final bb = [...b];
  rr[4] = (rr[4] + warmth * 0.08).clamp(-1, 1).toDouble();
  bb[4] = (bb[4] - warmth * 0.08).clamp(-1, 1).toDouble();
  return (rr, g, bb, a);
}

(List<double>, List<double>, List<double>, List<double>) _applyContrast(
  List<double> r,
  List<double> g,
  List<double> b,
  List<double> a,
  double contrast,
) {
  if (contrast == 0) return (r, g, b, a);
  final factor = 1 + contrast * 0.6;
  return (
    _contrastRow(r, factor),
    _contrastRow(g, factor),
    _contrastRow(b, factor),
    a,
  );
}

List<double> _contrastRow(List<double> row, double factor) {
  // pivot 0.5: out = (in - 0.5) * factor + 0.5
  final result = [
    row[0] * factor,
    row[1] * factor,
    row[2] * factor,
    row[3],
    0.0,
  ];
  result[4] = (0.5 - 0.5 * factor) + row[4];
  return result;
}

(List<double>, List<double>, List<double>, List<double>) _applyToneScale(
  List<double> r,
  List<double> g,
  List<double> b,
  List<double> a, {
  required double gain,
}) {
  if ((gain - 1).abs() < 0.001) return (r, g, b, a);
  return (_scaleRow(r, gain), _scaleRow(g, gain), _scaleRow(b, gain), a);
}

(List<double>, List<double>, List<double>, List<double>)
_applyShadowsHighlights(
  List<double> r,
  List<double> g,
  List<double> b,
  List<double> a,
  EditAdjustments adjustments,
) {
  if (adjustments.shadows == 0 && adjustments.highlights == 0) {
    return (r, g, b, a);
  }
  // Linear approximation: shadows lift the dark end (add offset scaled),
  // highlights push the bright end (gain on top of existing offsets).
  const shadowGain = 0.18;
  const highlightGain = 0.15;
  final offset = adjustments.shadows * shadowGain;
  final gain = 1 + adjustments.highlights * highlightGain;
  return (
    _toneRow(r, gain, offset),
    _toneRow(g, gain, offset),
    _toneRow(b, gain, offset),
    a,
  );
}

List<double> _toneRow(List<double> row, double gain, double offset) {
  final result = [row[0] * gain, row[1] * gain, row[2] * gain, row[3], 0.0];
  result[4] = row[4] * gain + offset;
  return result;
}

(List<double>, List<double>, List<double>, List<double>) _applyFilterTint(
  List<double> r,
  List<double> g,
  List<double> b,
  List<double> a,
  EditFilter filter,
) {
  switch (filter) {
    case EditFilter.none:
      return (r, g, b, a);
    case EditFilter.vivid:
      return _applySaturation(r, g, b, a, 1.25);
    case EditFilter.warm:
      return _applyWarmth(r, g, b, a, 0.5);
    case EditFilter.cool:
      return _applyWarmth(r, g, b, a, -0.5);
    case EditFilter.mono:
      const lumR = 0.213;
      const lumG = 0.715;
      const lumB = 0.072;
      List<double> row(double base) => [
        lumR * base,
        lumG * base,
        lumB * base,
        0,
        0,
      ];
      return (row(1.0), row(1.0), row(1.0), a);
  }
}

/// Composition helpers used by preview widgets.
double straightenRadians(double degrees) => degrees * math.pi / 180;
