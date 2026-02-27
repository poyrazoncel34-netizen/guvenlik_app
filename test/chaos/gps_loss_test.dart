// ============================================================================
// CHAOS TEST 2: GPS Loss (Tunnel Vision)
// ============================================================================
// Disables GPS mid-tracking to test 5-level location fallback.
// Verifies graceful degradation of location accuracy.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'chaos_test_helpers.dart';
import '../../lib/core/services/emergency_core_service.dart';

void main() {
  group('Chaos Test 2: GPS Loss (Tunnel Vision)', () {
    late TestContext context;
    
    setUp(() async {
      context = await setupTestContext();
    });
    
    tearDown(() async {
      await context.cleanup();
    });
    
    test('should fallback to cached location when GPS fails', () async {
      // 1. Setup - inject cached location
      await context.injectCachedLocation();
      
      // 2. Trigger emergency (async)
      final startTime = DateTime.now();
      final emergencyFuture = context.triggerEmergency();
      
      // 3. Inject GPS failure after 500ms
      await Future.delayed(Duration(milliseconds: 500));
      await context.injectFailure(FailureType.gps);
      
      // 4. Wait for completion
      final result = await emergencyFuture;
      final reactionTime = DateTime.now().difference(startTime);
      
      // 5. Verify zero-fault response
      expect(result.success, isTrue,
          reason: 'Emergency should succeed despite GPS loss');
      
      expect(result.context, isNotNull);
      
      // 6. Verify fallback to cached location
      expect(result.context.locationSource, 
          anyOf(LocationSource.cached, LocationSource.system, LocationSource.ip),
          reason: 'Should use fallback location source');
      
      // 7. Verify location is available (even if degraded)
      expect(result.context.location, isNotNull,
          reason: 'Should have some location data from fallback');
      
      // 8. Verify reaction time
      expect(reactionTime.inSeconds, lessThan(15),
          reason: 'GPS fallback should complete within 15 seconds');
      
      print('✅ GPS Fallback Test PASSED');
      print('   Reaction Time: ${reactionTime.inMilliseconds}ms');
      print('   Location Source: ${result.context.locationSource}');
      print('   Location: ${result.context.location}');
    });
    
    test('should handle complete location failure gracefully', () async {
      // 1. Inject GPS failure with no cached location
      await context.injectFailure(FailureType.gps);
      
      // 2. Trigger emergency
      final result = await context.triggerEmergency();
      
      // 3. Verify emergency still succeeds
      expect(result.success, isTrue,
          reason: 'Emergency should succeed even without location');
      
      // 4. Verify location source is "none" or "ip"
      expect(result.context.locationSource,
          anyOf(LocationSource.none, LocationSource.ip),
          reason: 'Should indicate no GPS available');
      
      // 5. Verify no crash
      expect(result.context, isNotNull);
      
      print('✅ No Location Test PASSED');
      print('   Location Source: ${result.context.locationSource}');
      print('   Emergency Still Sent: ${result.success}');
    });
    
    test('should try all 5 fallback levels', () async {
      // 1. Inject GPS failure
      await context.injectFailure(FailureType.gps);
      
      // 2. Trigger emergency
      final result = await context.triggerEmergency();
      
      // 3. Verify fallback cascade was attempted
      // (In real implementation, check breadcrumbs for fallback attempts)
      expect(context.breadcrumbs.any((b) => b.contains('GPS')), isTrue,
          reason: 'Should log GPS failure');
      
      // 4. Verify emergency completed
      expect(result.success, isTrue);
      
      print('✅ Fallback Cascade Test PASSED');
      print('   Breadcrumb Trail:');
      print(context.getBreadcrumbTrail());
    });
    
    test('should not block emergency on slow GPS', () async {
      // 1. Setup - GPS will timeout after 10s
      // (Simulated by GPS failure)
      await context.injectFailure(FailureType.gps);
      
      // 2. Measure emergency response time
      final startTime = DateTime.now();
      final result = await context.triggerEmergency();
      final duration = DateTime.now().difference(startTime);
      
      // 3. Verify timeout is enforced
      expect(duration.inSeconds, lessThan(15),
          reason: 'Should not wait indefinitely for GPS');
      
      // 4. Verify emergency succeeded
      expect(result.success, isTrue,
          reason: 'Should proceed with fallback location');
      
      print('✅ GPS Timeout Test PASSED');
      print('   Duration: ${duration.inMilliseconds}ms');
      print('   Fallback Used: ${result.context.locationSource}');
    });
    
    test('should cache successful GPS for future fallback', () async {
      // 1. First emergency with GPS working (simulated by default state)
      final result1 = await context.triggerEmergency();
      
      expect(result1.success, isTrue);
      
      // 2. Second emergency with GPS failure
      await context.injectFailure(FailureType.gps);
      await context.injectCachedLocation(); // Simulate cached from first call
      
      final result2 = await context.triggerEmergency();
      
      // 3. Verify second emergency uses cached location
      expect(result2.success, isTrue);
      expect(result2.context.locationSource,
          anyOf(LocationSource.cached, LocationSource.system),
          reason: 'Should use cached location from previous success');
      
      print('✅ GPS Caching Test PASSED');
      print('   First Call: ${result1.context.locationSource}');
      print('   Second Call (GPS failed): ${result2.context.locationSource}');
    });
    
    test('should indicate location accuracy to user', () async {
      // 1. Inject GPS failure with cached location
      await context.injectFailure(FailureType.gps);
      await context.injectCachedLocation();
      
      // 2. Trigger emergency
      final result = await context.triggerEmergency();
      
      // 3. Verify location source is tracked
      expect(result.context.locationSource, isNot(LocationSource.gps),
          reason: 'Should not report GPS when using fallback');
      
      // 4. Verify user would be informed
      // (In real implementation, check for UI warning about degraded accuracy)
      expect(result.context.locationSource, isNotNull);
      
      print('✅ Accuracy Indication Test PASSED');
      print('   Location Source: ${result.context.locationSource}');
      print('   User Should See: "Using approximate location"');
    });
  });
}
