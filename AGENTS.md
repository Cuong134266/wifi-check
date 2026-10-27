# Agent guide

## Scope

Flutter attendance app for UXTeam, targeting Web, Android, and iOS. It talks to a deployed Google Apps Script backend. The backend remains authoritative for auth, settings, attendance, QR sessions, leave, history, and ranking.

## Verified architecture

- Entry point: `lib/main.dart` initializes `ApiService`, Google Sign-In, then opens `CheckinScreen`.
- Main orchestration: `lib/screens/checkin_screen.dart` contains sign-in, check-in gates, QR, leave, history, ranking, and sheet navigation.
- API client: `lib/services/api_service.dart` wraps Apps Script requests; web uses GET params, native uses POST and manual redirects.
- Check-in gates: `LocationService` verifies configured office radius; `PublicIpService` verifies configured public IP/DDNS; `WifiService.getInfo()` gathers native Wi-Fi metadata but is not currently used to reject attendance.
- QR: `QrCheckinService` parses/submits tokens; `QrScannerScreen` handles the camera.
- Leave/history/admin: thin service calls and dedicated sheets.
- LUNE Tarot: embedded `assets/lune/` web app bridged through `lib/widgets/lune_tarot_checkin*.*`; card data is sent to `CheckinBottomSheet`.
- Conditional platform adapters: Wi-Fi, map, web sign-in, and LUNE imports switch on `dart.library.html`/`dart.library.js_util`.

## Operational rules for assistants

- Before changing behavior, read the relevant source; do not infer from this guide alone.
- Keep backend actions and semantics authoritative; never hardcode a new backend action without confirming the endpoint.
- Web cannot inspect Wi-Fi hardware; location and public IP are the enforced checks. Native Wi-Fi metadata may be collected but is not currently a rejection gate.
- The current workbook has one `dailyMessage` per Tarot card. The product asks for 7–10 variants, but that source data has not been supplied; do not silently fabricate it.
- Generated deployment output is `build/web`; `docs/` is the publish tree and must be refreshed only with the correct `/wifi-check/` base href.
- Do not commit `.claude/` or unrelated local artifacts. Do not put secrets, access tokens, private IDs, employee data, or production credentials into docs or tests.

## Validation baseline

Use `dart format`, `flutter analyze`, and `flutter test` for code changes. Build web release with `flutter build web --release --base-href /wifi-check/`; on Git Bash for Windows, prefix `MSYS_NO_PATHCONV=1` if slash-prefixed args are rewritten.

## Context map

Load `.ai/project-map.yaml` for directory/module facts, `.ai/task-routes.yaml` to choose files by task, and `.ai/modules/<module>.md` for focused module notes. Keep these files updated from Git diffs and source reads.
