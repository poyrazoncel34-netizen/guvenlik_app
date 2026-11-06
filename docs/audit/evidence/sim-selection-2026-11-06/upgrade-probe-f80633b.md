device: emulator-5560 fingerprint=Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys Physical density: 420

| step | result | detail |
|---|---|---|
| old build installed | PASS | app-play-debug.apk lastUpdateTime=2026-11-06 16:32:39 |
| offline Pro anchor present (test-only, root) | PASS |  |
| old build: CALL_PHONE granted, READ_PHONE_STATE not declared | PASS | CALL_PHONE=true READ_PHONE_STATE=absent |
| old build reaches home | PASS |  /  /  /  /  |
| new build installed over old (adb install -r) | PASS | lastUpdateTime=2026-11-06 16:34:48 |
| after upgrade: CALL_PHONE kept, READ_PHONE_STATE declared but not granted | PASS | CALL_PHONE=true READ_PHONE_STATE=false |
| first start after upgrade shows the SIM disclosure | PASS |  /  /  /  /  /  |
| after accept: READ_PHONE_STATE granted | PASS | OS dialog shown=False; READ_PHONE_STATE=true CALL_PHONE=true |
| second start: not asked again | PASS |  /  /  /  /  |
| offer flag persisted | PASS |  |
