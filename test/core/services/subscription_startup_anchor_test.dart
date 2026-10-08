// Y-03 (chaos audit 2026-10-08): with the store unreachable, a confirmed Pro
// subscriber's home screen drew the SOS button as "Kilitli · PRO" until the
// first press -- the offline anchor that authorizes the press was loaded by
// the press itself and by nothing at startup (API 35 emulator, cold start and
// after a process death). A locked-looking SOS is one a panicking user may
// never try.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/revenue_cat_service.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StoreUnreachable extends RevenueCatService {
  @override
  Future<bool> ensureInitialized() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the startup refresh shows a corroborated Pro anchor before any press',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        RevenueCatService.priorProInitializationHintKey: true,
        RevenueCatService.lastVerifiedProAtKey: DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      });
      final provider = SubscriptionProvider(
        revenueCatService: _StoreUnreachable(),
      );
      addTearDown(provider.dispose);

      await provider.initializeFromPriorProHint();

      expect(provider.canUseEmergencyFeature, isTrue);
    },
  );

  test(
    'without the corroborating pair the startup refresh authorizes nothing',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        RevenueCatService.lastVerifiedProAtKey:
            DateTime.now().millisecondsSinceEpoch,
      });
      final provider = SubscriptionProvider(
        revenueCatService: _StoreUnreachable(),
      );
      addTearDown(provider.dispose);

      await provider.initializeFromPriorProHint();

      expect(provider.canUseEmergencyFeature, isFalse);
    },
  );
}
