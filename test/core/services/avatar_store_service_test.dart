// MP-31-010 -- the IMPORT BOUNDARY, not just the sanitiser.
//
// image_sanitizer_service_test.dart proves the derivative is clean. This file
// proves the clean derivative is the only thing that ever reaches app storage,
// that a pre-existing (unsanitised) avatar is repaired rather than left in
// place, and that the file the KVKK export names is the sanitised one.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/avatar_store_service.dart';
import 'package:guvenlik_app/core/services/image_sanitizer_service.dart';
import 'package:image/image.dart' as img;

import 'exif_fixture.dart';

Uint8List _photoWithMetadata({int orientation = 1}) {
  final image = img.Image(width: 48, height: 32);
  img.fill(image, color: img.ColorRgb8(180, 60, 60));
  img.fillRect(image, x1: 0, y1: 0, x2: 47, y2: 7,
      color: img.ColorRgb8(40, 200, 90));
  return withExif(
    Uint8List.fromList(img.encodeJpg(image, quality: 95)),
    orientation: orientation,
  );
}

void main() {
  late Directory documents;
  late AvatarStoreService store;

  setUp(() {
    documents = Directory.systemTemp.createTempSync('korubeni_avatar_test');
    store = AvatarStoreService(documentsDirectory: () async => documents);
  });

  tearDown(() {
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  /// Every metadata literal the fixture carries, searched in the stored file.
  void assertStoredFileIsClean(String path) {
    final stored = File(path).readAsBytesSync();
    final asLatin1 = String.fromCharCodes(stored);
    for (final value in ExifFixtureContent.forbiddenStrings) {
      expect(asLatin1, isNot(contains(value)),
          reason: '$value survived into $path');
    }
    expect(ImageSanitizerService.readSourceOrientation(stored), 1,
        reason: 'the stored derivative must not carry an orientation tag that '
            'would rotate already-upright pixels a second time');
    expect(img.decodeImage(stored), isNotNull,
        reason: 'the stored file must still be a valid image');
  }

  test('an imported photo is stored sanitised, under the canonical name',
      () async {
    final source = File('${documents.path}/source.jpg')
      ..writeAsBytesSync(_photoWithMetadata());

    // Precondition: the SOURCE really does carry the metadata.
    expect(String.fromCharCodes(source.readAsBytesSync()),
        contains(ExifFixtureContent.model));

    final saved = await store.importFromBytes(source.readAsBytesSync());
    expect(saved, isNotNull);
    expect(saved, endsWith('/fake_call_avatar.jpg'));
    assertStoredFileIsClean(saved!);
  });

  test('a byte copy of the same source would FAIL this assertion', () async {
    // The negative control for the boundary: reproduce the pre-fix behaviour
    // (File.copy) and show the check catches it. Without this, "the stored file
    // is clean" could be true for reasons having nothing to do with the fix.
    final target = File('${documents.path}/fake_call_avatar.jpg')
      ..writeAsBytesSync(_photoWithMetadata());
    expect(
      () => assertStoredFileIsClean(target.path),
      throwsA(isA<TestFailure>()),
    );
  });

  test('a second import leaves no earlier avatar file behind', () async {
    // A previous build wrote fake_call_avatar.png with source bytes intact.
    final legacy = File('${documents.path}/fake_call_avatar.png')
      ..writeAsBytesSync(_photoWithMetadata());
    expect(legacy.existsSync(), isTrue);

    final saved = await store.importFromBytes(_photoWithMetadata());
    expect(saved, isNotNull);
    expect(legacy.existsSync(), isFalse,
        reason: 'the unsanitised legacy file stayed on disk, where the KVKK '
            'export and any file browser can still reach it');
    expect(
      documents
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.startsWith('fake_call_avatar'))
          .toList(),
      <String>['fake_call_avatar.jpg'],
    );
  });

  test('an avatar written by an earlier build is repaired on load', () async {
    final legacy = File('${documents.path}/fake_call_avatar.heic')
      ..writeAsBytesSync(_photoWithMetadata());

    final repaired = await store.sanitizeExisting(legacy.path);
    expect(repaired, isNotNull);
    expect(repaired, endsWith('/fake_call_avatar.jpg'));
    expect(legacy.existsSync(), isFalse);
    assertStoredFileIsClean(repaired!);
  });

  test('an already-canonical avatar is not re-encoded on every load', () async {
    final saved = await store.importFromBytes(_photoWithMetadata());
    final firstBytes = File(saved!).readAsBytesSync();

    final again = await store.sanitizeExisting(saved);
    expect(again, saved);
    expect(File(saved).readAsBytesSync(), firstBytes,
        reason: 're-encoding a JPEG on every launch degrades it for no gain');
  });

  test('an undecodable source stores nothing at all', () async {
    final saved = await store.importFromBytes(
      Uint8List.fromList(List<int>.generate(400, (i) => i % 251)),
    );
    expect(saved, isNull);
    expect(
      documents
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('fake_call_avatar'))
          .toList(),
      isEmpty,
      reason: 'a decode failure must never fall back to storing source bytes',
    );
  });

  test('a rotated source is stored upright', () async {
    final saved = await store.importFromBytes(_photoWithMetadata(orientation: 6));
    final stored = img.decodeImage(File(saved!).readAsBytesSync())!;
    expect(stored.width, 32, reason: '48x32 rotated 90 CW is 32x48');
    expect(stored.height, 48);
    // The green band ran across the top; after 90 CW it runs down the right.
    final right = stored.getPixel(29, 24);
    expect(right.g, greaterThan(right.r));
  });

  test('delete removes the derivative and every legacy name', () async {
    for (final ext in AvatarStoreService.legacyExtensions) {
      File('${documents.path}/fake_call_avatar.$ext')
          .writeAsBytesSync(<int>[1, 2, 3]);
    }
    await store.delete();
    expect(
      documents
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('fake_call_avatar'))
          .toList(),
      isEmpty,
    );
  });

  _exportArtifactContract();

  group('source contract', () {
    test('no image path copies source bytes', () {
      // File.copy on a picked image IS the defect. Assert it is absent from
      // every file that touches the avatar, so a future edit cannot quietly
      // reintroduce the fast path.
      for (final path in <String>[
        'lib/screens/fake_call_screen.dart',
        'lib/core/services/avatar_store_service.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, isNot(contains('.copy(')),
            reason: '$path copies a file; the avatar must be re-encoded');
      }
    });

    test('the picker hands its result to the store, not to dart:io', () {
      final src = File('lib/screens/fake_call_screen.dart').readAsStringSync();
      final pick = src.indexOf('_imagePicker.pickImage');
      expect(pick, isNot(-1));
      final body = src.substring(pick, pick + 900);
      expect(body, contains('AvatarStoreService.instance.importFromFile'));
    });
  });
}

