# Android Screenshots

Canonical upload folder: `store/screenshots/android/final/`.

Files directly under `store/screenshots/android/` are non-canonical source/reference captures and currently differ from the final set. Do not upload them unless the final set is regenerated and reviewed.

Required upload files:

- `final/01_home_locked_panic.png`
- `final/02_contacts.png`
- `final/03_settings_legal.png`
- `final/04_map.png`

Release builds set FLAG_SECURE, so `adb shell screencap` returns a black frame
against them. Capture store screenshots from a DEBUG build
(`scripts/capture_screenshots.sh`), which is exempt by design.

Before Play upload, manually verify:

- no real names
- no real phone numbers
- no real emails
- no precise home/work address
- no sensitive map coordinates
- no private account data
- no accidental personal profile info

Format: PNG or JPEG. Count: min 2, max 8. Recommended size: 1080x1920 or 1080x2340.
