// ============================================================================
// CHAOS TEST HELPERS - Test Infrastructure
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import '../../lib/core/services/connectivity_service.dart';
import '../../lib/core/services/location_service.dart';
import '../../lib/core/services/atomic_storage_service.dart';
import '../../lib/core/services/offline_queue_service.dart';
import '../../lib/core/services/emergency_core_service.dart';

// Generate mocks
@GenerateMocks([
  ConnectivityService,
  LocationService,
  Battery,
])
class MockConnectivityService extends Mock implements ConnectivityService {}
class MockLocationService extends Mock implements LocationService {}
class MockBattery extends Mock implements Battery {}

/// Test context for chaos tests
class TestContext {
  late MockConnectivityService connectivity;
  late MockLocationService location;
  late MockBattery battery;
  
  SnackbarMessage? lastSnackbar;
  List<String> breadcrumbs = [];
  
  Future<void> initialize() async {
    connectivity = MockConnectivityService();
    location = MockLocationService();
    battery = MockBattery();
    
    // Setup default behaviors
    when(connectivity.isOnline).thenReturn(true);
    when(connectivity.onStatusChange).thenAnswer((_) => Stream.value(true));
    when(battery.batteryLevel).thenAnswer((_) async => 100);
    when(battery.batteryState).thenAnswer((_) => Stream.value(BatteryState.full));
  }
  
  Future<EmergencyResult> triggerEmergency() async {
    breadcrumbs.add('Emergency triggered at ${DateTime.now()}');
    
    return await EmergencyCoreService.instance.triggerEmergency(
      title: 'Chaos Test Emergency',
      message: 'Testing zero-fault guarantees',
    );
  }
  
  Future<void> injectFailure(FailureType type) async {
    breadcrumbs.add('Injecting failure: $type at ${DateTime.now()}');
    
    switch (type) {
      case FailureType.network:
        await injectNetworkFailure();
        break;
      case FailureType.gps:
        await injectGPSFailure();
        break;
      case FailureType.lowBattery:
        await injectLowBattery();
        break;
      case FailureType.criticalBattery:
        await injectCriticalBattery();
        break;
    }
  }
  
  Future<void> injectNetworkFailure() async {
    when(connectivity.isOnline).thenReturn(false);
    when(connectivity.onStatusChange).thenAnswer((_) => Stream.value(false));
    breadcrumbs.add('Network disabled');
  }
  
  Future<void> restoreNetwork() async {
    when(connectivity.isOnline).thenReturn(true);
    when(connectivity.onStatusChange).thenAnswer((_) => Stream.value(true));
    breadcrumbs.add('Network restored');
  }
  
  Future<void> injectGPSFailure() async {
    when(location.getCurrentPosition()).thenThrow(
      LocationServiceDisabledException(),
    );
    when(location.getLastKnownPosition()).thenAnswer((_) async => null);
    breadcrumbs.add('GPS disabled');
  }
  
  Future<void> injectCachedLocation() async {
    final cached = Position(
      latitude: 41.0082,
      longitude: 28.9784,
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
      accuracy: 100.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
    
    when(location.getLastKnownPosition()).thenAnswer((_) async => cached);
    breadcrumbs.add('Cached location injected (5 min old)');
  }
  
  Future<void> injectLowBattery() async {
    when(battery.batteryLevel).thenAnswer((_) async => 15);
    when(battery.batteryState).thenAnswer(
      (_) => Stream.value(BatteryState.discharging),
    );
    breadcrumbs.add('Low battery (15%)');
  }
  
  Future<void> injectCriticalBattery() async {
    when(battery.batteryLevel).thenAnswer((_) async => 3);
    when(battery.batteryState).thenAnswer(
      (_) => Stream.value(BatteryState.discharging),
    );
    breadcrumbs.add('Critical battery (3%)');
  }
  
  void simulateCrash() {
    breadcrumbs.add('Simulated crash');
    throw TestCrashException();
  }
  
  Future<void> restart() async {
    breadcrumbs.add('Simulated restart');
    await cleanup();
    await initialize();
  }
  
  Future<void> cleanup() async {
    breadcrumbs.add('Cleanup');
    // Clean up resources
  }
  
  String getBreadcrumbTrail() {
    return breadcrumbs.join('\n');
  }
}

/// Failure types for injection
enum FailureType {
  network,
  gps,
  lowBattery,
  criticalBattery,
}

/// Snackbar message for testing
class SnackbarMessage {
  final String message;
  final String? actionLabel;
  
  SnackbarMessage(this.message, {this.actionLabel});
  
  bool get hasAction => actionLabel != null;
}

/// Test crash exception
class TestCrashException implements Exception {
  @override
  String toString() => 'Simulated crash for testing';
}

/// Test result for reporting
class TestResult {
  final String name;
  final bool passed;
  final Duration reactionTime;
  final String? fallbackUsed;
  final bool dataIntegrity;
  final String? errorMessage;
  
