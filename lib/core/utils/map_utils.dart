import 'package:url_launcher/url_launcher.dart';

// OSM tile User-Agent identifier — per OSMF tile usage policy
// (https://operations.osmfoundation.org/policies/tiles/), a contact channel
// is "highly recommended" so operations can reach the developer if needed.
const String kOsmUserAgentPackageName =
    'com.poyrazoncel.korubeni; +korubeni.destek@gmail.com';

// The User-Agent actually sent. flutter_map's own default would be
// `flutter_map (<package>)`: it leads with the LIBRARY, which is the shape the
// policy says "will be blocked". Passed as an explicit tileProvider header,
// so TileLayer's putIfAbsent never replaces it. No version number on purpose:
// pubspec stays at 1.0.0 (versionCode comes from the tag), so it would lie.
const String kMapTileUserAgent = 'KoruBeni ($kOsmUserAgentPackageName)';

bool shouldUseOfflineMapFallback({required bool isOnline}) => !isOnline;

/// Opens the tile provider's copyright/licence page from the map attribution.
Future<void> openMapAttributionPage(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    // Silent fallback — attribution remains visible as static text even
    // if no browser is available to open the copyright page.
  }
}
