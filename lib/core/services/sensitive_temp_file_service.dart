import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Owns short-lived files that can contain user PII. Cleanup is best effort;
/// reset still removes the whole app temp directory as a second line of defense.
class SensitiveTempFileService {
  SensitiveTempFileService._();

  static const String exportPrefix = 'korubeni_data_export_';
  static const String legacyExportName = 'korubeni_verilerim.json';

  static Future<void> purgeStaleExports() async {
    try {
      final directory = await getTemporaryDirectory();
      await purgeStaleExportsInDirectory(directory);
    } catch (_) {}
  }

  @visibleForTesting
  static Future<void> purgeStaleExportsInDirectory(Directory directory) async {
    try {
      if (!await directory.exists()) return;
      await _purgeMatchingFiles(directory);
      // share_plus copies XFiles into this cache directory before launching
      // Android's Sharesheet. The source file is deleted in the export
      // surface's finally block, but the plugin-owned copy otherwise retains
      // the same PII after the chooser returns.
      final sharePlusDirectory = Directory('${directory.path}/share_plus');
      await _purgeMatchingFiles(sharePlusDirectory);
    } catch (_) {}
  }

  static Future<void> delete(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    try {
      final sharePlusCopy = File(
        '${file.parent.path}/share_plus/${file.uri.pathSegments.last}',
      );
      if (await sharePlusCopy.exists()) await sharePlusCopy.delete();
    } catch (_) {}
  }

  static Future<void> _purgeMatchingFiles(Directory directory) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name == legacyExportName ||
          (name.startsWith(exportPrefix) && name.endsWith('.json'))) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}
