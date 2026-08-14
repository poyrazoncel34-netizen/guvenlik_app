// MP-31-010 -- an imported avatar must reach app storage as pixels only.
//
// The fixtures are BUILT here rather than checked in as binaries, so the exact
// metadata each one carries is visible in this file and cannot drift away from
// what the assertions claim. Every "absent" assertion re-parses the produced
// bytes with the same decoder that wrote them; nothing is asserted about the
// sanitiser's intentions, only about the artifact it emitted.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/image_sanitizer_service.dart';
import 'package:image/image.dart' as img;

import 'exif_fixture.dart';

/// Every metadata key that must not survive. Deliberately wider than "GPS":
/// altitude, timestamps, make/model and software locate a person too.
const _prohibitedTags = <String>[
  'GPSLatitude',
  'GPSLongitude',
  'GPSLatitudeRef',
  'GPSLongitudeRef',
  'GPSAltitude',
  'GPSTimeStamp',
  'GPSDateStamp',
  'DateTime',
  'DateTimeOriginal',
  'DateTimeDigitized',
  'Make',
  'Model',
  'Software',
  'Artist',
  'Copyright',
  'UserComment',
  'ImageDescription',
  'BodySerialNumber',
  'LensModel',
];

/// A photo-like source: an asymmetric pattern so a rotation is detectable, and
/// a full set of hostile metadata spliced in as a real APP1 segment.
Uint8List _fixtureWithMetadata({int orientation = 1}) {
  final image = img.Image(width: 60, height: 40);
  // Left half red, right half blue; top quarter green. Any rotation moves them.
  img.fill(image, color: img.ColorRgb8(200, 30, 30));
  img.fillRect(image, x1: 30, y1: 0, x2: 59, y2: 39,
      color: img.ColorRgb8(30, 30, 200));
  img.fillRect(image, x1: 0, y1: 0, x2: 59, y2: 9,
      color: img.ColorRgb8(30, 200, 30));
  return withExif(
    Uint8List.fromList(img.encodeJpg(image, quality: 95)),
    orientation: orientation,
  );
}

/// A PNG carrying text chunks, which EXIF stripping alone would never touch.
Uint8List _pngFixtureWithTextChunks() {
  final image = img.Image(width: 30, height: 20);
  img.fill(image, color: img.ColorRgb8(90, 140, 190));
  image.textData = <String, String>{
    'Comment': 'a PNG text chunk with a location: 41.0139 N, 28.9790 E',
    'Author': ExifFixtureContent.artist,
  };
  return Uint8List.fromList(img.encodePng(image));
}

/// Tag id -> canonical EXIF tag name, so assertions can name tags rather than
/// magic numbers. Built by inverting the package's own table.
final Map<int, String> _tagNames = <int, String>{
  for (final entry in img.exifTagNameToID.entries) entry.value: entry.key,
};

/// Every tag NAME and every stringified VALUE held anywhere in a decoded
/// image's metadata, across all five IFDs plus PNG text chunks.
List<String> _metadataStrings(img.Image image) {
  final values = <String>[];
  for (final ifd in <img.IfdDirectory>[
    image.exif.imageIfd,
    image.exif.gpsIfd,
    image.exif.exifIfd,
    image.exif.interopIfd,
    image.exif.thumbnailIfd,
  ]) {
    for (final key in ifd.keys) {
      values.add(_tagNames[key] ?? 'tag_$key');
      values.add(ifd[key].toString());
    }
  }
  image.textData?.forEach((k, v) {
    values
      ..add(k)
      ..add(v);
  });
  return values;
}

