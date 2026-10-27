# Services and integration contracts

## Facts
- `ApiService` in `lib/services/api_service.dart` centralizes Apps Script transport and named actions (`login`, `checkin`, `getSettings`, `updateOfficeIp`, plus service-specific actions).
- Web transport uses GET query parameters; native sends POST and manually follows redirects. This is an integration constraint documented in the source.
- `LocationService` reads office coordinates/radius from settings with client defaults and calculates range.
- `PublicIpService` fetches/caches public IP, matches exact/prefix entries, and can resolve DDNS via Google DoH.
- `QrCheckinService` handles session creation, token extraction, and `checkinByQr`; `LeaveService` handles leave request create/list.
- `DeviceService` persists a device ID using `SharedPreferences`.

## Dependencies
- HTTP: `http`; location: `geolocator`; local state: `shared_preferences`; Wi-Fi: `network_info_plus`, `permission_handler`.
- Services are called by `CheckinScreen`, `AdminIpSheet`, QR and leave widgets.

## Public interfaces verified
- `ApiService.request`, `loginAndSync`, `checkin`, `getSettings`, `updateOfficeIp`.
- `LocationService.ensurePermission`, `getCurrentPosition`, `distanceTo`, `getInfo`.
- `PublicIpService.resolveDdns`, `getPublicIp`, `verify`.
- `QrCheckinService.createSession`, `checkinByQr`, `extractToken`.
- `LeaveService.createRequest`, `getMine`; `DeviceService.getInfo`.

## Unverified boundary
Apps Script implementation/server-side auth and database rules are not in this repository. Verify backend contract with its owner before changing action payloads or interpreting response semantics.
