# Product features and behavior

## Product purpose

UXTeam is a Flutter attendance/check-in app for employees. It records daily attendance and gives employees supporting flows for QR check-in, attendance history/ranking, leave requests, and a LUNE Tarot reflection attached to the check-in experience.

The app is a client for a Google Apps Script API. The backend is authoritative for identity, attendance records, settings, leave requests, QR sessions, history, and ranking.

## Main user journey

1. The user opens the home screen. The app restores a cached Google account and settings if available; otherwise, sign-in is user-initiated.
2. The user signs in with Google. The app sends the email, display name, avatar, and device metadata to the backend, then caches the returned employee and settings locally.
3. The app checks location and public IP, displays readiness/status, and refreshes history/ranking in the background after authentication.
4. The user starts a check-in. The LUNE Tarot flow presents the deck and lets the user draw a card; the result sheet begins the actual check-in.
5. The app verifies the configured office location radius and public IP, submits the attendance request, then shows the check-in status, time, and map together with the selected card reading.

A previously checked-in user can still see the selected card/result flow without creating a duplicate attendance record.

## Attendance rules

- Location is compared with `office_lat`, `office_lng`, and `office_radius` from backend settings. Defaults in the client are the UXTeam office coordinates and a 2,000 m radius.
- The current check-in gate requires an in-range location for non-admin accounts.
- Public IP is compared with `office_public_ip`. Supported formats include comma/line-separated exact IPs, prefix wildcards such as `113.185.*`, and DDNS hostnames resolved through Google DNS-over-HTTPS.
- An empty office IP setting causes IP verification to be skipped. When an IP list is configured, a non-admin whose public IP does not match is blocked and told to connect to the company network or contact an admin. Admin accounts have a special path: they are not blocked by the location gate, and a nonmatching public IP can be registered through the backend's office-IP update action.
- Native Wi-Fi metadata is collected where platform permissions/plugins allow it and sent with attendance data. The current check-in gate does not call `WifiService.verify()` to reject mismatched SSID/BSSID/subnet values. Browsers cannot read Wi-Fi hardware details; the web flow uses GPS and public IP rather than SSID/BSSID verification.
- The client recognizes an already-recorded attendance response and reports the existing check-in time instead of treating it as a second attendance.

## QR attendance

The QR scanner requests camera access on native platforms; browsers handle camera permission themselves. A scanned payload is parsed for a check-in token, then submitted with employee, device, location, and public-IP information. QR check-in requires an in-range location. A separate issuer flow creates a QR session for an authorized user; token validation and session rules belong to the backend.

## Leave requests

Employees can submit leave type, date range, and reason. Their requests are retrieved from the backend. The app displays a submission/result flow; approval policy and final request status are backend-owned.

## History and ranking

The app fetches personal attendance history and team ranking after login, caches successful results locally, and can restore the cache while fresh data is loading. A manual refresh path is also available in the home screen.

## Administration

Admin-specific UI and API flows support office IP maintenance. Admin authorization is determined from the employee role returned by the backend. The client should not be treated as the security boundary; the backend must authorize administrative actions independently.

## LUNE Tarot

LUNE is an embedded web experience shared by Flutter Web and native WebView. The deck supports shuffling, drawing, a three-topic intention selector (self, love, work), a card journal, catalog/search, and an interpretation view. Card selection is sent to Flutter through a same-origin `postMessage` on web and a JavaScript channel in native WebView.

The check-in result sheet presents the selected card and the reading in this order:

1. English and Vietnamese card names, with three keywords.
2. Today's message.
3. A gentle point to notice.
4. One small action for today.
5. Detailed self, work, relationship, and limitation perspectives, plus a reflection question.

Card meanings are sourced from `assets/lune/LUNE — Ý nghĩa 78 lá Tarot.xlsx` and synchronized into `assets/lune/tarot-sheet-content.js`. The workbook currently has one daily-message value per card; it does not yet supply the requested 7–10 random alternatives. Do not present generated/duplicated text as spreadsheet-authored variants.

The revealed card has a tap-to-flip interaction, a restrained champagne/lavender/mint/rose foil sheen, and pointer/touch tilt. The check-in sheet owns reading content and scrolling; dragging on the card should control card tilt rather than scroll the reading.

Tarot is an optional reflection prompt, not a prediction, diagnostic, or substitute for personal judgment.

## Platform differences

| Capability | Android/iOS | Web |
|---|---|---|
| LUNE runtime | Flutter WebView | Same-origin iframe/platform view |
| Wi-Fi hardware metadata | Platform plugin, subject to OS permissions | Not available to browser code |
| Camera | Native permission flow | Browser permission flow |
| Location | Geolocator and OS permission | Browser geolocation permission; secure context required |
| Google sign-in | Native Google Sign-In | Google Sign-In web flow/dialog |

## Local persistence and privacy notes

The client stores the signed-in employee, settings, history, ranking, and device identifier in local preferences. The LUNE journal is stored in browser local storage within the LUNE web runtime. These are device-local caches, not shared server records. Attendance and leave data are sent to the configured Apps Script backend.

## Key implementation locations

- App initialization and Google Sign-In setup: `lib/main.dart`
- Main home, authentication, attendance orchestration, QR/leave/history UI: `lib/screens/checkin_screen.dart`
- Backend HTTP client and API actions: `lib/services/api_service.dart`
- GPS and office-radius validation: `lib/services/location_service.dart`
- Public IP/DDNS validation: `lib/services/public_ip_service.dart`
- Platform Wi-Fi implementations: `lib/services/wifi_service.dart`, `lib/services/wifi_service_native.dart`, `lib/services/wifi_service_web.dart`
- QR service and scanner: `lib/services/qr_checkin_service.dart`, `lib/screens/qr_scanner_screen.dart`
- Leave API wrapper: `lib/services/leave_service.dart`
- Check-in result and Tarot sheet: `lib/widgets/checkin_bottom_sheet.dart`
- LUNE web app and card content: `assets/lune/`
- Published Flutter Web output: `docs/` (root deployment); historical web snapshots: `docs/v2/`, `docs/v3/`
