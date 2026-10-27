# New contributor onboarding

## What this product is

This repository contains UXTeam, a Flutter attendance app used by employees to check in against company location/network rules. The app supports Android, iOS, and Web. Its home screen combines attendance status with user/account data, and it provides QR attendance, leave requests, history/ranking, and an optional LUNE Tarot reflection.

This is an existing product, not a starter Flutter template. The client depends on a deployed Google Apps Script backend for employee identity, settings, attendance, QR sessions, leave requests, history, and ranking. Backend behavior and records are authoritative; the Flutter client does not define the server-side business rules.

## Product outcomes

- Make employee check-in understandable and quick on mobile and web.
- Enforce the configured office location and public network rules before normal check-in.
- Support QR-based check-in and leave request submission where the workflow requires it.
- Give users visibility into attendance history and team ranking.
- Keep the LUNE card experience reflective and non-deterministic in tone: it offers prompts, not factual claims about a user's future.

## Who uses it

- **Employee:** signs in with Google, checks in, scans an issued QR where applicable, reviews attendance history/ranking, and submits leave requests.
- **Administrator:** has a backend-provided admin role and can maintain office public-IP configuration through an admin flow. Backend authorization remains mandatory.

## Important business behavior

- The backend response is authoritative for employee profile, role, attendance outcome, settings, and leave/QR state.
- A normal check-in requires an in-range location. The configured radius comes from settings, with a client fallback of 2 km.
- Public IP must match configured office IP entries, unless IP verification has no configured value. Exact IP, prefix wildcard, and DDNS entries are supported by the client; a non-admin mismatch is rejected and the user is told to connect to the company network or contact an admin.
- Admins follow a special client path for location and public-IP maintenance; do not generalize that exception to employees.
- Native Wi-Fi metadata is collected and sent, but the current attendance gate does not reject a mismatched SSID/BSSID/subnet using `WifiService.verify()`. Browsers cannot expose SSID/BSSID to this app.
- A user who has already checked in should not create a second attendance record.
- LUNE interpretations are for self-reflection. The currently synced workbook contains one daily message per card, not 7–10 alternative messages.

For the complete user-facing behavior, see [FEATURES.md](FEATURES.md).

## Architecture at a glance

```text
Flutter app
  ├─ CheckinScreen: app state, Google sign-in, check-in orchestration, home UI
  ├─ Services: Apps Script API, GPS, public IP, Wi-Fi, device, QR, leave
  ├─ Widgets: check-in/result sheets, QR, leave, maps, admin controls
  └─ LUNE presentation
       ├─ Web: same-origin iframe/platform view
       └─ Native: WebView loading assets/lune/index.html
            └─ JavaScript bridge sends selected card + reading to Flutter
```

The API is centralized in `lib/services/api_service.dart`. On Web it sends GET requests with query parameters because of the Apps Script cross-origin redirect behavior documented in that client; native uses POST and manually follows redirects. Avoid changing this transport without validating the deployed Apps Script endpoint and both platform targets.

Flutter uses conditional imports for platform-specific Wi-Fi and map behavior. Keep browser-only libraries out of code compiled for native platforms and vice versa.

## Source map and recommended reading order

1. `pubspec.yaml` — Flutter/Dart constraints, dependencies, and bundled assets.
2. `lib/main.dart` — app initialization, API initialization, Google Sign-In, root route.
3. `lib/screens/checkin_screen.dart` — main product state and user journeys; read the sign-in, check-in, QR, leave, and history methods separately.
4. `lib/services/api_service.dart` — backend transport and action payloads.
5. `lib/services/location_service.dart`, `public_ip_service.dart`, and `wifi_service*.dart` — check-in gates and platform differences.
6. `lib/services/qr_checkin_service.dart`, `leave_service.dart`, and `device_service.dart` — supporting workflows.
7. `lib/widgets/checkin_bottom_sheet.dart` — attendance result and Tarot reading UI.
8. `assets/lune/index.html`, `app.js`, `checkin-bridge.js`, and `tarot-sheet-content.js` — embedded LUNE experience and Flutter bridge.
9. `test/` — current automated coverage.

Generated deployment files under `docs/` are not application source. The root of `docs/` is the published Flutter Web build; `docs/v2/` and `docs/v3/` are retained snapshots. Rebuild before replacing the published root, and leave the historical snapshots untouched unless a task explicitly targets them.

## Run and validate locally

Requirements: Flutter SDK compatible with Dart `^3.11.1`, plus the platform toolchain for the target you are testing.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

For a web release matching the published GitHub Pages subpath, build with:

```sh
flutter build web --release --base-href=/wifi-check/
```

On Git Bash for Windows, MSYS path conversion can rewrite slash-prefixed arguments. If that occurs, run the command with `MSYS_NO_PATHCONV=1` in the environment and verify `build/web/index.html` contains `<base href="/wifi-check/" />` before copying output into `docs/`.

A successful unit/widget test run does not validate browser permissions or the full deployed Apps Script integration. For a product change, manually check the relevant platform flow (golden path plus permission/network failure states) as well.

## Configuration and integration boundaries

- Google OAuth client IDs are initialized in `lib/main.dart`; platform-specific OAuth setup also lives in Android, iOS, and web configuration.
- The Apps Script endpoint is currently embedded in `lib/services/api_service.dart`.
- Office coordinates, radius, Wi-Fi values, and public IP settings are returned by the backend; the client includes fallback location values.
- Avoid copying real employee data, access tokens, private spreadsheets, or production secrets into documentation, tests, screenshots, or commits.
- Do not assume a value cached in `SharedPreferences` is current. Settings are refreshed from the server after sign-in and cached for startup/offline display.

## Test coverage today

The existing tests cover a smoke launch, Tarot result-sheet scrolling, public-IP matching/cache behavior, and coordinate-distance calculation. There is not currently broad automated coverage for Google sign-in, live Apps Script requests, GPS permissions, QR camera behavior, native WebView interactions, or all employee/admin paths. Validate those flows manually in an authorized test environment when changing them.

## First-task checklist

- Confirm the requested behavior and the intended target platform(s).
- Trace the existing flow before changing service payloads or state transitions.
- Preserve backend authority and platform-specific behavior.
- Add/update a focused test where behavior can be tested locally.
- Run `dart format`, `flutter analyze`, and `flutter test`.
- If changing UI, launch it and test the actual interaction, including permission/error states.
- If changing web assets, build with the correct base href and verify the deployed `docs/` root without overwriting `docs/v2/` or `docs/v3/`.
