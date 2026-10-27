# LUNE Tarot and result sheet

## Facts
- Web source is under `assets/lune/`; entry HTML loads `motion.js`, `tarot-data.js`, `tarot-sheet-content.js`, `app.js`, `checkin-bridge.js`, and styling files.
- `tarot-data.js` defines the deck. `tarot-sheet-content.js` overlays editorial meanings and daily fields by card ID. The workbook `assets/lune/LUNE — Ý nghĩa 78 lá Tarot.xlsx` is the supplied content source.
- Workbook verified to contain 78 cards and one `dailyMessage` field per card. It does not contain 7–10 message variants per card.
- `checkin-bridge.js` sends selected card data to Flutter. Native receives via JavaScript channel; web receives same-origin `postMessage`.
- `CheckinBottomSheet` presents card image, check-in state, keywords, daily message, caution, small action, detailed perspectives, and reflection question.

## Interfaces
- Flutter widget: `LuneTarotCheckin` via conditional export in `lib/widgets/lune_tarot_checkin.dart`.
- Selection payload is a map containing card fields (`id`, names, keywords, overview, love, work, shadow, action, question, dailyMessage, caution, smallAction, etc.) and topic/artwork metadata.
- Bottom sheet receives `tarotCard` and an async check-in callback.

## Change routing
For content changes inspect workbook, `tarot-sheet-content.js`, card ID merge in `app.js`, and bridge payload. For visual/gesture changes inspect `app.js`, `motion.js`, CSS layers, and Flutter `checkin_bottom_sheet.dart` separately.

## Validation
`flutter test` covers a Tarot result-sheet scroll test, but not the complete LUNE gesture/animation in a browser or native WebView. Manually verify draw, reveal, card tilt, scroll, error/success result, and narrow viewport after UI changes.
