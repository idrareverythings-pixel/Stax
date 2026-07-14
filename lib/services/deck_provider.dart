import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/deck_models.dart';
import 'pdf_service.dart';

/// Single source of truth for "the deck" — the flat, reorderable list of
/// pages spanning every loaded file. Every screen (deck grid, sign,
/// password, export sheet) reads and mutates through this provider so the
/// app-wide model stays identical to the web prototype's `pages[]` +
/// `files[]` arrays.
class DeckProvider extends ChangeNotifier {
  final List<SourceFile> files = [];
  final List<DeckPage> pages = [];
  int _idCounter = 0;

  int get selectedCount => pages.where((p) => p.selected).length;
  bool get isEmpty => files.isEmpty;

  Future<void> addFile(String name, Uint8List bytes) async {
    final doc = await PdfDocument.openData(bytes);
    final fileId = 'f${_idCounter++}';
    files.add(SourceFile(id: fileId, name: name, bytes: bytes, pageCount: doc.pages.length));

    for (int i = 0; i < doc.pages.length; i++) {
      pages.add(DeckPage(
        id: 'p${_idCounter++}',
        fileId: fileId,
        fileName: name,
        pageIndex: i,
      ));
    }
    await doc.dispose();
    notifyListeners();
  }

  void removeFile(String fileId) {
    files.removeWhere((f) => f.id == fileId);
    pages.removeWhere((p) => p.fileId == fileId);
    notifyListeners();
  }

  void removePage(String pageId) {
    pages.removeWhere((p) => p.id == pageId);
    notifyListeners();
  }

  void toggleSelected(String pageId) {
    final page = pages.firstWhere((p) => p.id == pageId);
    page.selected = !page.selected;
    notifyListeners();
  }

  void rotate(String pageId) {
    final page = pages.firstWhere((p) => p.id == pageId);
    page.rotation = (page.rotation + 90) % 360;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final page = pages.removeAt(oldIndex);
    pages.insert(newIndex, page);
    notifyListeners();
  }

  void reset() {
    files.clear();
    pages.clear();
    notifyListeners();
  }

  Map<String, SourceFile> get _filesById => {for (final f in files) f.id: f};

  Future<Uint8List> exportMerged() =>
      PdfService.buildPdf(pages: pages, filesById: _filesById);

  Future<Uint8List> exportSelected() => PdfService.buildPdf(
        pages: pages.where((p) => p.selected).toList(),
        filesById: _filesById,
      );
}
