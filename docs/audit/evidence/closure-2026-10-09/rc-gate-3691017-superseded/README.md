# RC 3691017 — superseded

Gate and device runs on RELEASE_CANDIDATE_HEAD `3691017` (2026-10-10 09:45–11:10). Kept because this run
FOUND a defect: on the API 29 emulator a force-stop deleted an armed Check-In's alarms and reopening
the app restored none (`upgrade-v102-to-rc.out.txt` "force-stop -> reopen: alarms=0", then reproduced
by hand: 4 -> 0 -> 0). Fixed in `39ccb2f` + `cdc4024`; every result here is therefore INVALID for the
final RC and was re-run on it (`../rc-gate/`).

Also in this run (all on 3691017, for the record only):
- `attempt1-*`: chaos seed 20261013 sat 60+ sequences on an ANR dialog the old driver never saw;
  the ANR is the emulator GNSS HAL deadlock (`attempt1-anr-gnss-deadlock-evidence.txt`) — environment.
- `human-chaos-rc-api35.*`: chaos seed 20261014, 110/110 OK with the ANR-aware driver.
- `runtime-matrix-rc-smoke-release.run1-wrong-extra-key.md`: the widget step failed because the
  script sent `<smoke package>.extra.PANIC_SOURCE`; the trampoline correctly refused it (fail-closed).
- `lockout-matrix-api36-rc.txt` step 15: the probe counted only the home screen as "unlocked".
