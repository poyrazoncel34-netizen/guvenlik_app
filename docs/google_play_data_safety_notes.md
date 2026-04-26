# Google Play Data Safety Notes

Release note: KoruBeni has no developer-operated backend. Most safety data is stored locally on the device. Subscription and billing data is processed by Google Play Billing and RevenueCat. Online map screens may contact the map tile provider.

| Data | Collected | Shared / processed by third party | Purpose | Optional | Encrypted in transit | Deletion / request path | SDK / service |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RevenueCat anonymous app user ID | Yes, for Pro users / purchase flow | Yes | Subscription verification and entitlement state | Required for Pro purchases | Yes, provider transport | Restore/cancel via Google Play; contact support for privacy requests | RevenueCat |
| Purchase events and entitlement status | Yes, for Pro users / purchase flow | Yes | Unlock and restore KoruBeni Pro | Required for Pro purchases | Yes | Managed through Google Play subscriptions and RevenueCat | Google Play Billing, RevenueCat |
| Payment card credentials | No by developer | Processed by Google Play | Payment processing | Required only for purchase | Yes by Google Play | Google Play account controls | Google Play Billing |
| Location data | Yes, when user grants permission and opens map/location/emergency flows | Map tile requests may contact provider; developer backend does not receive it | Map view, location session, emergency context | Optional until related feature is used | Yes for provider network calls where applicable | Clear app data or in-app data deletion | Android location services, map provider |
| Emergency contacts | Yes, if user adds contacts | No developer backend sharing; Android call/dialer uses selected number during user-started flow | Contact management and panic call flow | Optional | Local storage; no network transfer by developer | In-app contact deletion or device data deletion | Local SQLite / Android Contacts picker |
| Profile name | Yes, optional | No | Personalize local profile | Optional | Local only | In-app data deletion / clear app data | SharedPreferences / secure storage |
| Device identifiers / app info | Limited app/device info for subscription SDK | Yes, RevenueCat / Google Play | Subscription fraud prevention, entitlement verification | Required for Pro purchases | Yes | Contact support / provider account controls | RevenueCat, Google Play Billing |
| App interactions / local activity timeline | Yes, local events | No developer backend sharing | Local safety history | Optional / feature driven | Local only | In-app data deletion | Local database |
| Crash logs | Local only if generated | No third-party crash SDK in this release | Local diagnostics | N/A | Local only | Clear app data | Local crash log service |
| Map tile requests | Yes, when map is opened online | Yes, map provider receives technical request | Display map tiles | Optional | Yes if provider endpoint uses HTTPS | Provider policies; clear app data for local state | OpenStreetMap tile endpoint currently |

User deletion:
- In app: Settings -> Legal Information -> Delete My Data.
- Android system: Settings -> Apps -> KoruBeni -> Storage -> Clear data.
- Subscription cancellation is separate: Google Play -> Subscriptions.
- Public deletion URL: `https://poyrazoncel34-netizen.github.io/guvenlik_app/data_deletion.html`.