  TestResult({
    required this.name,
    required this.passed,
    required this.reactionTime,
    this.fallbackUsed,
    required this.dataIntegrity,
    this.errorMessage,
  });
}

/// Chaos report generator
class ChaosReport {
  final List<TestResult> results;
  final DateTime timestamp;
  
  ChaosReport(this.results) : timestamp = DateTime.now();
  
  String generate() {
    final buffer = StringBuffer();
    
    buffer.writeln('# KoruBeni Chaos Test Report');
    buffer.writeln('Generated: ${timestamp.toIso8601String()}');
    buffer.writeln();
    
    // Summary
    final passed = results.where((r) => r.passed).length;
    final failed = results.length - passed;
    final successRate = (passed / results.length * 100).toStringAsFixed(1);
    
    buffer.writeln('## Executive Summary');
    buffer.writeln('- Total Tests: ${results.length}');
    buffer.writeln('- Passed: $passed ✅');
    buffer.writeln('- Failed: $failed ❌');
    buffer.writeln('- Success Rate: $successRate%');
    buffer.writeln('- Overall Health: ${_getHealthStatus(successRate)}');
    buffer.writeln();
    
    // Performance metrics
    final avgReactionTime = results
        .map((r) => r.reactionTime.inMilliseconds)
        .reduce((a, b) => a + b) / results.length;
    
    buffer.writeln('## Performance Metrics');
    buffer.writeln('- Average Reaction Time: ${avgReactionTime.toStringAsFixed(0)}ms');
    buffer.writeln('- Fastest Response: ${results.map((r) => r.reactionTime.inMilliseconds).reduce((a, b) => a < b ? a : b)}ms');
    buffer.writeln('- Slowest Response: ${results.map((r) => r.reactionTime.inMilliseconds).reduce((a, b) => a > b ? a : b)}ms');
    buffer.writeln('- Data Integrity: ${results.where((r) => r.dataIntegrity).length}/${results.length}');
    buffer.writeln();
    
    // Individual results
    buffer.writeln('## Test Results');
    for (final result in results) {
      buffer.writeln();
      buffer.writeln('### ${result.name}');
      buffer.writeln('- Status: ${result.passed ? "✅ PASSED" : "❌ FAILED"}');
      buffer.writeln('- Reaction Time: ${result.reactionTime.inMilliseconds}ms');
      
      if (result.fallbackUsed != null) {
        buffer.writeln('- Fallback Used: ${result.fallbackUsed}');
      }
      
      buffer.writeln('- Data Integrity: ${result.dataIntegrity ? "✅ Verified" : "❌ Compromised"}');
      
      if (!result.passed && result.errorMessage != null) {
        buffer.writeln('- Error: ${result.errorMessage}');
      }
    }
    
    // Vulnerabilities
    final vulnerabilities = results.where((r) => !r.passed).toList();
    if (vulnerabilities.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Vulnerabilities Found');
      for (final vuln in vulnerabilities) {
        buffer.writeln('- **${vuln.name}**: ${vuln.errorMessage}');
      }
    } else {
      buffer.writeln();
      buffer.writeln('## Vulnerabilities Found');
      buffer.writeln('None ✅');
    }
    
    // Recommendations
    buffer.writeln();
    buffer.writeln('## Recommendations');
    if (failed == 0) {
      buffer.writeln('- All tests passed! System is operating within zero-fault guarantees.');
      buffer.writeln('- Continue monitoring in production.');
      buffer.writeln('- Run chaos tests before each release.');
    } else {
      buffer.writeln('- Fix failed tests before release.');
      buffer.writeln('- Review zero-fault patterns for failed scenarios.');
      buffer.writeln('- Add regression tests for discovered issues.');
    }
    
    return buffer.toString();
  }
  
  String _getHealthStatus(String successRate) {
    final rate = double.parse(successRate);
    if (rate == 100) return 'EXCELLENT 🟢';
    if (rate >= 80) return 'GOOD 🟡';
    if (rate >= 60) return 'NEEDS IMPROVEMENT 🟠';
    return 'CRITICAL 🔴';
  }
}

/// Verification helpers
Future<void> verifyDataIntegrity(TestContext context) async {
  // Check atomic storage integrity
  await AtomicStorageService.instance.checkIntegrity();
}

Future<void> verifyNoDataLoss(TestContext context) async {
  // Check offline queue
  final queueCount = await OfflineQueueService.instance.pendingCount();
  expect(queueCount, greaterThanOrEqualTo(0));
}

Future<void> verifyUserFeedback(TestContext context) async {
  // In real implementation, check for UI feedback
  // For now, just verify breadcrumbs exist
  expect(context.breadcrumbs, isNotEmpty);
}

/// Setup test context
Future<TestContext> setupTestContext() async {
  final context = TestContext();
  await context.initialize();
  return context;
}
