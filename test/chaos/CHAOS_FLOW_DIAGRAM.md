# KoruBeni Chaos Testing Flow Diagram

## Overall Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CHAOS ENGINEERING FRAMEWORK                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
        ┌───────────┐   ┌───────────┐   ┌───────────┐
        │   Skill   │   │ Subagent  │   │   Rules   │
        │  (Guide)  │   │   (AI)    │   │(Standards)│
        └───────────┘   └───────────┘   └───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Test Infrastructure │
                    │   - TestContext       │
                    │   - Mocks             │
                    │   - Helpers           │
                    └───────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
        ┌───────────┐   ┌───────────┐   ┌───────────┐
        │  Test 1   │   │  Test 2   │   │  Test 3   │
        │ Network   │   │    GPS    │   │ Resource  │
        └───────────┘   └───────────┘   └───────────┘
                │               │               │
                ▼               ▼               ▼
        ┌───────────┐   ┌───────────┐   ┌───────────┐
        │  Test 4   │   │  Test 5   │   │  Report   │
        │  System   │   │ Database  │   │ Generator │
        └───────────┘   └───────────┘   └───────────┘
```

## Test Execution Flow

```
START
  │
  ▼
┌─────────────────────┐
│ Setup TestContext   │
│ - Initialize mocks  │
│ - Setup defaults    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Trigger Emergency   │
│ (async operation)   │
└──────────┬──────────┘
           │
           ▼
    ⏰ Wait 500ms
           │
           ▼
┌─────────────────────┐
│ Inject Failure      │
│ - Network loss      │
│ - GPS failure       │
│ - Low battery       │
│ - Crash             │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Wait for Completion │
│ (measure time)      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Verify Result       │
│ - Success?          │
│ - Data integrity?   │
│ - Fallback used?    │
└──────────┬──────────┘
           │
           ▼
      ┌────────┐
      │ Pass?  │
      └───┬────┘
          │
    ┌─────┴─────┐
   Yes          No
    │            │
    ▼            ▼
┌────────┐  ┌────────┐
│ Record │  │ Record │
│Success │  │Failure │
└───┬────┘  └───┬────┘
    │            │
    └─────┬──────┘
          │
          ▼
    ┌──────────┐
    │ Cleanup  │
    └─────┬────┘
          │
          ▼
         END
```

## Failure Injection Mechanisms

```
┌──────────────────────────────────────────────────────────────┐
│                    FAILURE INJECTION                          │
└──────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   Network     │   │      GPS      │   │   Battery     │
│   Failure     │   │    Failure    │   │   Failure     │
│               │   │               │   │               │
│ Mock:         │   │ Mock:         │   │ Mock:         │
│ isOnline=false│   │ getCurrentPos │   │ level=3%      │
│               │   │ throws error  │   │               │
└───────────────┘   └───────────────┘   └───────────────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   System      │   │   Database    │   │   Memory      │
│   Crash       │   │  Corruption   │   │   Pressure    │
│               │   │               │   │               │
│ Throw:        │   │ Interrupt:    │   │ Simulate:     │
│ TestCrash     │   │ write op      │   │ 95% RAM       │
│ Exception     │   │               │   │               │
└───────────────┘   └───────────────┘   └───────────────┘
```

## Zero-Fault Response Flow

```
FAILURE DETECTED
        │
        ▼
┌───────────────────┐
│ Log to Breadcrumb │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Activate Fallback │
│ - Offline queue   │
│ - Cached location │
│ - Emergency mode  │
│ - State backup    │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Preserve Data     │
│ - Local storage   │
│ - Atomic write    │
│ - Backup copy     │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Notify User       │
│ - Show message    │
│ - Explain status  │
│ - Offer retry     │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Log to Crashlytics│
│ - Error details   │
│ - Context info    │
│ - Device state    │
└────────┬──────────┘
         │
         ▼
    SUCCESS
```

## Report Generation Flow

```
TEST SUITE COMPLETE
        │
        ▼
