import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Result of sanitising one imported image.
class SanitizedImage {
  const SanitizedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.sourceOrientation,
    required this.wasResized,
  });

  /// The re-encoded derivative. The ONLY thing that may be written to disk.
  final Uint8List bytes;
  final int width;
  final int height;

  /// The EXIF orientation the SOURCE FILE declared (1 = upright, 1..8).
  ///
  /// Read from the source bytes, not from the decoded image: this package's
  /// JPEG decoder already applies orientation and drops the tag, so asking the
  /// decoded object would answer 1 for a photo whose file said 6. A field that
  /// reports 1 for a rotated source is a constant wearing a measurement's
  /// clothes — the defect class this evidence phase exists to remove.
  final int sourceOrientation;
  final bool wasResized;
}

/// Re-encodes a user-selected image so that nothing but pixels survives.
///
/// Why a re-encode and not "strip the GPS tags"
/// --------------------------------------------
/// Deleting GPSLatitude/GPSLongitude leaves altitude, timestamps, camera make
/// and model, the software that produced the file, user comments, maker notes
/// and XMP — several of which locate a person as effectively as coordinates do.
/// The audit (MP-31-010) found the avatar being copied byte for byte into app
/// documents with `File.copy`, which preserved all of it.
///
/// So the import boundary decodes to raw pixels, applies the source
/// orientation TO those pixels, and builds a brand-new image whose only content
/// is colour values. Nothing is inherited: not an EXIF block, not an XMP
/// packet, not a PNG text chunk — because the output object never touched the
/// input object's metadata. That is a structural guarantee rather than a
/// blocklist that a new tag can outgrow.
///
/// `image_picker`'s `imageQuality:` also re-encodes on some platform
/// implementations, which is why this defect was easy to miss. That is a
/// platform behaviour on some devices, not a guarantee this app makes.
abstract final class ImageSanitizerService {
  /// Longest edge of the stored derivative. The avatar renders in a 124 px
  /// circle; anything beyond this is memory the app never shows.
  static const int maxDimension = 512;

  /// JPEG quality of the derivative.
  static const int jpegQuality = 88;

  /// Returns a sanitised derivative, or null when [bytes] is not a decodable
  /// image. A null return must be treated as "do not store anything" — never
  /// as "store the original".
  static SanitizedImage? sanitize(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final orientation = readSourceOrientation(bytes);
    // Orientation must be applied to the PIXELS. Dropping the tag without
    // baking it would silently rotate every photo taken in portrait.
    //
    // For JPEG the decoder has already done this and removed the tag, so this
    // call is a no-op there. It is kept for the formats whose decoders do not:
    // deleting it would make the guarantee depend on which branch of the
    // decoder a user's photo happened to take.
    final upright = img.bakeOrientation(decoded);

    final longest = upright.width > upright.height
        ? upright.width
        : upright.height;
    final resized = longest > maxDimension
        ? img.copyResize(
            upright,
            width: upright.width >= upright.height ? maxDimension : null,
            height: upright.height > upright.width ? maxDimension : null,
            interpolation: img.Interpolation.average,
          )
        : upright;

    final clean = _copyPixelsOnly(resized);
    return SanitizedImage(
      bytes: Uint8List.fromList(img.encodeJpg(clean, quality: jpegQuality)),
      width: clean.width,
      height: clean.height,
      sourceOrientation: orientation,
      wasResized: !identical(resized, upright),
    );
  }

  /// The file extension the sanitised derivative must be stored under. The
  /// source extension is never reused: a `.png` holding JPEG bytes is the kind
  /// of mismatch that makes a later reader reach for the original.
  static const String extension = 'jpg';

  /// EXIF orientation declared by a JPEG's own APP1 segment, or 1.
  ///
  /// A deliberately small, bounded reader: walk the JPEG marker chain to the
  /// first APP1 that starts with "Exif\0\0", read the TIFF byte order, and
  /// look up tag 0x0112 in IFD0. Every length is checked against the buffer,
  /// because this parses a file the user chose.
  static int readSourceOrientation(Uint8List bytes) {
    const orientationTag = 0x0112;
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return 1;

    var offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] != 0xFF) return 1;
      final marker = bytes[offset + 1];
      // Standalone markers carry no length; SOS means pixel data starts.
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        offset += 2;
        continue;
      }
      if (marker == 0xDA || marker == 0xD9) return 1;
      final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
      if (length < 2 || offset + 2 + length > bytes.length) return 1;
      final segment = offset + 4;
      if (marker == 0xE1 &&
          length >= 8 &&
          bytes[segment] == 0x45 && // E
          bytes[segment + 1] == 0x78 && // x
          bytes[segment + 2] == 0x69 && // i
          bytes[segment + 3] == 0x66 && // f
          bytes[segment + 4] == 0x00) {
        return _orientationFromTiff(bytes, segment + 6,
            offset + 2 + length, orientationTag);
      }
      offset += 2 + length;
    }
    return 1;
  }

  static int _orientationFromTiff(
    Uint8List bytes,
    int tiffStart,
    int limit,
    int wantedTag,
  ) {
    if (tiffStart + 8 > limit) return 1;
    final bigEndian = bytes[tiffStart] == 0x4D && bytes[tiffStart + 1] == 0x4D;
    final littleEndian =
        bytes[tiffStart] == 0x49 && bytes[tiffStart + 1] == 0x49;
    if (!bigEndian && !littleEndian) return 1;

    int u16(int at) => bigEndian
        ? (bytes[at] << 8) | bytes[at + 1]
        : (bytes[at + 1] << 8) | bytes[at];
    int u32(int at) => bigEndian
        ? (bytes[at] << 24) |
              (bytes[at + 1] << 16) |
              (bytes[at + 2] << 8) |
              bytes[at + 3]
        : (bytes[at + 3] << 24) |
              (bytes[at + 2] << 16) |
              (bytes[at + 1] << 8) |
              bytes[at];

    if (u16(tiffStart + 2) != 0x002A) return 1;
    final ifd0 = tiffStart + u32(tiffStart + 4);
    if (ifd0 + 2 > limit) return 1;
    final count = u16(ifd0);
    for (var i = 0; i < count; i++) {
      final entry = ifd0 + 2 + 12 * i;
      if (entry + 12 > limit) return 1;
      if (u16(entry) != wantedTag) continue;
      final value = u16(entry + 8);
      return value >= 1 && value <= 8 ? value : 1;
    }
    return 1;
  }

  /// Builds a NEW image containing nothing but colour values.
  ///
  /// Copying the pixels by hand rather than cloning is the whole point: a clone
  /// carries `exif`, `iccProfile`, `textData` and frame metadata with it, and
  /// each of those is a channel this function exists to close. Alpha is
  /// composited over white, because JPEG has no alpha and the alternative is a
  /// black halo around every transparent avatar.
  static img.Image _copyPixelsOnly(img.Image source) {
    final out = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 3,
    );
    final hasAlpha = source.numChannels == 4;
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        if (!hasAlpha) {
          out.setPixelRgb(x, y, pixel.r, pixel.g, pixel.b);
          continue;
        }
        final alpha = pixel.a / pixel.maxChannelValue;
        out.setPixelRgb(
          x,
          y,
          _overWhite(pixel.r, alpha, pixel.maxChannelValue),
          _overWhite(pixel.g, alpha, pixel.maxChannelValue),
          _overWhite(pixel.b, alpha, pixel.maxChannelValue),
        );
      }
    }
    return out;
  }

  static num _overWhite(num channel, num alpha, num maxValue) =>
      channel * alpha + maxValue * (1 - alpha);
}
