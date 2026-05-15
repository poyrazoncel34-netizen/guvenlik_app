# Release Risks

## OpenStreetMap Tiles

The app currently uses `https://tile.openstreetmap.org/{z}/{x}/{y}.png` directly for the in-app map. Attribution is visible and a package user agent is set, but this endpoint is not intended as an enterprise-grade production tile service.

Before a larger production launch, switch to a production-suitable provider such as MapTiler, Stadia, Thunderforest, Mapbox, or a self-hosted tile service with a proper API key and quota policy.

Current mitigation:
- OSM attribution is shown in the map UI.
- `userAgentPackageName` is configured.
- The app only requests tiles for the map viewport the user actively opens.
- The app must not bulk download, scrape, pre-seed, cache as an offline archive, or package OpenStreetMap public tiles.
- Store/legal copy does not claim enterprise-grade map reliability.

## Manual Play Console Items

- Public privacy and data deletion URLs are prepared; operator must verify hosted pages stay live before release.
- Confirm RevenueCat products, offering IDs, and Google Play subscription products match.
- Complete Play Console content rating and target audience with adult / 18+ intended audience notes.
- Submit Data Safety accurately; do not mark local-only data as developer-collected/shared unless the final build transmits it.
- Copy `docs/play_console_declarations.md` into the corresponding declaration fields.
- Submit foreground service type declaration for Android 14+ targets, and exact alarm / battery optimization declarations if Play Console requires them.
- Use screenshot upload path `store/screenshots/android/final/` and complete manual PII review.
- Verify Play icon is 512x512 PNG and feature graphic is 1024x500.

## Runtime And Production Gates

- Real-device QA is not complete. Emulator evidence is not accepted for production readiness.
- Billing is not complete. Monthly purchase, annual purchase, restore, cancel/manage, no-offering, and network-failure fallback must be tested through Play test tracks and license testers.
- Production is DO_NOT_CLAIM_READY until Play Console forms, billing tests, Android 13/14 physical-device QA, screenshot PII review, and closed testing if required are complete with evidence.
