import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/kamea_engine.dart';
import 'package:ignosis_sigil_generator/src/geometry/sigil_geometry.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/models/sigil_state.dart';
import 'package:ignosis_sigil_generator/src/services/sigil_svg.dart';
import 'package:ignosis_sigil_generator/src/services/universal_export_service.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/scene_factory.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_canvas.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_spec.dart';

/// Every coordinate pair in the SVG's path data.
Iterable<Offset> points(String svg) => RegExp(r'[ML](-?[\d.]+) (-?[\d.]+)')
    .allMatches(svg)
    .map((m) => Offset(double.parse(m.group(1)!), double.parse(m.group(2)!)));

void main() {
  test('a straight stroke is one segment; its role is kept', () {
    final g = SigilGeometry(strokes: [
      SigilStroke(Path()
        ..moveTo(10, 20)
        ..lineTo(110, 20)),
      SigilStroke(
          Path()
            ..moveTo(0, 0)
            ..lineTo(0, 30),
          role: StrokeRole.terminal),
    ]);
    final svg = sigilSvg(g, size: const Size(512, 512));
    expect(svg, contains('viewBox="0 0 512 512"'));
    expect(svg, contains('<path class="ink" d="M10 20 L110 20"/>'));
    expect(svg, contains('<path class="terminal" d="M0 0 L0 30"/>'));
    expect(svg, contains('fill="none"'));
    expect(svg, contains('stroke="#141416"'));
  });

  test('a closed contour closes, and a curve stays on its circle', () {
    final g = SigilGeometry(strokes: [
      SigilStroke(Path()..addOval(Rect.fromCircle(center: const Offset(100, 100), radius: 50)),
          role: StrokeRole.binding),
    ]);
    final svg = sigilSvg(g, size: const Size(200, 200));
    expect(svg, contains(' Z"'));
    final pts = points(svg).toList();
    expect(pts.length, greaterThan(100));
    for (final p in pts) {
      expect((p - const Offset(100, 100)).distance, closeTo(50, 0.05));
    }
  });

  test('an empty geometry is a valid, empty drawing', () {
    final svg = sigilSvg(SigilGeometry.empty, size: const Size(512, 512));
    expect(svg, isNot(contains('<path')));
    expect(svg.trim(), endsWith('</svg>'));
  });

  test('every system exports its strokes, in order, inside the plate, the same each time', () {
    for (final system in SigilSystem.values) {
      for (final inverted in [false, if (system == SigilSystem.infinite) true]) {
        final spec = SigilSpec(
          kernel: IntentKernel.fromText('I COMMAND RADIANT CLARITY'),
          system: system,
          kameaType: PlanetaryKameaType.values.first,
          symmetryFolds: 4,
          symmetryGroup: SymmetryGroup.cyclic,
          inverted: inverted,
        );
        final g = buildScene(spec, SigilCanvas.referenceSize, -1e6).geometry;
        final svg = sigilSvg(g, size: SigilCanvas.referenceSize);
        final name = '${system.name}${inverted ? ' (inverted)' : ''}';
        expect('<path'.allMatches(svg).length, g.strokes.where((s) => s.length > 0).length, reason: name);
        expect(svg, isNot(contains('NaN')), reason: name);
        expect(svg.length, lessThan(400000), reason: '$name is a small file');
        for (final p in points(svg)) {
          expect(p.dx, inInclusiveRange(-1, 513), reason: name);
          expect(p.dy, inInclusiveRange(-1, 513), reason: name);
        }
        expect(
            sigilSvg(buildScene(spec, SigilCanvas.referenceSize, -1e6).geometry, size: SigilCanvas.referenceSize), svg,
            reason: '$name is deterministic');
      }
    }
  });

  test('the title is escaped, and the file is named like the PNG', () {
    final svg = sigilSvg(SigilGeometry.empty, size: const Size(1, 1), title: 'a <b> & c');
    expect(svg, contains('<title>a &lt;b&gt; &amp; c</title>'));
    final at = DateTime.fromMillisecondsSinceEpoch(1793078224020);
    expect(UniversalExportService.svgFilename('ignosis_sigil', at), 'ignosis_sigil_1793078224020.svg');
  });
}
