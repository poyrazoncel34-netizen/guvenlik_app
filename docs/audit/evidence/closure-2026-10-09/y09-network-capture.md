# Y-09 — runtime network observation (API 36, emulator `-tcpdump`)

Build `0353522` debug (APK sha1 `0006967c0ff5…`, lastUpdateTime 2026-10-09 13:59:02), location granted,
`adb emu geo fix 28.97837 41.00824`.

Capture 1 (13:58–14:01): app in "offline" state, tiles served from the on-device cache; the capture holds only
boot-time OS traffic (connectivitycheck.gstatic.com, time.android.com, www.google.com). Not usable as proof of tile traffic.

Capture 2 (14:02–14:04, network verified with `ping tile.openstreetmap.org` 0% loss; tile cache deleted first):
| Source | Host (DNS query / TLS SNI) | Count |
|---|---|---|
| app (map screen) | `tile.openstreetmap.org` | DNS A×3 + AAAA×1; TLS ClientHello ×30 |
| Android OS | `remoteprovisioning.googleapis.com`, `connectivitycheck.gstatic.com`, `time.android.com`, `www.google.com` | boot / platform |

No other host. No developer backend (there is none). No RevenueCat traffic (debug build, no API key).
TLS payloads are encrypted: the request paths are not visible in the capture. By SOURCE the tile URL is
`https://tile.openstreetmap.org/{z}/{x}/{y}.png` (no raw coordinates); that the tile x/y of the map centred on the
user narrows the user's approximate area is INFERENCE. After the session the app cache held 130 files under
`files/osm_tiles_v1/15/19569/…` (tile bodies + metadata). Coordinates searched across `/data/data/<pkg>` and
`/data/user_de/0/<pkg>`: only `kernel_blob.bin` (debug Dart kernel, code) matched; no database / prefs / file holds them.
The device-data reset deletes the application-support directory, which contains the tile cache (source: `app_reset_service.dart`).
