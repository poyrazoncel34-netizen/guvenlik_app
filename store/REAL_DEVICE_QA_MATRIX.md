# Real-Device QA Matrix

Runtime/device execution is forbidden in this repo audit. Emulator, adb, `flutter run`, installs, and Play Billing runtime purchase flows are not accepted as substitute evidence.

All rows default to NOT_RUN until an operator supplies physical-device evidence. Production readiness depends on required Android 13 and Android 14 rows being PASS.

Minimum device coverage:

| Device set | Requirement |
| --- | --- |
| Android 13 physical device | Required |
| Android 14 physical device | Required |
| Android 15 physical device | Optional but recommended |
| Aggressive OEM battery device such as Samsung/Xiaomi/Oppo | Optional but recommended |

## Matrix

| ID | device/OS | precondition | steps | expected result | actual result | evidence | severity if failed | status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| QA-001 | Android 13 + Android 14 physical | Fresh install build available | Install from Play internal/closed track | App opens first-run flow without crash |  |  | Critical | NOT_RUN |
| QA-002 | Android 13 + Android 14 physical | Fresh install | Set device/app locale TR | TR UI and native notifications show Turkish copy |  |  | High | NOT_RUN |
| QA-003 | Android 13 + Android 14 physical | Fresh install | Set device/app locale EN | EN UI and native notifications show English copy |  |  | High | NOT_RUN |
| QA-004 | Android 13 + Android 14 physical | Notification prompt available | Deny notification permission | App shows denied/degraded path and does not crash |  |  | High | NOT_RUN |
| QA-005 | Android 13 + Android 14 physical | Notification permission denied once | Permanently deny notifications in system settings | App explains degraded behavior and continues safely |  |  | High | NOT_RUN |
| QA-006 | Android 13 + Android 14 physical | Location prompt available | Deny location permission | Map/safety flows show unavailable state, no fake coordinates |  |  | High | NOT_RUN |
| QA-007 | Android 13 + Android 14 physical | Exact alarm permission available | Deny exact alarm permission | App uses fallback/degraded path and avoids guarantee language |  |  | Critical | NOT_RUN |
| QA-008 | Android 13 + Android 14 physical | Battery optimization not exempted | Start safety timer without exemption | App warns reliability may be reduced; no guarantee claim |  |  | High | NOT_RUN |
| QA-009 | Android 13 + Android 14 physical | Pro entitlement active | Start Safe Walk | Safe Walk starts with visible state and notification where applicable |  |  | Critical | NOT_RUN |
| QA-010 | Android 13 + Android 14 physical | Safe Walk active | Stop Safe Walk | Timer/alarm/foreground service stops; persistent notification clears |  |  | Critical | NOT_RUN |
| QA-011 | Android 13 + Android 14 physical | Safe Walk active | Let Safe Walk timeout | Timeout/grace/emergency path behaves as designed |  |  | Critical | NOT_RUN |
| QA-012 | Android 13 + Android 14 physical | Pro entitlement active | Start Check-in | Check-in starts with expected timer/deadline |  |  | Critical | NOT_RUN |
| QA-013 | Android 13 + Android 14 physical | Check-in active | Let check-in expire | Expiry notification and event path fire as expected |  |  | Critical | NOT_RUN |
| QA-014 | Android 13 + Android 14 physical | Check-in with grace active | Enter grace period | Grace notification appears in device locale |  |  | Critical | NOT_RUN |
| QA-015 | Android 13 + Android 14 physical | Grace period active | Let grace period expire | Emergency dispatch path starts as designed |  |  | Critical | NOT_RUN |
| QA-016 | Android 13 + Android 14 physical | Safety session active | Reboot device during active session | Boot recovery restores or expires session with localized notification |  |  | Critical | NOT_RUN |
| QA-017 | Android 13 + Android 14 physical | Safety session active | Kill app process during active session | Expected alarm/notification/degraded behavior occurs |  |  | Critical | NOT_RUN |
| QA-018 | Android 13 + Android 14 physical | CALL_PHONE granted, Pro active | Start Panic/SOS and let countdown finish | Direct call path starts only after explicit flow/countdown |  |  | Critical | NOT_RUN |
| QA-019 | Android 13 + Android 14 physical | CALL_PHONE denied, Pro active | Start Panic/SOS and let countdown finish | `ACTION_DIAL` fallback opens for manual confirmation |  |  | Critical | NOT_RUN |
| QA-020 | Android 13 + Android 14 physical | Telephony app available | Trigger denied/unavailable direct call path | Dialer fallback opens safely |  |  | Critical | NOT_RUN |
| QA-021 | Android 13 + Android 14 physical | Siren feature available | Start siren in safe test environment | Siren is audible and controls work |  |  | High | NOT_RUN |
| QA-022 | Android 13 + Android 14 physical | Device volume known | Start and stop siren | Volume is restored after siren stops |  |  | High | NOT_RUN |
| QA-023 | Android 13 + Android 14 physical | Fake call feature available | Start immediate fake call | Simulated call screen appears; no real call placed |  |  | Medium | NOT_RUN |
| QA-024 | Android 13 + Android 14 physical | Notifications available | Schedule delayed fake call | Delayed fake call notification/screen appears as expected |  |  | Medium | NOT_RUN |
| QA-025 | Android 13 + Android 14 physical | Contacts available | Use contact picker | Picker returns selected contact or safe cancel path |  |  | High | NOT_RUN |
| QA-026 | Android 13 + Android 14 physical | Network disabled or map unavailable | Open map/location session | Offline/unavailable fallback is clear and no crash occurs |  |  | High | NOT_RUN |
| QA-027 | Android 13 + Android 14 physical | App data exists | Export data | Export contains expected local data only |  |  | Medium | NOT_RUN |
| QA-028 | Android 13 + Android 14 physical | App data exists | Delete device data | Data is deleted locally and app returns to setup flow |  |  | High | NOT_RUN |
| QA-029 | Android 13 + Android 14 physical | App notification channels created | Open Android notification channel settings | Only `emergency_alerts`, `service_status`, and `general_notifications` active channels are shown for app safety notifications |  |  | High | NOT_RUN |
| QA-030 | Android 13 + Android 14 physical | RevenueCat offering unavailable | Open paywall | No-offering fallback appears and app does not crash |  |  | High | NOT_RUN |
| QA-031 | Android 13 + Android 14 physical | License tester, monthly product configured | Buy monthly subscription | Purchase succeeds and Pro entitlement activates |  |  | Critical | NOT_RUN |
| QA-032 | Android 13 + Android 14 physical | License tester, annual product configured | Buy annual subscription | Purchase succeeds and Pro entitlement activates |  |  | Critical | NOT_RUN |
| QA-033 | Android 13 + Android 14 physical | Existing tester purchase | Restore purchase with same Google account | Pro entitlement restores |  |  | Critical | NOT_RUN |
| QA-034 | Android 13 + Android 14 physical | Existing tester purchase | Open cancel/manage subscription path | Google Play manage flow opens and return path is safe |  |  | High | NOT_RUN |
| QA-035 | Android 13 + Android 14 physical | Account may require closed testing | Verify tester opt-in | Tester is opted in before testing; 12 testers/14 days tracked if required |  |  | Release blocker | NOT_RUN |

## Evidence Requirements

Evidence should include device model, Android version, app version/build, locale, test account type when billing is involved, screenshot/video/log excerpt where appropriate, date, operator name, and PASS/FAIL/BLOCKED result.

Do not mark PASS from emulator, simulator, adb-only output, Play Console assumptions, RevenueCat assumptions, or repo-only static review.
