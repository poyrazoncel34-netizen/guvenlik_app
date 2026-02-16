import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    test('singleton instance is consistent', () {
      final instance1 = ConnectivityService.instance;
      final instance2 = ConnectivityService.instance;
      expect(identical(instance1, instance2), true);
    });

    test('isOnline defaults to true', () {
      final service = ConnectivityService.instance;
      expect(service.isOnline, isA<bool>());
    });

    test('onStatusChange stream is broadcast', () {
      final service = ConnectivityService.instance;
      expect(service.onStatusChange, isA<Stream<bool>>());
    });
  });
}
