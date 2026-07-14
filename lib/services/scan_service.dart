import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:ui' show Rect;

/// Handles the "scan-to-PDF" flow: capture a document photo, clean it up,
/// and assemble one or more scans into a single PDF.
///
/// NOTE: true automatic edge-detection + perspective correction (like
/// CamScanner) needs a native computer-vision library — this is normally
/// done with `opencv_dart` or a platform channel to ML Kit's Document
/// Scanner API on Android. That integration is flagged in the README as
/// the one Phase-2 item that needs a native dependency spike before
/// launch; here we implement manual crop + contrast/brightness cleanup,
/// which already gets most of the perceived quality.
class ScanService {
  static Future<bool> ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<CameraController> initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      backCamera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    await controller.initialize();
    return controller;
  }

  /// Captures a frame, then applies a "document mode" cleanup pass:
  /// grayscale-ish contrast boost + user-adjustable manual crop rect
  /// (expressed in 0..1 fractions of the image, matching an on-screen
  /// crop overlay).
  static Future<Uint8List> captureAndClean(
    CameraController controller, {
    Rect? cropFraction,
  }) async {
    final XFile file = await controller.takePicture();
    final bytes = await File(file.path).readAsBytes();
    var decoded = img.decodeImage(bytes)!;

    if (cropFraction != null) {
      final x = (cropFraction.left * decoded.width).round();
      final y = (cropFraction.top * decoded.height).round();
      final w = (cropFraction.width * decoded.width).round();
      final h = (cropFraction.height * decoded.height).round();
      decoded = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    }

    // "Document mode": punch up contrast and brightness so photographed
    // paper reads closer to a flatbed scan.
    decoded = img.adjustColor(decoded, contrast: 1.25, brightness: 1.05, saturation: 0.85);

    return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
  }

  /// Assembles one or more cleaned scan images into a single PDF, one
  /// image per page, sized to standard A4/Letter-ish proportions.
  static Future<Uint8List> scansToPdf(List<Uint8List> scanImages) async {
    final doc = PdfDocument();
    try {
      for (final bytes in scanImages) {
        final image = PdfBitmap(bytes);
        final page = doc.pages.add();
        final size = page.getClientSize();
        page.graphics.drawImage(image, Rect.fromLTWH(0, 0, size.width, size.height));
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  static Future<File> saveTemp(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    return file.writeAsBytes(bytes, flush: true);
  }
}
