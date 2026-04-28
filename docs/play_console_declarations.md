# Play Console Declarations

Do not submit until this text is copied into Play Console and final public URLs are filled.

## Foreground Service `specialUse`

KoruBeni uses foreground/background reliability only for user-started safety sessions such as Safe Walk, check-in, and emergency countdown reliability. The work is tied to an active user session and stops after the session ends or is cancelled. It is not used for ads, analytics, hidden tracking, or indefinite background execution.

If `specialUse` remains declared, explanation: the app combines safety timers, user-visible check-in deadlines, and emergency countdown backup behavior that do not fit cleanly into a single standard foreground service type. The user starts the flow, sees UI/notification disclosure, and can stop it.

## `CALL_PHONE`

`CALL_PHONE` is used only after the user explicitly starts the Pro panic/SOS flow and the countdown expires. The app attempts to call the user-selected emergency contact. If the permission is denied, unavailable, or unsafe to use, the app falls back to the Android dialer so the user can place the call manually. The app does not place hidden background calls.

## `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

This permission is an optional reliability enhancement for user-started safety timers such as Safe Walk/check-in. The app continues to function if the user denies the request, but warns that timer and background reliability may be reduced. The prompt is suppressible and does not auto-show forever.

## Data Safety Summary

KoruBeni does not operate a developer backend. Most safety data is stored on device: emergency contacts, display name, optional user-selected avatar images, PIN, local activity history, fake call settings, and consent records.

Subscription status, anonymous user ID, purchase events, app/device information, and entitlement data may be handled by Google Play Billing and RevenueCat. Payment credentials are handled by Google Play and are not stored by the developer. Map screens may contact the configured map tile service, currently OpenStreetMap tile infrastructure for online map display. No advertising, user-generated content, or third-party analytics SDK is used in this release.

## App Access / Reviewer Notes

Panic/SOS is a KoruBeni Pro feature.

The free plan includes basic app access, immediate fake call, siren, emergency contact management, basic display name, map/location view where permission is granted, and legal/settings access.

Reviewer path:
Home -> locked Pro panic/SOS button -> Paywall/test purchase -> Pro entitlement active -> Home -> panic/SOS button -> long press -> emergency countdown.

Testing instructions:
- Use a Google Play license tester account or internal test track account.
- Install the Play/internal testing build.
- Open the paywall from the locked panic/SOS button or Settings -> KoruBeni Pro.
- Complete a sandbox/test purchase for the configured monthly or annual plan.
- Return to Home and verify the panic/SOS button shows active Pro copy before long press.

Manual fields still needed:
- Final public account/data deletion URL: `https://poyrazoncel34-netizen.github.io/guvenlik_app/data_deletion.html`.
- Final Play subscription product IDs and RevenueCat offering identifiers.
- Any reviewer test account notes required by the active Play test track.
