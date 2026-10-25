import 'dart:ui';

/// What a stroke means in sigil grammar. The painter styles each role.
enum StrokeRole {
  /// The body of the glyph.
  ink,

  /// The opening circle that marks where the pen first touches.
  startMark,

  /// The terminal crossbar that seals the last stroke.
  terminal,

  /// Construction lines such as an outer binding circle.
  binding,
}

/// One pen-down movement, kept in the order it is written.
class SigilStroke {
  SigilStroke(this.path, {this.role = StrokeRole.ink});

  final Path path;
  final StrokeRole role;

  /// Measured on first use: assembled copies (e.g. every Spare group copy)
  /// that are only ever drawn whole never allocate native metrics.
  late final List<PathMetric> _metrics = path.computeMetrics().toList(growable: false);
  late final double length = _metrics.fold(0.0, (sum, m) => sum + m.length);

  /// The first [fraction] of this stroke by arc length.
  Path partial(double fraction) {
    if (fraction >= 1) return path;
    final out = Path();
    if (fraction <= 0) return out;
    var remaining = length * fraction;
    for (final m in _metrics) {
      if (remaining <= 0) break;
      final take = remaining < m.length ? remaining : m.length;
      out.addPath(m.extractPath(0, take), Offset.zero);
      remaining -= take;
    }
    return out;
  }

  /// The point at [fraction] of the arc length, or null for an empty stroke.
  Offset? pointAt(double fraction) {
    if (_metrics.isEmpty) return null;
    var remaining = length * fraction.clamp(0.0, 1.0);
    for (final m in _metrics) {
      if (remaining <= m.length) return m.getTangentForOffset(remaining)?.position;
      remaining -= m.length;
    }
    return _metrics.last.getTangentForOffset(_metrics.last.length)?.position;
  }

  /// Samples points along the stroke roughly every [spacing] pixels.
  List<Offset> sample(double spacing) {
    final out = <Offset>[];
    for (final m in _metrics) {
      final steps = (m.length / spacing).ceil().clamp(1, 100000);
      for (var i = 0; i <= steps; i++) {
        final p = m.getTangentForOffset(m.length * i / steps)?.position;
        if (p != null) out.add(p);
      }
    }
    return out;
  }
}

/// The output of an engine: strokes in written order plus the nodes they visit.
///
/// Returning only a flattened [Path] would lose the order the ductus needs, so
/// engines return this instead. Use [path] when a single path is enough.
class SigilGeometry {
  SigilGeometry({required this.strokes, this.nodes = const []});

  static final empty = SigilGeometry(strokes: const []);

  final List<SigilStroke> strokes;

  /// Points the pen visits, in order (cells, petals, anchors).
  final List<Offset> nodes;

  bool get isEmpty => strokes.isEmpty;

  late final double totalLength = strokes.fold(0.0, (sum, s) => sum + s.length);

  /// All strokes flattened into one path.
  late final Path path = () {
    final p = Path();
    for (final s in strokes) {
      p.addPath(s.path, Offset.zero);
    }
    return p;
  }();

  /// Builds a path with stroke `i` revealed to `fractions[i]` of its length.
  Path reveal(List<double> fractions) {
    final p = Path();
    for (var i = 0; i < strokes.length && i < fractions.length; i++) {
      final f = fractions[i];
      if (f <= 0) continue;
      p.addPath(strokes[i].partial(f), Offset.zero);
    }
    return p;
  }

  /// The first [length] pixels of ink, following the written order.
  Path revealLength(double length) {
    final p = Path();
    var remaining = length;
    for (final s in strokes) {
      if (remaining <= 0) break;
      if (s.length <= 0) continue;
      p.addPath(s.partial(remaining / s.length), Offset.zero);
      remaining -= s.length;
    }
    return p;
  }
}
