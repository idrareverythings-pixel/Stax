import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Runs OCR entirely on-device (no server round-trip — matches the plan's
/// privacy commitment) and returns both the raw recognized text and a new
/// PDF with an invisible, selectable text layer stamped over each page
/// image, the same trick Acrobat's "searchable PDF" uses.
class OcrService {
  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Recognizes text in a single rendered page image (PNG/JPEG bytes,
  /// typically produced by pdfrx's page-to-image rendering).
  static Future<RecognizedText> recognizePageImage(Uint8List imageBytes) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/ocr_page_${DateTime.now().microsecondsSinceEpoch}.png');
    await tempFile.writeAsBytes(imageBytes);
    try {
      final inputImage = InputImage.fromFile(tempFile);
      return await _recognizer.processImage(inputImage);
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  /// Given a source PDF and pre-rendered page images (one per page, at a
  /// known scale), builds a new PDF where each page is the original image
  /// with an invisible text layer positioned over each recognized word's
  /// bounding box — so the result is searchable/copyable but looks
  /// identical to the scan.
  static Future<Uint8List> makeSearchable({
    required List<Uint8List> pageImages,
    required double renderScale,
  }) async {
    final doc = PdfDocument();
    try {
      for (final imageBytes in pageImages) {
        final recognized = await recognizePageImage(imageBytes);
        final image = PdfBitmap(imageBytes);
        final page = doc.pages.add();
        final pageSize = page.getClientSize();

        page.graphics.drawImage(
          image,
          Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
        );

        // Transparent text render mode: text exists for search/selection
        // but is not visibly drawn over the image.
        final invisibleFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
        for (final block in recognized.blocks) {
          for (final line in block.lines) {
            final box = line.boundingBox;
            final scaledRect = Rect.fromLTWH(
              box.left / renderScale,
              box.top / renderScale,
              box.width / renderScale,
              box.height / renderScale,
            );
            page.graphics.drawString(
              line.text,
              invisibleFont,
              bounds: scaledRect,
              brush: PdfBrushes.transparent,
            );
          }
        }
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  static void dispose() => _recognizer.close();
}
