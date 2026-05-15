# Play Console Forms Checklist

No Play Console dashboard action is completed by this repo audit. Every submission item below is PLAY_CONSOLE / NEEDS_OPERATOR_ACTION until the operator records external evidence.

## Form Sources

| Form / App content item | Prepared source | Status |
| --- | --- | --- |
| Data Safety | `store/DATA_SAFETY_FORM.md` | CODE_DONE copy prepared; internal testing may be exempt; PLAY_CONSOLE submit for closed/open/production when Play requires it |
| Content Rating | `store/CONTENT_RATING_ANSWERS.md` | CODE_DONE copy prepared; PLAY_CONSOLE submit |
| Target Audience | `store/CONTENT_RATING_ANSWERS.md` and `docs/play_console_declarations.md` | CODE_DONE recommendation; PLAY_CONSOLE submit |
| Foreground service specialUse | `docs/play_console_declarations.md` | CODE_DONE copy prepared; PLAY_CONSOLE submit |
| SCHEDULE_EXACT_ALARM | `docs/play_console_declarations.md` | CODE_DONE copy prepared; PLAY_CONSOLE submit if required |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | `docs/play_console_declarations.md` | CODE_DONE copy prepared; PLAY_CONSOLE submit if required |
| CALL_PHONE | `store/permissions_declaration_notes.md` | CODE_DONE copy prepared; PLAY_CONSOLE submit if required |
| Privacy policy URL | `store/release_checklist.md` | CODE_DONE URL prepared; NEEDS_OPERATOR_ACTION verify live URL and PLAY_CONSOLE submit |
| Data deletion URL | `store/release_checklist.md` | CODE_DONE URL prepared; NEEDS_OPERATOR_ACTION verify live URL and PLAY_CONSOLE submit |

## Data Safety Guardrails

- Be accurate and conservative.
- Internal testing may be exempt from Data Safety depending on Play Console state; closed/open/production testing and production require the form when Play presents it.
- Legal/privacy docs must still match the build before internal testing.
- Do not claim local-only data is collected/shared merely because it is stored on device.
- Mention Google Play Billing and RevenueCat subscription processing for optional Pro.
- Mention OSM/configured map tile requests when maps are disclosed.
- Mention no analytics, ads, crash SDK, auth backend, cloud DB, SMS sending, microphone, or audio recording only if final build verification still matches current repo.
- Do not mark blanket encryption-in-transit for local-only data or provider-controlled flows.

## Content Rating / Target Audience

- Intended audience: adults / 18+.
- Do not enter Designed for Families unless the product decision changes and the app/legal/store copy is reworked.
- Complete the IARC questionnaire according to the final build behavior.

## Completion Checklist

| Item | Status | Evidence |
| --- | --- | --- |
| Data Safety submitted or internal-testing exemption evidenced | PLAY_CONSOLE | Not supplied |
| Content Rating certificate obtained | PLAY_CONSOLE | Not supplied |
| Target Audience submitted | PLAY_CONSOLE | Not supplied |
| FGS declaration submitted | PLAY_CONSOLE | Not supplied |
| Exact alarm declaration submitted if required | PLAY_CONSOLE | Not supplied |
| Battery optimization declaration submitted if required | PLAY_CONSOLE | Not supplied |
| CALL_PHONE declaration submitted if required | PLAY_CONSOLE | Not supplied |
| Privacy URL submitted and live | NEEDS_OPERATOR_ACTION / PLAY_CONSOLE | Not supplied |
| Data deletion URL submitted and live if applicable | NEEDS_OPERATOR_ACTION / PLAY_CONSOLE | Not supplied |