void main() {
  group('the fixture actually carries what the test claims', () {
    // A sanitiser test whose fixture has no metadata proves nothing. This is
    // the harness precondition, and it is the first thing to check.
    test('the JPEG fixture carries GPS, device and timestamp metadata', () {
      final decoded = img.decodeImage(_fixtureWithMetadata())!;
      final strings = _metadataStrings(decoded);
      for (final tag in <String>[
        'GPSLatitude',
        'GPSLongitude',
        'Make',
        'Model',
        'Software',
        'DateTime',
      ]) {
        expect(strings, contains(tag),
            reason: 'fixture lost $tag; the absence assertions would be vacuous');
      }
      expect(strings.join(' '), contains('Pixelish 9 Pro'));
    });

    test('the PNG fixture carries text chunks', () {
      final decoded = img.decodeImage(_pngFixtureWithTextChunks())!;
      expect(decoded.textData, isNotNull);
      expect(_metadataStrings(decoded).join(' '), contains('28.9790'));
    });
  });

  group('sanitised output', () {
    test('carries none of the prohibited tags, re-parsed from the bytes', () {
      final result = ImageSanitizerService.sanitize(_fixtureWithMetadata())!;
      final reparsed = img.decodeImage(result.bytes)!;
      final strings = _metadataStrings(reparsed);
      for (final tag in _prohibitedTags) {
        expect(strings, isNot(contains(tag)), reason: '$tag survived');
      }
    });

    test('carries no metadata VALUES either, not merely no tag names', () {
      final result = ImageSanitizerService.sanitize(_fixtureWithMetadata())!;
      final joined = _metadataStrings(img.decodeImage(result.bytes)!).join(' ');
      for (final value in <String>[
        'ACME Phone Co',
        'Pixelish 9 Pro',
        'KoruBeniTestFixture',
        'Test Subject',
        '2026:08:15',
        'private note',
        'a photo taken at home',
      ]) {
        expect(joined, isNot(contains(value)), reason: '$value survived');
      }
    });

    test('the raw byte stream contains no metadata string', () {
      // Stronger than decoding: a tag the decoder does not surface would still
      // be sitting in the file. Scan the bytes themselves.
      final result = ImageSanitizerService.sanitize(_fixtureWithMetadata())!;
      final asLatin1 = String.fromCharCodes(result.bytes);
      for (final value in <String>[
        'ACME Phone Co',
        'Pixelish 9 Pro',
        'Test Subject',
        'private note',
        'GPSLatitude',
      ]) {
        expect(asLatin1, isNot(contains(value)),
            reason: '$value is still present in the stored bytes');
      }
    });

    test('PNG text chunks do not survive either', () {
      final result =
          ImageSanitizerService.sanitize(_pngFixtureWithTextChunks())!;
      final reparsed = img.decodeImage(result.bytes)!;
      expect(reparsed.textData ?? const <String, String>{}, isEmpty);
      expect(String.fromCharCodes(result.bytes), isNot(contains('28.9790')));
    });

    test('undecodable input stores NOTHING rather than falling back', () {
      final garbage = Uint8List.fromList(List<int>.generate(512, (i) => i % 256));
      expect(ImageSanitizerService.sanitize(garbage), isNull);
    });
  });

  group('pixels and orientation are preserved, not sacrificed', () {
    test('an unrotated image keeps its geometry and its colours', () {
      final result = ImageSanitizerService.sanitize(_fixtureWithMetadata())!;
      expect(result.width, 60);
      expect(result.height, 40);
      expect(result.sourceOrientation, 1);

      final out = img.decodeImage(result.bytes)!;
      // Sample well inside each region so JPEG ringing at the borders cannot
      // decide the test.
      final green = out.getPixel(30, 4);
      final red = out.getPixel(10, 30);
      final blue = out.getPixel(50, 30);
      expect(green.g, greaterThan(green.r));
      expect(green.g, greaterThan(green.b));
      expect(red.r, greaterThan(red.b));
      expect(blue.b, greaterThan(blue.r));
    });

    test('EXIF orientation 6 is applied to the PIXELS, not dropped', () {
      // Orientation 6 = rotate 90 CW on display. A sanitiser that merely
      // deletes the tag would leave every portrait photo lying on its side.
      final result =
          ImageSanitizerService.sanitize(_fixtureWithMetadata(orientation: 6))!;
      expect(result.sourceOrientation, 6);
      expect(result.width, 40, reason: 'a 60x40 source rotates to 40x60');
      expect(result.height, 60);

      final out = img.decodeImage(result.bytes)!;
      // The green band ran across the TOP; after 90 CW it runs down the RIGHT.
      final right = out.getPixel(36, 30);
      expect(right.g, greaterThan(right.r));
      expect(right.g, greaterThan(right.b));
      // And the re-parsed file must not carry an orientation tag that would
      // rotate it a second time.
      final orientation = out.exif.imageIfd['Orientation']?.toInt() ?? 1;
      expect(orientation, 1);
    });

    test('a large source is bounded, and aspect ratio is kept', () {
      final big = img.Image(width: 2000, height: 1000);
      img.fill(big, color: img.ColorRgb8(120, 120, 120));
      final result = ImageSanitizerService.sanitize(
        Uint8List.fromList(img.encodeJpg(big)),
      )!;
      expect(result.wasResized, isTrue);
      expect(result.width, ImageSanitizerService.maxDimension);
      expect(result.height, ImageSanitizerService.maxDimension ~/ 2);
    });

    test('a transparent PNG composites over white, not black', () {
      final transparent = img.Image(width: 20, height: 20, numChannels: 4);
      img.fill(transparent, color: img.ColorRgba8(0, 0, 0, 0));
      final result = ImageSanitizerService.sanitize(
        Uint8List.fromList(img.encodePng(transparent)),
      )!;
      final pixel = img.decodeImage(result.bytes)!.getPixel(10, 10);
      expect(pixel.r, greaterThan(240));
      expect(pixel.g, greaterThan(240));
      expect(pixel.b, greaterThan(240));
    });
  });

  group('negative control', () {
    test('the pre-fix implementation -- a byte copy -- IS caught', () {
      // Reproduce exactly what fake_call_screen.dart did before this change:
      // hand the source bytes through unchanged. If the assertions above can be
      // satisfied by that, they prove nothing.
      final source = _fixtureWithMetadata();
      final asLatin1 = String.fromCharCodes(source);
      expect(asLatin1, contains('Pixelish 9 Pro'),
          reason: 'byte copy preserves the device model');
      final strings = _metadataStrings(img.decodeImage(source)!);
      expect(strings, contains('GPSLatitude'),
          reason: 'byte copy preserves GPS coordinates');
    });

    test('a GPS-only strip would NOT satisfy this suite', () {
      // The other tempting shortcut: delete the GPS IFD and keep going.
      final decoded = img.decodeImage(_fixtureWithMetadata())!;
      for (final key in decoded.exif.gpsIfd.keys.toList()) {
        decoded.exif.gpsIfd[key] = null;
      }
      final stripped = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
      final strings = _metadataStrings(img.decodeImage(stripped)!);
      expect(strings, contains('Model'),
          reason: 'GPS-only stripping leaves the device model behind, which is '
              'why this row is not closed by deleting two tags');
    });
  });
}
