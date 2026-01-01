/// Archive extraction utilities.
library;

import 'dart:io';

import 'package:archive/archive.dart';

/// Handles extraction of package archives.
class ArchiveHandler {
  /// Extracts a .tar.gz archive to the specified directory.
  Future<void> extract(String archivePath, String outputDir) async {
    final file = File(archivePath);
    if (!file.existsSync()) {
      throw StateError('Archive not found: $archivePath');
    }

    final bytes = await file.readAsBytes();
    final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));

    final outDir = Directory(outputDir);
    if (outDir.existsSync()) {
      await outDir.delete(recursive: true);
    }
    await outDir.create(recursive: true);

    for (final entry in archive) {
      final path = '$outputDir/${entry.name}';
      if (entry.isFile) {
        final outFile = File(path);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>);
      } else {
        await Directory(path).create(recursive: true);
      }
    }
  }
}
