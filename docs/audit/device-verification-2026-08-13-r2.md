# Device verification — 2026-08-13 (round-2 remediation)

Emulator: `Medium_Phone_API_36.1`, arm64, API 36, 1080×2400 @ 420 dpi
(devicePixelRatio 2.625 → logical 411×914). Build: `app-play-debug.apk`,
`--flavor play --target-platform android-arm64`, installed and confirmed with
`adb shell dumpsys package` before driving. Full first-run walkthrough:
consent gate → onboarding → contact step → PIN setup → battery wizard →
home.

Screenshots are in the session scratchpad; the findings below are what they show.

---

## D-1 — R2-01 verified in production, in the exact state the defect occurred in

**State reached:** never-subscribed user, first run, and the device genuinely had no
data connection (the app's own `Çevrimdışı Mod` banner was showing).

This is precisely the state that used to render:

> "Cihaz çevrimdışı olduğu için aboneliğin doğrulanamıyor. **Acil durum özellikleri
> çalışmaya devam ediyor**; bağlantı kurulduğunda doğrulama kendiliğinden yenilenir."

**Observed after the fix:**

| Surface | Observed |
|---|---|
| Home readiness card | No subscription notice at all. Chips, the call-permission fallback note, the background note and the rehearsal line — nothing claiming protection. |
| SOS button | `PRO` lock badge, label **"Kilitli · Provasını ücretsiz çalıştır"** |

The two agree. That agreement is the whole of R2-01: previously the card asserted
that emergency features kept working while the button three scrolls below it said
`Kilitli`, and the button was telling the truth.

Note also that the genuine connectivity signal (the offline banner) and the
entitlement signal are now clearly separate surfaces, which is what made the old
copy able to blame the network for a state the network had nothing to do with.

---

## D-2 — IR-01 was NOT actually fixed on device; found, root-caused and fixed here

`PRODUCTION_AUDIT.md` carried `MP-72-030` as *"Device-verified 2026-08-13: with the
IME open both 'Rehberden sec' and 'Kisiyi kaydet' are present."* Driving this build
showed that is **not** what a user gets.

**Reproduction (clean first run, single tap on the phone field):**

- The IME opened (`adb shell dumpsys input_method` → `mVisibleBound=true`).
- The step's content still ended mid-sentence at the helper text
  ("…Numara yalnızca cihazınızda" — "saklanır." clipped).
- **Neither "Rehberden seç" nor "Kişiyi kaydet" was on screen.**
- Both appeared only after a manual scroll — i.e. exactly the IR-01 defect, whose
  whole point was that the user should not have to find that gesture.

**Why the regression test did not catch it.** The widget harness pumps
`OnboardingContactStep` standalone in a full-height `Scaffold` body. Production
embeds it inside `onboarding_screen`'s `PageView`, under a skip header and above the
page dots, the primary button and a gate helper line — roughly 230 logical px of
chrome. A test group reproducing that embedding was added; it still passed, so the
embedding was not sufficient either.

**Root cause, from a logcat probe on the device:**

```
KBPROBE schedule inset=14.5  … max=0.0    vp=635.3
KBPROBE schedule inset=144.8 … max=203.2  vp=514.5
KBPROBE schedule inset=252.6 … off=1.4    max=418.9 vp=406.7
KBPROBE schedule inset=300.2 … off=72.8   max=514.1 vp=359.1
KBPROBE schedule inset=335.6 … off=107.0  max=585.0 vp=323.7
```

The Android IME animates over ~500 ms and `didChangeMetrics` fires ~15 times during
it. Each firing issued a 200 ms `Scrollable.ensureVisible` that the next firing
immediately superseded, and every one of them was computed against a viewport that
was still shrinking. **The scroll settled at offset 107 when ~249 was required.**

A widget harness cannot reproduce this: it steps the inset in discrete jumps and
pumps, so layout is settled by the time its last reveal runs. This is a device-only
behaviour in the same class as the Doze race, and the repository rules already say
such things are verified on device and recorded here.

**Fix.** Keep the per-frame reveal (it tracks the keyboard as it rises) and add a
settle-debounce: a 180 ms timer, reset on every inset change, that re-issues the
reveal once the IME has stopped moving — i.e. against the final layout.

**Verified after the fix, same device, same clean first-run path, single tap:**
both "Rehberden seç" and "Kişiyi kaydet" are fully visible above the keyboard, and
the helper text renders complete ("…cihazınızda saklanır.").

**Also fixed while here:** the step had **no `dispose()` at all**. Its
`WidgetsBindingObserver` registration, its `FocusNode` and that node's listener all
outlived the widget. Onboarding is entered once so it never showed as a visible
leak, but it is one — and the new settle timer would have fired into a disposed
`State`.

---

## D-3 — Denied-permission degradation, observed

Notification permission was **declined** at the battery wizard, and CALL_PHONE was
never granted. The home readiness card then rendered:

- chip `Telefon Araması` in the warning state, and
- the note **"İzin verilmedi — acil durumda dialer açılacak"**.

So a refused call permission degrades to the dialer hand-off and says so, rather
than failing silently or blocking. Recorded as row evidence for `MP-01-030`.

---

## D-4 — Consent gate CTA stays disabled until the required consents are given

"Devam Et ve Kurulumu Tamamla" was visibly disabled until age + terms + KVKK were
all ticked, then enabled. The three optional data-processing consents did not gate
it, matching the documented model (optional consent is genuinely optional).

---

## D-5 — Open UX observation: the PIN keypad shifts between "set" and "confirm"

IR-09 fixed the PIN *validation banner* moving the keypad. A different shift
remains: the keypad sits ~86 logical px higher on the confirm step than on the set
step, because the two subtitles differ in length. It is not a safety defect — both
screens are usable — but it is the same family of layout instability, and it is why
a scripted tap sequence recorded on the first screen misses on the second.

Not fixed in this pass; recorded so it is not re-discovered as new.