┌───────────────────┐
│ Collect Results   │
│ - Pass/Fail       │
│ - Reaction times  │
│ - Fallbacks used  │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Calculate Metrics │
│ - Success rate    │
│ - Avg time        │
│ - Health status   │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Generate Report   │
│ - Executive sum   │
│ - Test details    │
│ - Vulnerabilities │
│ - Recommendations │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Save to File      │
│ CHAOS_REPORT.md   │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Display Summary   │
│ - Console output  │
│ - Pass/Fail count │
│ - Exit code       │
└────────┬──────────┘
         │
         ▼
        END
```

## Test Scenario Flows

### 1. Network Blackout

```
Emergency Trigger
      │
      ▼ (500ms)
Network Loss Injected
      │
      ▼
Check Connectivity
      │
      ▼
   Offline?
      │
      ▼ Yes
Queue to OfflineQueue
      │
      ▼
Save to Local Storage
      │
      ▼
Return Success
      │
      ▼
Network Returns
      │
      ▼
Auto-Sync Queue
      │
      ▼
Verify Sent
```

### 2. GPS Loss

```
Emergency Trigger
      │
      ▼ (500ms)
GPS Disabled
      │
      ▼
Try Level 1: GPS
      │
      ▼ Failed
Try Level 2: Cached
      │
      ▼ Success
Use Cached Location
      │
      ▼
Mark as "Approximate"
      │
      ▼
Send Emergency
      │
      ▼
Notify User of Accuracy
```

### 3. Resource Exhaustion

```
Emergency Trigger
      │
      ▼
Check Battery: 3%
      │
      ▼
Critical Battery!
      │
      ▼
Activate Emergency-Only Mode
      │
      ├─ Pause background tasks
      ├─ Reduce location accuracy
      ├─ Minimize data payload
      └─ Prioritize emergency
      │
      ▼
Send Emergency
      │
      ▼
Success (minimal battery used)
```

### 4. System Kill

```
Emergency in Progress
      │
      ▼
System Kills App
      │
      ▼
Data Saved to Local
      │
      ▼
App Restarts
      │
      ▼
StartupDiagnostics Runs
      │
      ▼
Recover State
      │
      ├─ Check local storage
      ├─ Check offline queue
      └─ Resume operations
      │
      ▼
Emergency Completes
```

### 5. Database Corruption

```
Start Write Operation
      │
      ▼
Create Backup
      │
      ▼
Write New Data
      │
      ▼ (interrupted)
Crash/Interrupt
      │
      ▼
App Restarts
      │
      ▼
Integrity Check
      │
      ▼
Corruption Detected
      │
      ▼
Rollback from Backup
      │
      ▼
Data Restored
```

## Integration Points

```
┌─────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT WORKFLOW                      │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  Pre-Commit   │   │   CI/CD       │   │ Pre-Release   │
│               │   │               │   │               │
│ Run chaos     │   │ Automated     │   │ Mandatory     │
│ tests before  │   │ chaos tests   │   │ full suite    │
│ commit        │   │ on PR         │   │ run           │
└───────────────┘   └───────────────┘   └───────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ All Pass?     │
                    └───────┬───────┘
                            │
                    ┌───────┴───────┐
                   Yes             No
                    │               │
                    ▼               ▼
            ┌───────────┐   ┌───────────┐
            │ Proceed   │   │ Block     │
            │ (merge/   │   │ (fix      │
            │  deploy)  │   │  issues)  │
            └───────────┘   └───────────┘
```

## Success Path

```
┌──────────────┐
│ Write Code   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Run Tests    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ All Pass ✅  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Generate     │
│ Report       │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 100% Success │
│ Rate         │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Commit &     │
│ Release      │
└──────────────┘
```

## Failure Path

```
┌──────────────┐
│ Write Code   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Run Tests    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Test Fails ❌│
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Check Report │
│ - Which test?│
│ - Why failed?│
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Identify     │
│ Service      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Apply        │
│ Zero-Fault   │
│ Pattern      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Fix Code     │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Re-run Tests │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ All Pass ✅  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Commit &     │
│ Release      │
└──────────────┘
```

---

**Legend**:
- ✅ = Success
- ❌ = Failure
- ⏰ = Timing
- 📡 = Network
- 📍 = GPS
- 🔋 = Battery
- 💥 = Crash
- 💾 = Storage
