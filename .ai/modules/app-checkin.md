# App and check-in orchestration

## Facts
- `lib/main.dart` initializes `ApiService`, initializes Google Sign-In, and routes to `CheckinScreen`.
- `lib/screens/checkin_screen.dart` owns cached user/settings state, sign-in, readiness probes, check-in, QR/leave/history/ranking/admin sheet navigation.
- Normal attendance gates: in-range location and configured public-IP match. Admin has explicit exceptions/update path in the screen flow.
- `WifiService.getInfo()` is called for metadata; `WifiService.verify()` is not called in the current check-in path.

## Dependencies
- `ApiService`, `LocationService`, `PublicIpService`, `WifiService`, `DeviceService`, `QrCheckinService`.
- UI sheets in `lib/widgets/` and QR scanner in `lib/screens/qr_scanner_screen.dart`.

## Interfaces
- Public screen: `CheckinScreen`.
- Main API and orchestration are private methods on `_CheckinScreenState`; there is no stable exported controller interface.

## Change routing
Read this module for sign-in, check-in, admin/employee differences, or navigation. Then inspect the specific service and sheet involved; treat backend responses as authoritative.

## Validation
`flutter test`, `flutter analyze`; manually validate web/native permissions and backend-dependent paths in an authorized test environment.
