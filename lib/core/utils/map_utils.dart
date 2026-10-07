import 'package:url_launcher/url_launcher.dart';

// OSM tile User-Agent identifier — per OSMF tile usage policy
// (https://operations.osmfoundation.org/policies/tiles/), a contact channel
// is "highly recommended" so operations can reach the developer if needed.
// flutter_map wraps this as: User-Agent: flutter_map (<this string>)
const String kOsmUserAgentPackageName =
    'com.poyrazoncel.korubeni; +korubeni.destek@gmail.com';

bool shouldUseOfflineMapFallback({required bool isOnline}) => !isOnline;

/// Opens the OpenStreetMap copyright page from the map attribution.
Future<void> openOsmCopyrightPage() async {
  final uri = Uri.parse('https://www.openstreetmap.org/copyright');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    // Silent fallback — attribution remains visible as static text even
    // if no browser is available to open the copyright page.
  }
}
