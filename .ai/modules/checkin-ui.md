# Check-in UI

## Facts
- `CheckinBottomSheet` in `lib/widgets/checkin_bottom_sheet.dart` owns check-in result/loading/error presentation and the selected Tarot reading.
- The widget calls `map_impl.buildMapWidget`; the map implementation is selected by a conditional import.
- Other user-flow sheets: `QrIssuerSheet`, `LeaveRequestSheet`, and `AdminIpSheet` in their respective files under `lib/widgets/`.
- `CheckinScreen` creates these sheets and supplies callbacks/data; it owns workflow orchestration.

## Dependencies
- `checkin_bottom_sheet.dart`: `shimmer`, gesture events, conditional map implementation.
- Leave sheet -> `LeaveService`; QR issuer sheet -> `QrCheckinService`; admin IP sheet -> `ApiService` and `PublicIpService`.

## Change routing
For layout/scroll/touch behavior, inspect both the sheet and the caller in `checkin_screen.dart`. Keep service validation out of presentation widgets unless a current public interface requires otherwise.

## Validation
`flutter test` includes a Tarot result popup scrolling test. Run it after changes; for visual behavior, also inspect the actual mobile/desktop sheet.
