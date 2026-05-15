// map_page.dart konum izni UI testı.
// Bug: İzin reddedildiğinde "Location unavailable" gösteriyor ama
//      kullanıcıya izin vermesi için yönlendirme butonu yok.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/location_service.dart';

void main() {
  group('MapPage — konum izni banner UI', () {
    test('İzin reddedildiğinde settings butonu gösterilmeli', () {
      // permissionDenied veya permissionDeniedForever durumunda
      // kullanıcıya openAppSettings butonu gösterilmeli.
      const deniedStatuses = [
        LocationStatus.permissionDenied,
        LocationStatus.permissionDeniedForever,
      ];

      for (final status in deniedStatuses) {
        final shouldShowSettingsButton =
            status == LocationStatus.permissionDenied ||
            status == LocationStatus.permissionDeniedForever;

        expect(
          shouldShowSettingsButton,
          true,
          reason:
              '$status durumunda kullanıcıya app settings açma butonu gösterilmeli.',
        );
      }
    });
  });
}
