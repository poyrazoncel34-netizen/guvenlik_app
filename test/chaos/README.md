# KoruBeni Chaos Engineering Test Suite

## "Iron Fist" Stress Testing

This directory contains comprehensive chaos engineering tests that attempt to break KoruBeni's zero-fault guarantees through simulated failures.

## Overview

The chaos test suite validates that KoruBeni operates correctly under extreme conditions:

1. **Network Blackout** - Total network loss during emergency
2. **GPS Loss (Tunnel Vision)** - Location service failure with 5-level fallback
3. **Resource Exhaustion** - Critical battery and low memory conditions
4. **System Kill (Persistence)** - App crash and state recovery
5. **Database Corruption** - Interrupted write operations and rollback

## Quick Start

### Run All Tests

```bash
flutter test test/chaos/chaos_test_suite.dart
```

### Run Individual Tests

```bash
# Network Blackout
flutter test test/chaos/network_blackout_test.dart

# GPS Loss
flutter test test/chaos/gps_loss_test.dart

# Resource Exhaustion
flutter test test/chaos/resource_exhaustion_test.dart

# System Kill
flutter test test/chaos/system_kill_test.dart

# Database Corruption
flutter test test/chaos/database_corruption_test.dart
```

### View Report

After running tests, check the generated report:

```bash
cat test/chaos/CHAOS_REPORT.md
```

## Test Structure

Each test follows this pattern:

```dart
test('scenario description', () async {
  // 1. Setup
  final context = await setupTestContext();
  
  // 2. Trigger operation
  final operationFuture = context.triggerEmergency();
  
  // 3. Inject failure at specific time
  await Future.delayed(Duration(milliseconds: 500));
  await context.injectFailure(FailureType.network);
  
  // 4. Wait for completion
  final result = await operationFuture;
  
  // 5. Verify zero-fault response
  expect(result.success, isTrue);
  
  // 6. Verify specific guarantees
  await verifyDataIntegrity(context);
  await verifyNoDataLoss(context);
});
```

## Failure Injection

### Network Failure

```dart
await context.injectFailure(FailureType.network);
```

Simulates complete network loss. Verifies:
- OfflineQueueService queues requests
- UI remains responsive
- Data persists locally
- Sync occurs when network returns

### GPS Failure

```dart
await context.injectFailure(FailureType.gps);
```

Disables location services. Verifies:
- 5-level fallback cascade
- Graceful degradation
- Emergency still sends
- User informed of accuracy

### Low Battery

```dart
await context.injectFailure(FailureType.lowBattery);      // 15%
await context.injectFailure(FailureType.criticalBattery); // 3%
```

Simulates battery drain. Verifies:
- Emergency-only mode activates
- Non-essential tasks pause
- Emergency prioritized
- Battery-aware behavior

### System Crash

```dart
try {
  context.simulateCrash();
} catch (e) {
  expect(e, isA<TestCrashException>());
}
await context.restart();
```

Simulates app crash. Verifies:
- State recovery on restart
- No data loss
- Queue persists
- Integrity maintained

## Verification Methods

### Data Integrity

```dart
await verifyDataIntegrity(context);
```

Checks:
- No corrupted data
- Backups are consistent
- Integrity check passes

### No Data Loss

```dart
await verifyNoDataLoss(context);
```

Checks:
- Failed operations queued
- Emergency data saved locally
- Sync will retry

### User Feedback

```dart
await verifyUserFeedback(context);
```

Checks:
- User receives notification
- Message is meaningful
- Action buttons present

## Performance Benchmarks

### Response Time Limits

- **Normal conditions**: < 2 seconds
- **Network failure**: < 5 seconds
- **GPS fallback**: < 15 seconds
- **Critical battery**: < 10 seconds

### Resource Limits

- **Memory growth**: < 10MB per 100 operations
- **Battery impact**: Minimal in emergency-only mode
- **Queue size**: Unlimited (disk-based)

## Success Criteria

A test passes when:

1. ✅ No crashes or exceptions
2. ✅ Appropriate fallback activated
3. ✅ Data integrity maintained
4. ✅ User receives feedback
5. ✅ Recovery is automatic
6. ✅ Performance acceptable

## Chaos Report

After running tests, a comprehensive report is generated:

```markdown
# KoruBeni Chaos Test Report

## Executive Summary
- Total Tests: 5
- Passed: 5 ✅
- Failed: 0 ❌
- Success Rate: 100.0%
- Overall Health: EXCELLENT 🟢

## Performance Metrics
- Average Reaction Time: 1234ms
- Fastest Response: 523ms
- Slowest Response: 2341ms
- Data Integrity: 5/5

## Test Results

### 1. Network Blackout
- Status: ✅ PASSED
- Reaction Time: 523ms
- Fallback Used: OfflineQueue
- Data Integrity: ✅ Verified

[... etc for each test]

## Vulnerabilities Found
None ✅

## Recommendations
- All tests passed! System is operating within zero-fault guarantees.
- Continue monitoring in production.
- Run chaos tests before each release.
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Chaos Tests

on:
  pull_request:
  schedule:
    - cron: '0 0 * * 0' # Weekly

jobs:
  chaos:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test test/chaos/
      - name: Upload Report
        if: always()
        uses: actions/upload-artifact@v2
        with:
          name: chaos-report
          path: test/chaos/CHAOS_REPORT.md
```

## When to Run

Run chaos tests:

- ✅ Before every release (mandatory)
- ✅ After major refactoring
- ✅ When adding critical features
- ✅ Weekly in CI/CD pipeline
- ✅ After dependency updates
- ✅ When investigating production issues

## Troubleshooting

### Tests Fail to Run

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter test test/chaos/
```

### Mock Issues

```bash
# Regenerate mocks
flutter pub run build_runner build --delete-conflicting-outputs
```

### Report Not Generated

Check that the test completes fully. The report is generated in `tearDownAll()`.

## Contributing

When adding new chaos tests:

1. Follow the existing test structure
2. Use `TestContext` for failure injection
3. Verify all zero-fault guarantees
4. Add to `chaos_test_suite.dart`
5. Update this README

## Zero-Fault Patterns Tested

1. **Offline-First**: All operations work without network
2. **Retry with Backoff**: Network calls retry 3-5 times
3. **Timeout Enforcement**: All operations have 10s timeout
4. **Atomic Storage**: All writes are transactional
5. **Graceful Degradation**: Features degrade, never crash
6. **State Recovery**: App recovers from any interruption
7. **Resource Awareness**: App adapts to low battery/memory
8. **Comprehensive Logging**: All failures logged to Crashlytics

## Related Documentation

- [Zero-Fault Checklist](../../.cursor/rules/zero-fault-checklist.mdc)
- [Chaos Testing Standards](../../.cursor/rules/chaos-testing-standards.mdc)
- [Emergency Core Service](../../lib/core/services/emergency_core_service.dart)
- [Network Retry Service](../../lib/core/services/network_retry_service.dart)
- [Atomic Storage Service](../../lib/core/services/atomic_storage_service.dart)

## Contact

For questions about chaos testing:
- Review the chaos-engineer subagent
- Check the chaos-test skill
- Consult the zero-fault rules

---

**Remember**: This is a safety-critical emergency app. User lives may depend on it working perfectly under the worst conditions. Be thorough and uncompromising in your testing.
