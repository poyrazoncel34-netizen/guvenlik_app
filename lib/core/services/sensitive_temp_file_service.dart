import 'dart:io';

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
    } catch (_) {}
  }

  static Future<void> delete(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
