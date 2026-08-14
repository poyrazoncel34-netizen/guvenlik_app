/// Builds JPEG fixtures carrying REAL EXIF metadata, at the byte level.
///
/// Why not `image.exif[...] = ...` and `encodeJpg`
/// -----------------------------------------------
/// That round trip silently loses the two tags this row is most about: the
/// package's JPEG encoder drops `Orientation` (it assumes upright pixels) and
/// does not emit the GPS sub-IFD block. A fixture built that way would have
/// produced a suite that "proved" GPS removal while never having carried GPS —
/// the exact vacuity class this repository has already been bitten by. So the
/// APP1 segment is assembled here, and `assertFixtureCarriesMetadata` in the
/// test re-parses it to prove the fixture is real before anything is asserted
/// about the sanitiser.
///
/// Layout (TIFF, big-endian): header, IFD0, GPS IFD, then a data area for every
/// value that does not fit in an entry's 4 inline bytes.
library;

import 'dart:typed_data';

class _Entry {
  _Entry.inline(this.tag, this.type, this.count, this.inlineBytes)
    : data = null;
  _Entry.deferred(this.tag, this.type, this.count, this.data)
    : inlineBytes = null;

  final int tag;
  final int type; // 2 = ASCII, 3 = SHORT, 4 = LONG, 5 = RATIONAL
  final int count;
  final List<int>? inlineBytes; // exactly 4 bytes
  final List<int>? data;
}

List<int> _u16(int v) => <int>[(v >> 8) & 0xFF, v & 0xFF];
List<int> _u32(int v) =>
    <int>[(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

_Entry _ascii(int tag, String value) {
  final bytes = <int>[...value.codeUnits, 0];
  if (bytes.length <= 4) {
    return _Entry.inline(tag, 2, bytes.length, <int>[
      ...bytes,
      ...List<int>.filled(4 - bytes.length, 0),
    ]);
  }
  return _Entry.deferred(tag, 2, bytes.length, bytes);
}

_Entry _short(int tag, int value) =>
    _Entry.inline(tag, 3, 1, <int>[..._u16(value), 0, 0]);

_Entry _rationals(int tag, List<List<int>> values) => _Entry.deferred(
  tag,
  5,
  values.length,
  <int>[
    for (final v in values) ...<int>[..._u32(v[0]), ..._u32(v[1])],
  ],
);

/// A rational list needs numerator/denominator pairs interleaved correctly.
_Entry _rationalTriple(int tag, List<int> whole) => _Entry.deferred(
  tag,
  5,
  whole.length,
  <int>[for (final v in whole) ..._u32(v), ..._u32(1)],
);

/// The exact strings and coordinates every fixture carries. The test asserts
/// against these, so a change here cannot silently weaken an assertion.
class ExifFixtureContent {
  static const String make = 'ACME Phone Co';
  static const String model = 'Pixelish 9 Pro';
  static const String software = 'KoruBeniTestFixture 1.0';
  static const String dateTime = '2026:08:15 09:30:00';
  static const String artist = 'Test Subject';
  static const String copyright = 'Test Subject 2026';
  static const String description = 'a photo taken at home';
  static const String userComment = 'private note';
  static const String gpsDateStamp = '2026:08:15';

  /// 41 deg 0' 50" N, 28 deg 58' 44" E -- Istanbul.
  static const List<int> latitude = <int>[41, 0, 50];
  static const List<int> longitude = <int>[28, 58, 44];
  static const int altitude = 39;

  /// Every literal a sanitised artifact must not contain.
  static const List<String> forbiddenStrings = <String>[
    make,
    model,
    software,
    dateTime,
    artist,
    copyright,
    description,
    userComment,
    gpsDateStamp,
  ];
}

/// Assembles the APP1 EXIF payload (without the marker/length header).
Uint8List _exifPayload({required int orientation}) {
  const gpsOffsetTag = 0x8825;

  final ifd0 = <_Entry>[
    _ascii(0x010E, ExifFixtureContent.description),
    _ascii(0x010F, ExifFixtureContent.make),
    _ascii(0x0110, ExifFixtureContent.model),
    _short(0x0112, orientation),
    _ascii(0x0131, ExifFixtureContent.software),
    _ascii(0x0132, ExifFixtureContent.dateTime),
    _ascii(0x013B, ExifFixtureContent.artist),
    _ascii(0x8298, ExifFixtureContent.copyright),
    // GPSOffset, patched once the GPS IFD position is known.
    _Entry.inline(gpsOffsetTag, 4, 1, <int>[0, 0, 0, 0]),
  ]..sort((a, b) => a.tag.compareTo(b.tag));

  final gps = <_Entry>[
    _ascii(0x0001, 'N'),
    _rationalTriple(0x0002, ExifFixtureContent.latitude),
    _ascii(0x0003, 'E'),
    _rationalTriple(0x0004, ExifFixtureContent.longitude),
    _rationals(0x0006, <List<int>>[
      <int>[ExifFixtureContent.altitude, 1],
    ]),
    _ascii(0x001D, ExifFixtureContent.gpsDateStamp),
  ]..sort((a, b) => a.tag.compareTo(b.tag));

  int blockSize(List<_Entry> entries) => 2 + 12 * entries.length + 4;
  const headerSize = 8;
  final gpsOffset = headerSize + blockSize(ifd0);
  final dataStart = gpsOffset + blockSize(gps);

  final data = <int>[];
  List<int> emitBlock(List<_Entry> entries, {int? patchGpsOffset}) {
    final out = <int>[..._u16(entries.length)];
    for (final entry in entries) {
      out
        ..addAll(_u16(entry.tag))
        ..addAll(_u16(entry.type))
        ..addAll(_u32(entry.count));
      if (entry.tag == gpsOffsetTag && patchGpsOffset != null) {
        out.addAll(_u32(patchGpsOffset));
      } else if (entry.inlineBytes != null) {
        out.addAll(entry.inlineBytes!);
      } else {
        out.addAll(_u32(dataStart + data.length));
        data.addAll(entry.data!);
        if (data.length.isOdd) data.add(0);
      }
    }
    return out..addAll(_u32(0));
  }

  final ifd0Bytes = emitBlock(ifd0, patchGpsOffset: gpsOffset);
  final gpsBytes = emitBlock(gps);

  return Uint8List.fromList(<int>[
    0x4D, 0x4D, // 'MM' big-endian
    ..._u16(0x002A),
    ..._u32(headerSize),
    ...ifd0Bytes,
    ...gpsBytes,
    ...data,
  ]);
}

/// Splices a real EXIF APP1 segment into [jpeg] straight after SOI.
Uint8List withExif(Uint8List jpeg, {int orientation = 1}) {
  final payload = _exifPayload(orientation: orientation);
  final segment = <int>[
    0xFF, 0xE1,
    ..._u16(payload.length + 8), // length + "Exif\0\0"
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
    ...payload,
  ];
  return Uint8List.fromList(<int>[
    jpeg[0], jpeg[1], // SOI
    ...segment,
    ...jpeg.sublist(2),
  ]);
}
