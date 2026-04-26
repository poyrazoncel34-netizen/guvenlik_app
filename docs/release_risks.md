# Release Risks

## OpenStreetMap Tiles

The app currently uses `https://tile.openstreetmap.org/{z}/{x}/{y}.png` directly for the in-app map. Attribution is visible and a package user agent is set, but this endpoint is not intended as an enterprise-grade production tile service.

Before a larger production launch, switch to a production-suitable provider such as MapTiler, Stadia, Thunderforest, Mapbox, or a self-hosted tile service with a proper API key and quota policy.

Current mitigation:
- OSM attribution is shown in the map UI.
- `userAgentPackageName` is configured.
- Store/legal copy does not claim enterprise-grade map reliability.

## Manual Play Console Items

- Public data deletion URL is `https://poyrazoncel34-netizen.github.io/guvenlik_app/data_deletion.html`; verify the hosted page stays live before release.
- Confirm RevenueCat products, offering IDs, and Google Play subscription products match.
- Complete Play Console content rating with 18+ intended audience notes.
- Copy `docs/play_console_declarations.md` into the corresponding declaration fields.
