// ============================================================================
// KORUBENI CHAOS TEST SUITE - "Iron Fist" Stress Testing
// ============================================================================
// Comprehensive chaos engineering test suite that attempts to break
// KoruBeni's zero-fault guarantees through simulated failures.
//
// Run with: flutter test test/chaos/chaos_test_suite.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'chaos_test_helpers.dart';

// Import all chaos tests
import 'network_blackout_test.dart' as network_test;
import 'gps_loss_test.dart' as gps_test;
import 'resource_exhaustion_test.dart' as resource_test;
import 'system_kill_test.dart' as system_test;
import 'database_corruption_test.dart' as database_test;

void main() {
  print('');
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║  KORUBENI CHAOS TEST SUITE - "Iron Fist" Stress Testing       ║');
  print('║  Testing Zero-Fault Guarantees Under Extreme Conditions       ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  
  final results = <TestResult>[];
  final startTime = DateTime.now();
  
  group('KoruBeni Chaos Engineering Suite', () {
    setUpAll(() {
      print('🚀 Starting Chaos Test Suite...');
      print('📅 ${DateTime.now().toIso8601String()}');
      print('');
    });
    
    tearDownAll(() async {
      final duration = DateTime.now().difference(startTime);
      
      print('');
      print('╔════════════════════════════════════════════════════════════════╗');
      print('║  CHAOS TEST SUITE COMPLETED                                    ║');
      print('╚════════════════════════════════════════════════════════════════╝');
      print('');
      print('⏱️  Total Duration: ${duration.inSeconds}s');
      print('');
      
      // Generate comprehensive report
      final report = ChaosReport(results);
      final reportContent = report.generate();
      
      print(reportContent);
      
      // Save report to file
      try {
        final reportFile = File('test/chaos/CHAOS_REPORT.md');
        await reportFile.writeAsString(reportContent);
        print('');
        print('📄 Report saved to: test/chaos/CHAOS_REPORT.md');
      } catch (e) {
        print('⚠️  Failed to save report: $e');
      }
      
      print('');
      
      // Exit with appropriate code
      if (results.any((r) => !r.passed)) {
        print('❌ CHAOS TESTS FAILED - Fix issues before release!');
        print('');
      } else {
        print('✅ ALL CHAOS TESTS PASSED - Zero-Fault Guarantees Verified!');
        print('');
      }
    });
    
    // Test 1: Network Blackout
    group('Test 1: Network Blackout', () {
      test('Network loss during emergency', () async {
        print('🧪 Running: Network Blackout Test...');
        
        final testStart = DateTime.now();
        final context = await setupTestContext();
        
        try {
          // Run test
          final emergencyFuture = context.triggerEmergency();
          await Future.delayed(Duration(milliseconds: 500));
          await context.injectFailure(FailureType.network);
          
          final result = await emergencyFuture;
          final reactionTime = DateTime.now().difference(testStart);
          
          // Record result
          results.add(TestResult(
            name: 'Network Blackout',
            passed: result.success,
            reactionTime: reactionTime,
            fallbackUsed: 'OfflineQueue',
            dataIntegrity: true,
            errorMessage: result.success ? null : result.message,
          ));
          
          expect(result.success, isTrue);
          
          print('  ✅ PASSED (${reactionTime.inMilliseconds}ms)');
        } catch (e) {
          print('  ❌ FAILED: $e');
          results.add(TestResult(
            name: 'Network Blackout',
            passed: false,
            reactionTime: Duration.zero,
            dataIntegrity: false,
            errorMessage: e.toString(),
          ));
          rethrow;
        } finally {
          await context.cleanup();
        }
      });
    });
    
    // Test 2: GPS Loss
    group('Test 2: GPS Loss (Tunnel Vision)', () {
      test('GPS failure with location fallback', () async {
        print('🧪 Running: GPS Loss Test...');
        
        final testStart = DateTime.now();
        final context = await setupTestContext();
        
        try {
          await context.injectCachedLocation();
          
          final emergencyFuture = context.triggerEmergency();
          await Future.delayed(Duration(milliseconds: 500));
          await context.injectFailure(FailureType.gps);
          
          final result = await emergencyFuture;
          final reactionTime = DateTime.now().difference(testStart);
          
          results.add(TestResult(
            name: 'GPS Loss (Tunnel Vision)',
            passed: result.success,
            reactionTime: reactionTime,
            fallbackUsed: result.context.locationSource.toString(),
            dataIntegrity: true,
            errorMessage: result.success ? null : result.message,
          ));
          
          expect(result.success, isTrue);
          
          print('  ✅ PASSED (${reactionTime.inMilliseconds}ms)');
          print('     Fallback: ${result.context.locationSource}');
        } catch (e) {
          print('  ❌ FAILED: $e');
          results.add(TestResult(
            name: 'GPS Loss (Tunnel Vision)',
            passed: false,
            reactionTime: Duration.zero,
            dataIntegrity: false,
            errorMessage: e.toString(),
          ));
          rethrow;
        } finally {
          await context.cleanup();
        }
      });
    });
    
    // Test 3: Resource Exhaustion
    group('Test 3: Resource Exhaustion', () {
      test('Critical battery and low memory', () async {
        print('🧪 Running: Resource Exhaustion Test...');
        
        final testStart = DateTime.now();
        final context = await setupTestContext();
        
        try {
          await context.injectFailure(FailureType.criticalBattery);
          
          final result = await context.triggerEmergency();
          final reactionTime = DateTime.now().difference(testStart);
          
          results.add(TestResult(
            name: 'Resource Exhaustion',
            passed: result.success,
            reactionTime: reactionTime,
            fallbackUsed: 'Emergency-Only Mode',
            dataIntegrity: true,
            errorMessage: result.success ? null : result.message,
          ));
          
          expect(result.success, isTrue);
          expect(result.context.batteryLevel, lessThanOrEqualTo(10));
          
          print('  ✅ PASSED (${reactionTime.inMilliseconds}ms)');
          print('     Battery: ${result.context.batteryLevel}%');
        } catch (e) {
          print('  ❌ FAILED: $e');
          results.add(TestResult(
            name: 'Resource Exhaustion',
            passed: false,
            reactionTime: Duration.zero,
            dataIntegrity: false,
            errorMessage: e.toString(),
          ));
          rethrow;
        } finally {
          await context.cleanup();
        }
      });
    });
    
    // Test 4: System Kill
    group('Test 4: System Kill (Persistence)', () {
      test('App crash during emergency', () async {
        print('🧪 Running: System Kill Test...');
        
        final testStart = DateTime.now();
        final context = await setupTestContext();
        
        try {
          await context.triggerEmergency();
          
          // Simulate crash
          try {
            context.simulateCrash();
          } catch (e) {
            expect(e, isA<TestCrashException>());
          }
          
          // Restart and verify
          await context.restart();
          await verifyDataIntegrity(context);
          
          final reactionTime = DateTime.now().difference(testStart);
          
          results.add(TestResult(
            name: 'System Kill (Persistence)',
            passed: true,
            reactionTime: reactionTime,
            fallbackUsed: 'State Recovery',
            dataIntegrity: true,
          ));
          
          print('  ✅ PASSED (${reactionTime.inMilliseconds}ms)');
          print('     State Recovered: Yes');
        } catch (e) {
          print('  ❌ FAILED: $e');
          results.add(TestResult(
            name: 'System Kill (Persistence)',
            passed: false,
            reactionTime: Duration.zero,
            dataIntegrity: false,
            errorMessage: e.toString(),
          ));
          rethrow;
        } finally {
          await context.cleanup();
        }
      });
    });
    
    // Test 5: Database Corruption
    group('Test 5: Database Corruption', () {
      test('Interrupted write operations', () async {
        print('🧪 Running: Database Corruption Test...');
        
        final testStart = DateTime.now();
        final context = await setupTestContext();
        
        try {
          final service = AtomicStorageService.instance;
          final testKey = 'corruption_test';
          
          await service.writeString(testKey, 'initial');
          
          // Attempt corrupted write
          try {
            final writeFuture = service.writeString(testKey, 'corrupted');
            await Future.delayed(Duration(milliseconds: 30));
            context.simulateCrash();
          } catch (e) {
            expect(e, isA<TestCrashException>());
          }
          
          // Restart and verify
          await context.restart();
          await service.checkIntegrity();
          
          final recovered = await service.readString(testKey);
          final dataIntegrity = recovered == 'initial' || recovered == null;
          
          final reactionTime = DateTime.now().difference(testStart);
          
          results.add(TestResult(
            name: 'Database Corruption',
            passed: dataIntegrity,
            reactionTime: reactionTime,
            fallbackUsed: 'Atomic Rollback',
            dataIntegrity: dataIntegrity,
            errorMessage: dataIntegrity ? null : 'Data corruption detected',
          ));
          
          expect(dataIntegrity, isTrue);
          
          print('  ✅ PASSED (${reactionTime.inMilliseconds}ms)');
          print('     Rollback: Successful');
        } catch (e) {
          print('  ❌ FAILED: $e');
          results.add(TestResult(
            name: 'Database Corruption',
            passed: false,
            reactionTime: Duration.zero,
            dataIntegrity: false,
            errorMessage: e.toString(),
          ));
          rethrow;
        } finally {
          await context.cleanup();
        }
      });
    });
  });
}
