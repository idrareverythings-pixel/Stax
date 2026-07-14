import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/scan_service.dart';
import '../theme/app_theme.dart';

/// Multi-shot document scanner: capture pages one at a time, adjust a
/// manual crop rectangle per shot, review the stack, then hand the
/// finished PDF bytes back to whoever pushed this screen (see
/// HomeScreen._startScan).
///
/// See the caveat in scan_service.dart: automatic edge detection is a
/// Phase-2 native integration, not implemented here.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  final List<Uint8List> _captured = [];
  bool _ready = false;
  bool _busy = false;

  // Manual crop overlay, expressed as 0..1 fractions of the frame.
  Rect _cropFraction = const Rect.fromLTWH(0.06, 0.12, 0.88, 0.76);

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final granted = await ScanService.ensureCameraPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to scan documents')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    final controller = await ScanService.initCamera();
    if (!mounted) return;
    setState(() {
      _controller = controller;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || _busy) return;
    setState(() => _busy = true);
    try {
      final cleaned = await ScanService.captureAndClean(_controller!, cropFraction: _cropFraction);
      setState(() => _captured.add(cleaned));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_captured.isEmpty) return;
    setState(() => _busy = true);
    final pdfBytes = await ScanService.scansToPdf(_captured);
    if (mounted) Navigator.of(context).pop(pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan document · ${_captured.length} page${_captured.length == 1 ? '' : 's'}'),
      ),
      body: !_ready || _controller == null
          ? const Center(child: CircularProgressIndicator(color: StaxColors.teal))
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller!),
                      // Crop guide overlay — draggable corners would be
                      // the natural next step; kept as a fixed guide here
                      // to keep this file focused.
                      _CropGuide(fraction: _cropFraction),
                    ],
                  ),
                ),
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 64,
                        child: _captured.isEmpty
                            ? null
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white),
                                      borderRadius: BorderRadius.circular(6),
                                      image: DecorationImage(
                                        image: MemoryImage(_captured.last),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      GestureDetector(
                        onTap: _busy ? null : _capture,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: StaxColors.teal, width: 3),
                          ),
                          child: _busy
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                        ),
                      ),
                      TextButton(
                        onPressed: _captured.isEmpty || _busy ? null : _finish,
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: _captured.isEmpty ? Colors.white38 : StaxColors.tealDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CropGuide extends StatelessWidget {
  final Rect fraction;
  const _CropGuide({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rect = Rect.fromLTWH(
          fraction.left * constraints.maxWidth,
          fraction.top * constraints.maxHeight,
          fraction.width * constraints.maxWidth,
          fraction.height * constraints.maxHeight,
        );
        return IgnorePointer(
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _CropPainter(rect),
          ),
        );
      },
    );
  }
}

class _CropPainter extends CustomPainter {
  final Rect rect;
  _CropPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRect(rect);
    canvas.drawPath(Path.combine(PathOperation.difference, full, hole), overlay);

    final border = Paint()
      ..color = StaxColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) => oldDelegate.rect != rect;
}
