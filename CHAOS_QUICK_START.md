# KoruBeni Chaos Engineering - Quick Start Guide

## 🚀 Run Chaos Tests in 30 Seconds

```bash
# Navigate to project root
cd /Users/poyrazoncel/Desktop/guvenlik_app

# Run all chaos tests
./scripts/run_chaos_tests.sh

# View report
cat test/chaos/CHAOS_REPORT.md
```

## 📋 What Gets Tested

| Test | Scenario | Verification |
|------|----------|--------------|
| 1️⃣ Network Blackout | Internet cuts out during emergency | Offline queue works |
| 2️⃣ GPS Loss | Location service fails | 5-level fallback works |
| 3️⃣ Resource Exhaustion | 3% battery, low memory | Emergency-only mode works |
| 4️⃣ System Kill | App crashes mid-emergency | State recovery works |
| 5️⃣ Database Corruption | Write interrupted | Atomic rollback works |

## ✅ Expected Output

```
╔════════════════════════════════════════════════════════════════╗
║  KORUBENI CHAOS TEST SUITE - "Iron Fist" Stress Testing       ║
║  Testing Zero-Fault Guarantees Under Extreme Conditions       ║
╚════════════════════════════════════════════════════════════════╝

🧪 Running: Network Blackout Test...
  ✅ PASSED (523ms)

🧪 Running: GPS Loss Test...
  ✅ PASSED (1234ms)
     Fallback: LocationSource.cached

🧪 Running: Resource Exhaustion Test...
  ✅ PASSED (891ms)
     Battery: 3%

🧪 Running: System Kill Test...
  ✅ PASSED (1567ms)
     State Recovered: Yes

🧪 Running: Database Corruption Test...
  ✅ PASSED (678ms)
     Rollback: Successful

╔════════════════════════════════════════════════════════════════╗
║  CHAOS TEST SUITE COMPLETED                                    ║
╚════════════════════════════════════════════════════════════════╝

✅ ALL CHAOS TESTS PASSED - Zero-Fault Guarantees Verified!
```

## 🔧 Command Options

```bash
# Verbose output (see all details)
./scripts/run_chaos_tests.sh --verbose

# Run tests individually (slower but more detailed)
./scripts/run_chaos_tests.sh --individual

# Show report only (don't run tests)
./scripts/run_chaos_tests.sh --report

# Help
./scripts/run_chaos_tests.sh --help
```

## 🐛 If Tests Fail

### Step 1: Identify the Failure
```bash
# Run with verbose output
./scripts/run_chaos_tests.sh --verbose
```

### Step 2: Check the Service
Look at the relevant service:
- Network issues → `lib/core/services/network_retry_service.dart`
- GPS issues → `lib/core/services/emergency_core_service.dart`
- Battery issues → `lib/core/services/battery_optimization_service.dart`
- Storage issues → `lib/core/services/atomic_storage_service.dart`

### Step 3: Apply Zero-Fault Pattern
Check the rules:
- `.cursor/rules/zero-fault-checklist.mdc`
- `.cursor/rules/zero-fault-connectivity.mdc`
- `.cursor/rules/zero-fault-sensors.mdc`
- `.cursor/rules/zero-fault-database.mdc`

### Step 4: Re-run Tests
```bash
./scripts/run_chaos_tests.sh
```

## 🤖 Use the Chaos Engineer Subagent

The AI can help you run and fix chaos tests:

```
Use the chaos-engineer subagent to run stress tests and fix any issues
```

The subagent will:
1. Run all chaos tests
2. Generate comprehensive report
3. Identify failures
4. Suggest fixes
5. Apply zero-fault patterns
6. Re-run tests to verify

## 📊 Understanding the Report

### Health Status
- 🟢 **EXCELLENT**: 100% pass rate
- 🟡 **GOOD**: 80-99% pass rate
- 🟠 **NEEDS IMPROVEMENT**: 60-79% pass rate
- 🔴 **CRITICAL**: <60% pass rate

### Performance Metrics
- **Reaction Time**: How fast the system responds
- **Data Integrity**: Whether data remains uncorrupted
- **Fallback Used**: Which backup system activated

### Example Report Section
```markdown
### 1. Network Blackout
- Status: ✅ PASSED
- Reaction Time: 523ms
- Fallback Used: OfflineQueue
- Data Integrity: ✅ Verified
```

## 🔄 Integration with Workflow

### Before Committing
```bash
# Add to pre-commit hook
./scripts/run_chaos_tests.sh
```

### Before Releasing
```bash
# Mandatory before release
./scripts/run_chaos_tests.sh --verbose
```

### In CI/CD
```yaml
# .github/workflows/chaos-tests.yml
- run: ./scripts/run_chaos_tests.sh
```

## 📚 Learn More

- **Full Documentation**: `CHAOS_ENGINEERING_FRAMEWORK.md`
- **Test README**: `test/chaos/README.md`
- **Chaos Skill**: `.cursor/skills/chaos-test/SKILL.md`
- **Chaos Subagent**: `.cursor/agents/chaos-engineer.md`

## ⚡ Quick Troubleshooting

### Tests won't run
```bash
flutter clean
flutter pub get
./scripts/run_chaos_tests.sh
```

### Report not generated
Check that tests complete fully. Report is generated in `tearDownAll()`.

### Mock errors
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 🎯 Success Criteria

All tests pass when:
- ✅ No crashes
- ✅ Data integrity maintained
- ✅ User receives feedback
- ✅ Recovery is automatic
- ✅ Performance acceptable

## 🚨 Critical Rules

**NEVER** release without passing chaos tests!

This is a safety-critical emergency app. User lives may depend on it working perfectly under the worst conditions.

---

**Ready to test?**

```bash
./scripts/run_chaos_tests.sh
```
