import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates physical archival print sheets ready for manual practitioner combustion
class SigilPrintService {
  /// Renders and prints or exports an A4 / US-Letter ritual sheet
  static Future<void> printPhysicalBurnSheet({
    required Uint8List pngBytes,
    required String rawIntent,
    required String reducedKernel,
    required String systemTitle,
  }) async {
    final doc = pw.Document();

    final image = pw.MemoryImage(pngBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Top Minimalist Archival Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'IGNOSIS RITUAL ARTIFACT',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  pw.Text(
                    'SOLANA REPOSITORY · CONSECRATION SHEET',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 24),

              // Intent & Reduction Telemetry
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  color: PdfColors.grey100,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MATHEMATICAL METHOD:',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          systemTitle.toUpperCase(),
                          style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'SPARE REDUCED KERNEL:',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          reducedKernel.split('').join(' · '),
                          style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 36),

              // The Consecrated Sigil Emblem
              pw.Container(
                width: 320,
                height: 320,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                ),
                child: pw.Center(
                  child: pw.Image(image, width: 280, height: 280),
                ),
              ),

              pw.SizedBox(height: 48),

              // Perforated Cut Guide Line for Fire Ritual
              pw.Row(
                children: [
                  pw.Text('✂ CUT HERE PRIOR TO RITUAL FIRE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600, letterSpacing: 1.5)),
                  pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(left: 8),
                      height: 1,
                      color: PdfColors.grey400,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // Practitioner Instructions for Safe Physical Combustion
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RITUAL CHARGING & COMBUSTION INSTRUCTIONS:',
                      style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1.0),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '1. Cut the circular seal above. Place in a heat-resistant crucible or fireproof dish.\n'
                      '2. Enter Gnosis through steady breath regulation (inhale will, exhale thought).\n'
                      '3. Fix eyes on the seal until the visual image burns into your optic nerve.\n'
                      '4. Ignite the paper completely. As the flame consumes the seal, release all desire ("Does not matter, need not be").\n'
                      '5. Scatter or bury the ashes. Turn away immediately and banish with laughter or grounding.',
                      style: const pw.TextStyle(fontSize: 8.5, height: 1.4, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Invoke system native print spooler
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'IGNOSIS_Sigil_Print_Sheet',
    );
  }
}
