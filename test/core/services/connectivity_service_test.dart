import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/connectivity_service.dart';

/// S7 regression: the offline banner must not appear while the device is
/// actually online. connectivity_plus reports the active transport, not real
/// reachability, so the decision must treat any non-`none` transport (including
/// vpn/other/bluetooth) as online instead of allow-listing only
/// mobile/wifi/ethernet.
void main() {
  group('ConnectivityService.isOnlineFromResults', () {
    test('empty/unknown result list is fail-open (online), not offline', () {
      // D5: a false offline banner (e.g. an empty cold-start read) is worse
      // than briefly missing a true offline on an offline-first app.
      expect(ConnectivityService.isOnlineFromResults(const []), isTrue);
    });

    test('only ConnectivityResult.none is offline', () {
      expect(
        ConnectivityService.isOnlineFromResults(
          const [ConnectivityResult.none],
        ),
        isFalse,
      );
    });

    test('wifi, mobile and ethernet transports are online', () {
      expect(
        ConnectivityService.isOnlineFromResults(
          const [ConnectivityResult.wifi],
        ),
        isTrue,
      );
      expect(
        ConnectivityService.isOnlineFromResults(
          const [ConnectivityResult.mobile],
        ),
        isTrue,
      );
      expect(
        ConnectivityService.isOnlineFromResults(
          const [ConnectivityResult.ethernet],
        ),
        isTrue,
      );
    });

    test('vpn transport counts as online (false-offline regression)', () {
      expect(
        ConnectivityService.isOnlineFromResults(
          const [ConnectivityResult.vpn],
        ),
        isTrue,
      );
    });

    test('other and bluetooth transports count as online', () {
      expect(
        ConnectivityService.isOnlineFromResults(
          const [ConnectivityResult.other],
        ),
        isTrue,
      );
      expect(
        ConnectivityService.isOnlineFromResults(
          const [ConnectivityResult.bluetooth],
        ),
        isTrue,
      );
    });

    test('mixed none + wifi is online', () {
      expect(
        ConnectivityService.isOnlineFromResults(
          const [ConnectivityResult.none, ConnectivityResult.wifi],
        ),
        isTrue,
      );
    });
  });
}
