import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:share_plus/share_plus.dart';

import '../services/deck_provider.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_thumbnail.dart';

/// Fill & sign, built on the same "one flat list of pages" model as the
/// deck screen: pick a page, draw (or reuse) a signature, position it
/// with a draggable overlay, then flatten it into that page.
class SignScreen extends StatefulWidget {
  const SignScreen({super.key});

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> {
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );

  int _selectedPageIndex = 0;
  Offset _signatureOffset = const Offset(40, 400);
  Size _signatureSize = const Size(160, 70);

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  Future<void> _openSignaturePad(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Draw your signature', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor)),
              child: Signature(controller: _sigController, height: 180),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(onPressed: () => _sigController.clear(), child: const Text('Clear')),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Use this signature'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _flattenAndShare(BuildContext context) async {
    if (_sigController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draw a signature first')),
      );
      return;
    }
    final deck = context.read<DeckProvider>();
    final page = deck.pages[_selectedPageIndex];
    final source = deck.files.firstWhere((f) => f.id == page.fileId);

    final pngBytes = await _sigController.toPngBytes();
    if (pngBytes == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Flattening signature into the page…')),
    );

    final result = await PdfService.stampImageOnPage(
      sourceBytes: source.bytes,
      pageIndex: page.pageIndex,
      pngBytes: pngBytes,
      x: _signatureOffset.dx,
      y: _signatureOffset.dy,
      width: _signatureSize.width,
      height: _signatureSize.height,
    );

    final file = await PdfService.saveToTempFile(result, 'stax-signed.pdf');
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Signed with Stax'));
  }

  @override
  Widget build(BuildContext context) {
    final deck = context.watch<DeckProvider>();
    final page = deck.pages[_selectedPageIndex];
    final source = deck.files.firstWhere((f) => f.id == page.fileId);

    return Scaffold(
      appBar: AppBar(title: const Text('Fill & sign')),
      body: Column(
        children: [
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: deck.pages.length,
              itemBuilder: (context, i) {
                final selected = i == _selectedPageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPageIndex = i),
                  child: Container(
                    width: 56,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: selected ? StaxColors.teal : Theme.of(context).dividerColor, width: selected ? 2 : 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: PageThumbnail(
                      source: deck.files.firstWhere((f) => f.id == deck.pages[i].fileId),
                      page: deck.pages[i],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.77,
                child: Stack(
                  children: [
                    Positioned.fill(child: PageThumbnail(source: source, page: page)),
                    // Draggable signature placeholder overlay — the
                    // signature is only rasterized into the real PDF on
                    // export, so repositioning here stays instant.
                    Positioned(
                      left: _signatureOffset.dx,
                      top: _signatureOffset.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() => _signatureOffset += details.delta);
                        },
                        child: Container(
                          width: _signatureSize.width,
                          height: _signatureSize.height,
                          decoration: BoxDecoration(
                            border: Border.all(color: StaxColors.teal, width: 1.5, style: BorderStyle.solid),
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          child: _sigController.isNotEmpty
                              ? FutureBuilder<Uint8List?>(
                                  future: _sigController.toPngBytes(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const SizedBox.shrink();
                                    return Image.memory(snapshot.data!, fit: BoxFit.contain);
                                  },
                                )
                              : const Center(child: Text('Signature', style: TextStyle(color: StaxColors.teal, fontSize: 12))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openSignaturePad(context),
                  icon: const Icon(Icons.draw_outlined, size: 18),
                  label: const Text('Draw signature'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _flattenAndShare(context),
                  child: const Text('Sign & share'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
