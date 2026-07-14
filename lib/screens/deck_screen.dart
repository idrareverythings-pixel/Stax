import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/deck_models.dart';
import '../services/deck_provider.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_thumbnail.dart';
import 'sign_screen.dart';
import 'password_screen.dart';

class DeckScreen extends StatelessWidget {
  const DeckScreen({super.key});

  Future<void> _export(BuildContext context, {required bool selectedOnly}) async {
    final deck = context.read<DeckProvider>();
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(const SnackBar(content: Text('Building your PDF…')));

    try {
      final bytes = selectedOnly ? await deck.exportSelected() : await deck.exportMerged();
      final filename = selectedOnly ? 'stax-extracted.pdf' : 'stax-merged.pdf';
      final file = await PdfService.saveToTempFile(bytes, filename);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Shared from Stax',
      ));
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = context.watch<DeckProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('The deck', style: Theme.of(context).textTheme.titleMedium),
        actions: [
          IconButton(
            tooltip: 'Password protect',
            icon: const Icon(Icons.lock_outline),
            onPressed: deck.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PasswordScreen()),
                    ),
          ),
          IconButton(
            tooltip: 'Fill & sign',
            icon: const Icon(Icons.draw_outlined),
            onPressed: deck.pages.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignScreen()),
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FileBar(deck: deck),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${deck.pages.length} pages', style: Theme.of(context).textTheme.bodySmall),
                Text('Drag to reorder · tap to select', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: deck.pages.isEmpty
                ? const Center(child: Text('No pages yet'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: deck.pages.length,
                    itemBuilder: (context, index) {
                      final page = deck.pages[index];
                      final source = deck.files.firstWhere((f) => f.id == page.fileId);
                      return _DraggablePageCard(
                        key: ValueKey(page.id),
                        page: page,
                        source: source,
                        index: index,
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: deck.isEmpty ? null : () => deck.reset(),
                child: const Text('Reset'),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: deck.selectedCount == 0 ? null : () => _export(context, selectedOnly: true),
                    child: Text('Extract (${deck.selectedCount})'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: deck.pages.isEmpty ? null : () => _export(context, selectedOnly: false),
                    child: const Text('Download merged PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileBar extends StatelessWidget {
  final DeckProvider deck;
  const _FileBar({required this.deck});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final f in deck.files)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('${f.name}  ·  ${f.pageCount}p', style: const TextStyle(fontSize: 12)),
                onDeleted: () => deck.removeFile(f.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// A page card that is both a drag source and a drop target, giving the
/// same free-form reorder feel as the web prototype's HTML5 drag-and-drop
/// without pulling in a third-party reorderable-grid package.
class _DraggablePageCard extends StatelessWidget {
  final DeckPage page;
  final SourceFile source;
  final int index;

  const _DraggablePageCard({super.key, required this.page, required this.source, required this.index});

  @override
  Widget build(BuildContext context) {
    final deck = context.read<DeckProvider>();

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => deck.reorder(details.data, index),
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;
        return LongPressDraggable<int>(
          data: index,
          feedback: Opacity(
            opacity: 0.85,
            child: SizedBox(width: 120, child: _CardBody(page: page, source: source)),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: _CardBody(page: page, source: source)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isDragOver ? Border.all(color: StaxColors.teal, width: 2) : null,
            ),
            child: _CardBody(page: page, source: source),
          ),
        );
      },
    );
  }
}

class _CardBody extends StatelessWidget {
  final DeckPage page;
  final SourceFile source;
  const _CardBody({required this.page, required this.source});

  @override
  Widget build(BuildContext context) {
    final deck = context.read<DeckProvider>();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageThumbnail(source: source, page: page),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('p.${page.pageIndex + 1}', style: Theme.of(context).textTheme.labelSmall),
              ),
            ],
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => deck.toggleSelected(page.id),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: page.selected ? StaxColors.teal : Colors.black38,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 1.3),
                ),
                child: page.selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              children: [
                _miniButton(Icons.rotate_right, () => deck.rotate(page.id)),
                const SizedBox(width: 4),
                _miniButton(Icons.close, () => deck.removePage(page.id)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}