/// The KVKK export artifact itself (MP-31-010 asks for the artifact to be
/// inspected, not only the storage path).
///
/// `UserDataExportService` emits JSON. It never embeds image bytes — it names
/// the avatar file. That is the right shape, but it means the export's honesty
/// depends entirely on the named file being the sanitised derivative, which is
/// what these assertions pin.
void _exportArtifactContract() {
  group('KVKK export artifact', () {
    test('the export embeds no image bytes, only a file NAME', () {
      final src =
          File('lib/core/services/user_data_export_service.dart')
              .readAsStringSync();
      expect(src, contains("'avatarFileName'"));
      expect(src, contains("'hasAvatarFile'"));
      for (final embedding in <String>[
        'base64Encode',
        'readAsBytes',
        'readAsBytesSync',
      ]) {
        expect(src, isNot(contains(embedding)),
            reason: 'the export would then carry the image itself, and every '
                'guarantee would move from the file to the JSON');
      }
    });

    test('the name the export can emit is the sanitised derivative', () async {
      final documents =
          Directory.systemTemp.createTempSync('korubeni_export_test');
      addTearDown(() => documents.deleteSync(recursive: true));
      final store =
          AvatarStoreService(documentsDirectory: () async => documents);
      final saved = await store.importFromBytes(_photoWithMetadata());

      // This is the exact transformation user_data_export_service applies.
      final exported = saved!.split(Platform.pathSeparator).last;
      expect(exported, store.fileName);
      expect(exported, 'fake_call_avatar.jpg');

      final bytes = File(saved).readAsBytesSync();
      final asLatin1 = String.fromCharCodes(bytes);
      for (final value in ExifFixtureContent.forbiddenStrings) {
        expect(asLatin1, isNot(contains(value)),
            reason: 'the file the export names still carries $value');
      }
    });
  });
}
