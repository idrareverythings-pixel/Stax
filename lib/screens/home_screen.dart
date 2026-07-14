import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/deck_provider.dart';
import '../theme/app_theme.dart';
import 'deck_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final deck = context.read<DeckProvider>();
    for (final f in result.files) {
      if (f.bytes != null) {
        await deck.addFile(f.name, f.bytes!);
      }
    }
    if (context.mounted && deck.pages.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DeckScreen()),
      );
    }
  }

  Future<void> _startScan(BuildContext context) async {
    final scannedPdf = await Navigator.of(context).push<List<int>>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (scannedPdf != null && context.mounted) {
      final deck = context.read<DeckProvider>();
      await deck.addFile(
        'Scan ${DateTime.now().toLocal().toString().substring(0, 16)}.pdf',
        Uint8List.fromList(scannedPdf),
      );
      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeckScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _StackMark(),
            const SizedBox(width: 10),
            Text('Stax', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
            _Tag('pdf toolkit'),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FannedStackIcon(),
              const SizedBox(height: 22),
              Text('Drop your PDFs into the deck', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Merge, reorder, rotate, sign, and secure — all on this device.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _pickFiles(context),
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('Choose files'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _startScan(context),
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: const Text('Scan a document'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.layers_outlined, color: StaxColors.indigo, size: 22);
  }
}

class _Tag extends StatelessWidget {
  final String label;
  _Tag(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _FannedStackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(angle: -0.14, child: _sheet(context, StaxColors.indigoSoft)),
          Transform.rotate(angle: 0.08, child: _sheet(context, Theme.of(context).cardColor)),
          _sheet(context, Theme.of(context).cardColor, filled: true),
        ],
      ),
    );
  }

  Widget _sheet(BuildContext context, Color color, {bool filled = false}) {
    return Container(
      width: 52,
      height: 64,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StaxColors.indigo, width: 1.4),
      ),
    );
  }
}
