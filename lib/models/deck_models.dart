import 'dart:typed_data';

/// One PDF the user has loaded into the workspace.
class SourceFile {
  final String id;
  final String name;
  final Uint8List bytes;
  final int pageCount;

  SourceFile({
    required this.id,
    required this.name,
    required this.bytes,
    required this.pageCount,
  });
}

/// One page sitting in "the deck" — the flat, reorderable grid that spans
/// every loaded file. This mirrors the web prototype's `pages[]` array
/// exactly so the mental model transfers between platforms.
class DeckPage {
  final String id;
  final String fileId;
  final String fileName;
  final int pageIndex; // 0-based index into the *original* source file
  int rotation; // 0, 90, 180, 270 — additive, applied on export
  bool selected;

  DeckPage({
    required this.id,
    required this.fileId,
    required this.fileName,
    required this.pageIndex,
    this.rotation = 0,
    this.selected = false,
  });

  DeckPage copyWith({int? rotation, bool? selected}) => DeckPage(
        id: id,
        fileId: fileId,
        fileName: fileName,
        pageIndex: pageIndex,
        rotation: rotation ?? this.rotation,
        selected: selected ?? this.selected,
      );
}
