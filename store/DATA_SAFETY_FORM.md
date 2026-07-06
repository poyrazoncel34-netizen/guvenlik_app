# Play Console Data Safety Form Answers

Dashboard completion is PLAY_CONSOLE / NEEDS_OPERATOR_ACTION. This file prepares conservative copy and must be reconciled with the final Play Console form before submission.

Testing track nuance: Play Console internal testing may not require the Data Safety section before the first internal rollout, depending on the account/app state. Closed testing, open testing, and production submission require the Data Safety form where Play Console presents it. Legal/privacy docs must still match the shipped build before any internal test is shared.

## General Answer

**Does your app collect or share any of the required user data types?**  
Answer: Yes, because optional Pro subscription processing uses Google Play Billing / RevenueCat, and online map screens may contact the configured map tile provider.

Do not mark local-only data as developer-collected/shared merely because it is stored on the device.

## Data Types

| Data type | Play Console stance | Notes |
| --- | --- | --- |
| Location | Conservative disclosure needed for map/location sessions | Location is used only when the user opens map/location features or triggers safety flows. No developer backend receives it. Online map tile requests may reveal map viewport/network metadata to the tile provider. |
| Contacts | Local-only unless the user invokes Android call/contact flows | The app does not read the full contacts list. It stores only emergency contacts selected or entered by the user, locally on the device. Do not claim developer collection/sharing if no off-device transfer is introduced. |
| Optional profile name | Local-only | Device-only personalization. |
| Optional photos/images | Local-only | User-selected fake-call avatar images stay on device; no cloud upload. |
| Phone number | Not collected by developer | Emergency contact numbers are stored locally and may be used by Android telephony when the user starts a call flow. |
| Purchase history / subscription status | Processed by Google Play Billing and RevenueCat | Required for optional KoruBeni Pro entitlement verification and restore. |
| Anonymous app/device/subscription identifiers and IP address (connection-level) | Processed by RevenueCat / Google Play Billing where applicable | Used for purchase verification, entitlement status, fraud prevention, and restore. |
| Payment card credentials | Not collected by developer | Handled by Google Play. |
| Crash logs / analytics / ads data | Not collected in this release based on repo verification | No Firebase Analytics, Crashlytics, Sentry, ads SDK, UGC, auth backend, or cloud database in current Play build. |
| Audio / microphone | Not collected | Android Play release does not request microphone permission or record audio. |

## Copy-Paste Summary

```text
KoruBeni does not operate a developer backend. Emergency contacts, profile data, PIN, fake-call settings, local activity history, and consent records are stored on device. The app does not read the full contacts list; it stores only emergency contacts selected or entered by the user, locally on the device. Optional Pro subscription processing is handled by Google Play Billing and RevenueCat. Online map screens may request map tiles from the configured map tile provider, currently OpenStreetMap tile infrastructure, only for the map viewport the user actively opens. The app does not bulk download, scrape, pre-seed, archive, or package OpenStreetMap public tiles. The app does not use ads, analytics, crash reporting SDKs, auth backend, cloud database, SMS sending, microphone, audio recording, account creation, or user-generated content in this Play release.
```

## Sharing

```text
The app does not automatically share emergency contacts, location, profile data, or safety history with a developer backend. Emergency calls use Android telephony when explicitly started by the user. Google Play Billing, RevenueCat, and the configured map tile provider have their own technical network behavior.
```

## Security Practices

- Data sold: No.
- Developer backend: No developer-operated backend in this release.
- Encryption in transit: do not mark blanket "Yes" for all data. Local-only data is not transmitted to a developer backend; map, Google Play Billing, and RevenueCat traffic are provider-controlled.
- Users can request data deletion: Yes. Deleting app data removes on-device data; subscription cancellation remains managed through Google Play.

## Not Used

```text
Firebase auth, cloud database, analytics, crash reporting SDK, ads, UGC, developer backend, SMS sending, microphone/audio recording.
```

## Manual Gate

Status remains PLAY_CONSOLE until the operator verifies Play Console requirements for the selected track. Internal testing may be allowed before Data Safety submission, but closed/open/production testing and production must not proceed until the submitted form matches the final build, SDK list, map provider behavior, RevenueCat setup, and store/legal copy.
