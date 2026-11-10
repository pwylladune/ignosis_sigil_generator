import 'dart:ui';
import '../geometry/sigil_geometry.dart';

/// The seal as vector lines (SVG): one path per pen stroke, in the order it
/// was written, for a plotter, a cutter, an engraver or a stencil.
///
/// It is the geometry alone: the brush, the paper and the construction (the
/// kamea's square, the rose's letters) are not in it. Curves are sampled
/// every [spacing] scene units, which is finer than any of those tools
/// resolves at the size of a seal.
String sigilSvg(
  SigilGeometry geometry, {
  required Size size,
  Color ink = const Color(0xFF141416),
  double strokeWidth = 3,
  double spacing = 1,
  String title = 'IGNOSIS seal',
}) {
  final w = _num(size.width), h = _num(size.height);
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" width="${w}mm" height="${h}mm">')
    ..writeln('  <title>${_escape(title)}</title>')
    ..writeln('  <g fill="none" stroke="${_hex(ink)}" stroke-width="${_num(strokeWidth)}" '
        'stroke-linecap="round" stroke-linejoin="round">');
  for (final stroke in geometry.strokes) {
    final d = _pathData(stroke.path, spacing);
    if (d.isEmpty) continue;
    out.writeln('    <path class="${stroke.role.name}" d="$d"/>');
  }
  out
    ..writeln('  </g>')
    ..writeln('</svg>');
  return out.toString();
}

/// SVG path data for [path]: each contour as a polyline, closed where the
/// contour is.
String _pathData(Path path, double spacing) {
  final d = StringBuffer();
  for (final m in path.computeMetrics()) {
    if (m.length <= 0) continue;
    final steps = (m.length / spacing).ceil().clamp(1, 200000);
    // A closed contour ends where it began: Z draws that last segment.
    final last = m.isClosed ? steps - 1 : steps;
    final points = <Offset>[];
    for (var i = 0; i <= last; i++) {
      final p = m.getTangentForOffset(m.length * i / steps)?.position;
      if (p == null) continue;
      // A point on the straight line between its neighbours adds nothing.
      if (points.length >= 2 && _collinear(points[points.length - 2], points.last, p)) points.removeLast();
      points.add(p);
    }
    if (points.isEmpty) continue;
    for (var i = 0; i < points.length; i++) {
      if (d.isNotEmpty) d.write(' ');
      d.write('${i == 0 ? 'M' : 'L'}${_num(points[i].dx)} ${_num(points[i].dy)}');
    }
    if (m.isClosed) d.write(' Z');
  }
  return d.toString();
}

/// True when [b] lies on the segment from [a] to [c], to a hundredth of a unit.
bool _collinear(Offset a, Offset b, Offset c) {
  final ac = c - a;
  final length = ac.distance;
  if (length == 0) return false;
  final off = ((b.dx - a.dx) * ac.dy - (b.dy - a.dy) * ac.dx).abs() / length;
  final along = ((b.dx - a.dx) * ac.dx + (b.dy - a.dy) * ac.dy) / (length * length);
  return off < 0.01 && along > 0 && along < 1;
}

/// Two decimals, without a trailing ".00" or "-0".
String _num(double v) {
  final s = v.toStringAsFixed(2);
  final trimmed = s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  return trimmed == '-0' ? '0' : trimmed;
}

String _hex(Color c) {
  String two(double channel) => (channel * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}';
}

String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
