import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/deck_models.dart';
import '../theme/app_theme.dart';

/// Renders one page of a [SourceFile] as an image using pdfrx, which
/// binds to PDFium — the same rendering engine Chrome and Acrobat use,
/// so thumbnails and full-page previews match pixel-for-pixel what the
/// exported PDF will look like.
class PageThumbnail extends StatefulWidget {
  final SourceFile source;
  final DeckPage page;

  const PageThumbnail({super.key, required this.source, required this.page});

  @override
  State<PageThumbnail> createState() => _PageThumbnailState();
}

class _PageThumbnailState extends State<PageThumbnail> {
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    final doc = await PdfDocument.openData(widget.source.bytes);
    final page = doc.pages[widget.page.pageIndex];

    // Render at a modest scale for grid thumbnails; the full editor /
    // sign screen re-renders at a higher scale on demand.
    final image = await page.render(
      fullWidth: page.width * 0.5,
      fullHeight: page.height * 0.5,
    );
    final bytes = await image?.createImageIfNotAvailable() != null
        ? await image!.encodePng()
        : null;
    await doc.dispose();

    if (mounted) setState(() => _imageBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final rotation = widget.page.rotation;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        color: Theme.of(context).dividerColor,
        child: _imageBytes == null
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: StaxColors.teal),
                ),
              )
            : RotatedBox(
                quarterTurns: rotation ~/ 90,
                child: Image.memory(_imageBytes!, fit: BoxFit.contain),
              ),
      ),
    );
  }
}
