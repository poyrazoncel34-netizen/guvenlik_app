# Feature Matrix Verification

Single source of truth: `lib/core/constants/feature_access_matrix.dart`.

| Feature | Matrix tier | Store listing claim | Status |
| --- | --- | --- | --- |
| Basic app access | Free | Free basic safety tools | OK |
| Fake call immediate | Free | Free feature | OK |
| Siren | Free | Free feature | OK |
| Emergency contact management | Free | Free feature | OK |
| Basic profile name | Free | Privacy/settings local profile | OK |
| Basic map/location view | Free | Free map (own position) | OK |
| Legal/privacy/settings access | Free | Legal links and privacy sections | OK |
| Panic/SOS button | Pro | Explicitly KoruBeni Pro; not available on free plan | OK |
| Emergency countdown | Pro | Panic/SOS Pro flow includes countdown | OK |
| Emergency contact call triggered by panic | Pro | Described only as part of Pro panic/SOS | OK |
| Safe Walk | Pro | Pro feature | OK |
| Check-in | Pro | Pro feature | OK |
| Activity timeline / safety history | Free | Free local history/plan note | OK |
| Volume trigger | Pro | Pro feature | OK |
| Test mode | Free | Free rehearsal; no real call | OK |

Verification flags:
- `PremiumFeature.panic` is not in `FeatureAccessMatrix.freeFeatures`.
- `SubscriptionGate` reads from `FeatureAccessMatrix`.
- Paywall benefits use `FeatureAccessMatrix.proBenefitKeys`.
- No store or paywall benefit claims an unimplemented advanced-automation feature.
- Store listing does not claim free panic/SOS.
