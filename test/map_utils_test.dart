import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/utils/map_utils.dart';

void main() {
  test('shouldUseOfflineMapFallback returns false when online', () {
    expect(shouldUseOfflineMapFallback(isOnline: true), isFalse);
  });

  test('shouldUseOfflineMapFallback returns true when offline', () {
    expect(shouldUseOfflineMapFallback(isOnline: false), isTrue);
  });

  test('OSM user agent matches the production application id', () {
    expect(kOsmUserAgentPackageName, 'com.poyrazoncel.korubeni');
  });
}
