// OSM tile User-Agent identifier — per OSMF tile usage policy
// (https://operations.osmfoundation.org/policies/tiles/), a contact channel
// is "highly recommended" so operations can reach the developer if needed.
// flutter_map wraps this as: User-Agent: flutter_map (<this string>)
const String kOsmUserAgentPackageName =
    'com.poyrazoncel.korubeni; +korubeni.destek@gmail.com';

bool shouldUseOfflineMapFallback({required bool isOnline}) => !isOnline;
