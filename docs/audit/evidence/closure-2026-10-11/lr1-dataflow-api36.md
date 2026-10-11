### LR-1 Phase A — runtime data-flow inventory — API 36 (KoruBeni_API36, emulator-5558, 420 dpi, -no-audio)

Build: `app-play-debug.apk` from the LR-1 working tree. Emulator geo fix
`41.00824 / 28.97837`. Capture: on-device `tcpdump -i any -s 0`.
No third party was ever called; the only number used is the emulator's own
`05551234567`.

**Two of the twelve rows below were taken by HAND, not by `tools/lr1_dataflow_probe.py`.**
The probe drives Check-In correctly but mis-drives Safe Walk and Panic: Safe Walk
needs an explicit `Yürüyüşe Başla` button after the duration tile (Check-In arms on
the tile alone), and Panic shows a first-use information sheet. Rather than keep
iterating the driver, those two were performed manually and their observations are
recorded verbatim. They are marked MANUAL so nobody mistakes them for probe output.

| # | Question | Result | Observed |
|---|---|---|---|
| Q8/Q9 | Check-In arms with location REVOKED | **PASS** | `appops COARSE/FINE = ignore`, native `armed`, fg `com.poyrazoncel.korubeni` (probe) |
| Q8/Q9 | Safe Walk arms with location REVOKED | **PASS (MANUAL)** | `appops COARSE/FINE = ignore` → Güvenli Yürüyüş → `30 dk` → `Yürüyüşe Başla` → info sheet acknowledged → native **`armed`**, countdown `29:47`. No location permission prompt appeared. |
| Q8/Q9 | Panic runs with location REVOKED | **PASS (MANUAL)** | `appops COARSE/FINE = ignore` → panic held → info sheet → panic held → countdown "Acil uyarı devreye giriyor / 1 saniye kaldı / Acil kişi: Annem" → deadline reached → native `requestSubmittedUnconfirmed`, **Telecom 0 → 1**. The whole flow never mentioned or requested location. |
| Q7 | Map never opened → OSM requests | **PASS** | `osmHits = 0` across the entire phase-1 capture |
| Q1/Q2 | A developer backend receives coordinates | **PASS (none exists)** | the only HTTPS host in `lib/` is `tile.openstreetmap.org` (`app_environment.dart`); there is no backend in the repo |
| Q3/Q4/Q6 | The Map contacts OSM | **PASS (MANUAL)** | opening the Harita tab produced **120 cached tiles**; map screen label reads "Harita. Konumunuzu gösterir." with the coordinates rendered on screen |
| Q5 | Tile zoom levels actually requested | **PASS (MANUAL)** | cache layout `files/osm_tiles_v1/15/<x>/<y>.png` and `…/16/…` → **z = 15 and 16** |
| Q1/Q3 | Raw GPS coordinate anywhere on the wire | **PASS** | `41.00824` / `28.97837` / `41.008` / `28.978` searched across the full pcap → **not found**. Tile URLs carry `z/x/y`; TLS encrypts the path in either case. |
| Q10 | Coordinates persisted to prefs / DB / secure storage | **PASS** | `grep -rl` over `/data/data/<pkg>` and `/data/user_de/0/<pkg>` → no match outside `kernel_blob.bin` (Dart code) and the tile cache |

#### Instruments that did NOT work here, and why that matters

- `cmd appops get <pkg>` and `dumpsys appops --package <pkg>` print only the MODE
  (`foreground` / `ignore`) on this system image — **no per-access timestamps**.
  `dumpsys location` carries no per-package history either. An earlier version of
  this probe compared those strings before and after each flow and reported PASS /
  FAIL from them; the strings are identical by construction, so those verdicts were
  meaningless in both directions. They were replaced by the permission-revoked
  experiment above, which is behavioural and conclusive.
- Revoking a runtime permission **restarts the app process**. The revoke must come
  before the launch, or the measurement lands on the launcher.

#### Device state after the run

Location permission was left REVOKED by the last manual step. Any later probe on
this emulator must grant it again (`pm grant … ACCESS_FINE_LOCATION`) or it will
measure a device that cannot read location at all.
