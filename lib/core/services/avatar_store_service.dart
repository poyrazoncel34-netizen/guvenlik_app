import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'image_sanitizer_service.dart';

/// Owns the ONE file the fake-call avatar may occupy on disk.
///
/// The import boundary for MP-31-010. Every path that puts a user-selected
/// image into app storage goes through [importFromFile], and that method never
/// writes source bytes — only the derivative [ImageSanitizerService] produced.
/// Keeping the write in one service is what makes that claim checkable: a
/// verifier can assert that `File.copy` appears nowhere in the image path.
class AvatarStoreService {
  AvatarStoreService({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  static final AvatarStoreService instance = AvatarStoreService();

  final Future<Directory> Function() _documentsDirectory;

  /// The canonical name. One name, so a second import cannot leave the previous
  /// (possibly unsanitised, possibly differently-extensioned) file behind.
  static const String fileBaseName = 'fake_call_avatar';

  /// Names earlier builds could have written, which may still hold source
  /// bytes with their original metadata intact.
  static const List<String> legacyExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
    'webp',
    'gif',
    'bmp',
  ];

  String get fileName => '$fileBaseName.${ImageSanitizerService.extension}';

  /// Sanitises [sourcePath] and stores the derivative. Returns its path, or
  /// null when the source could not be decoded — in which case NOTHING is
  /// stored. Falling back to a byte copy would reinstate the defect.
  Future<String?> importFromFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final bytes = await source.readAsBytes();
    return importFromBytes(bytes);
  }

  Future<String?> importFromBytes(Uint8List bytes) async {
    // Decoding a full-resolution phone photo is tens of milliseconds of pure
    // Dart; off the UI isolate so the picker sheet does not jank on return.
    final sanitized = await compute(ImageSanitizerService.sanitize, bytes);
    if (sanitized == null) return null;

    final dir = await _documentsDirectory();
    await _deleteLegacyFiles(dir);
    final target = File('${dir.path}/$fileName');
    await target.writeAsBytes(sanitized.bytes, flush: true);
    return target.path;
  }

  /// Re-sanitises an avatar written by a build that predates this service.
  ///
  /// Fixing the import boundary alone would leave the metadata of everyone who
  /// already picked a photo sitting in app documents — and in the file the KVKK
  /// export names. Returns the path to use.
  Future<String?> sanitizeExisting(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    if (path.endsWith('/$fileName')) {
      // Already the canonical derivative name. Re-encoding on every launch
      // would degrade the image for no gain.
      return path;
    }
    return importFromBytes(await file.readAsBytes());
  }

  Future<void> delete() async {
    final dir = await _documentsDirectory();
    await _deleteLegacyFiles(dir);
    final target = File('${dir.path}/$fileName');
    if (await target.exists()) await target.delete();
  }

  Future<void> _deleteLegacyFiles(Directory dir) async {
    for (final ext in legacyExtensions) {
      if (ext == ImageSanitizerService.extension) continue;
      final legacy = File('${dir.path}/$fileBaseName.$ext');
      if (await legacy.exists()) await legacy.delete();
    }
  }
}
