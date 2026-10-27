# Platform adapters

## Facts
- `lib/services/wifi_service.dart` conditionally selects native or web Wi-Fi implementation.
- `lib/widgets/checkin_bottom_sheet.dart` conditionally selects native WebView map or web HTML map implementation.
- `lib/services/web_sign_in.dart` selects a stub or `google_sign_in_web` export using `dart.library.js_util`.
- `lib/widgets/lune_tarot_checkin.dart` selects native WebView or web iframe/platform-view implementation using `dart.library.html`.
- Native Wi-Fi reads SSID/BSSID/IP with location permission; web returns a browser marker because browser APIs do not expose Wi-Fi hardware metadata.
- Native map uses `webview_flutter`; web map registers an HTML platform view.

## Public adapter interfaces verified
- `WifiService.getInfo()` and `WifiService.verify(...)`; platform implementations export `getWifiInfo()`.
- `buildMapWidget(double lat, double lng)` in native/web map files.
- `renderButton()` from web sign-in conditional export.
- `LuneTarotCheckin(onCardSelected, checkinStatus, interactionEnabled)` in both implementations.

## Change routing
When changing a cross-platform capability, inspect both branches and the conditional import site. Avoid importing `dart:html` or WebView-only dependencies into shared code.

## Validation
Run analyzer/tests and exercise both the target native platform and browser permission behavior when possible.
