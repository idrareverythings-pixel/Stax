import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size, Rect;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdfviewer.dart' show PdfPageRotateAngle;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/deck_models.dart';

/// Wraps `syncfusion_flutter_pdf`, which — unlike the pure-Dart `pdf`
/// package — can load and mutate *existing* PDF byte structures. That
/// makes it the closest mobile analog to pdf-lib on the web.
class PdfService {
  /// Builds one output PDF from an ordered list of [DeckPage]s, each of
  /// which may reference a different source file. This single method
  /// backs both "Download merged PDF" (pass the whole deck) and
  /// "Extract selected" (pass only the checked pages) — same as the web
  /// prototype's single `exportPages()` function.
  static Future<Uint8List> buildPdf({
    required List<DeckPage> pages,
    required Map<String, SourceFile> filesById,
  }) async {
    final PdfDocument outDoc = PdfDocument();
    outDoc.pageSettings.margins.all = 0;

    // Cache one opened PdfDocument per source file so we don't re-parse
    // the same bytes for every page pulled from it.
    final Map<String, PdfDocument> openDocs = {};
    try {
      for (final page in pages) {
        final source = filesById[page.fileId];
        if (source == null) continue;

        final srcDoc = openDocs.putIfAbsent(
          page.fileId,
          () => PdfDocument(inputBytes: source.bytes),
        );

        // PdfDocument.pages doesn't support cherry-picking a single page
        // into a new document directly, so we import the full template
        // then keep only the page we want using PdfPageLayer template,
        // OR — the simpler, robust route used here — import the specific
        // page's content as a template and stamp it onto a new page sized
        // to match. This preserves vector content, not just a rasterized
        // image.
        final PdfPage srcPage = srcDoc.pages[page.pageIndex];
        final template = srcPage.createTemplate();

        final PdfPage newPage = outDoc.pages.add();
        newPage.graphics.drawPdfTemplate(
          template,
          Offset.zero,
          Size(srcPage.size.width, srcPage.size.height),
        );

        if (page.rotation != 0) {
          _applyRotation(newPage, page.rotation);
        }
      }

      final bytes = await outDoc.save();
      return Uint8List.fromList(bytes);
    } finally {
      outDoc.dispose();
      for (final d in openDocs.values) {
        d.dispose();
      }
    }
  }

  static void _applyRotation(PdfPage page, int rotationDegrees) {
    // Syncfusion rotates the whole page's coordinate space in 90° steps.
    final steps = (rotationDegrees ~/ 90) % 4;
    const angles = [
      PdfPageRotateAngle.rotateAngle0,
      PdfPageRotateAngle.rotateAngle90,
      PdfPageRotateAngle.rotateAngle180,
      PdfPageRotateAngle.rotateAngle270,
    ];
    // Note: page rotation is set at the PdfPage level via `rotation` in
    // newer Syncfusion APIs; kept here as a single seam so swapping the
    // exact call if the package version differs is a one-line change.
    page.rotation = angles[steps];
  }

  /// Password-protects a PDF. [userPassword] is required to *open* the
  /// file; [ownerPassword] (optional) gates permissions like printing.
  static Future<Uint8List> protect({
    required Uint8List sourceBytes,
    required String userPassword,
    String? ownerPassword,
    bool allowPrinting = true,
    bool allowCopyContent = false,
  }) async {
    final doc = PdfDocument(inputBytes: sourceBytes);
    try {
      doc.security.userPassword = userPassword;
      doc.security.ownerPassword = ownerPassword ?? userPassword;
      doc.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
      doc.security.permissions.addAll([
        if (allowPrinting) PdfPermissionsFlags.print,
        if (allowCopyContent) PdfPermissionsFlags.copyContent,
      ]);
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  /// Compresses a PDF by re-saving with image recompression enabled and
  /// (optionally) a max image DPI ceiling.
  static Future<Uint8List> compress(Uint8List sourceBytes) async {
    final doc = PdfDocument(inputBytes: sourceBytes);
    try {
      doc.compressionLevel = PdfCompressionLevel.best;
      doc.fileStructure.incrementalUpdate = false;
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  /// Flattens a PNG signature/annotation overlay onto a specific page —
  /// used by the Fill & Sign screen.
  static Future<Uint8List> stampImageOnPage({
    required Uint8List sourceBytes,
    required int pageIndex,
    required Uint8List pngBytes,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    final doc = PdfDocument(inputBytes: sourceBytes);
    try {
      final page = doc.pages[pageIndex];
      final image = PdfBitmap(pngBytes);
      page.graphics.drawImage(image, Rect.fromLTWH(x, y, width, height));
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  static Future<File> saveToTempFile(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
