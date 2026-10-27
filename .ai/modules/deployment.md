# Deployment and publish tree

## Facts
- Flutter source and platform config are at repository root (`lib`, `web`, `android`, `ios`, manifests).
- `flutter build web --release --base-href /wifi-check/` generates `build/web`.
- `docs/` is the currently tracked publish tree. Its root holds the active deployment output; `docs/v2` and `docs/v3` are retained historical web snapshots.
- The workbook and `Cover.webp` are currently tracked under both source assets and the copied publish assets.

## Dependencies
- `web/index.html` provides the local/bootstrap shell; `docs/index.html` corresponds to the deployed shell.
- Web-rendered LUNE assets under `assets/lune` are packaged into `docs/assets/assets/lune`.

## Public invariants
- Publish deployments must use `/wifi-check/` base href.
- Preserve historical snapshot directories unless explicitly asked to replace them.
- Verify referenced cover, Tarot thumbs, fonts, bootstrap, and main Dart bundle exist after copy.

## Change routing
Inspect release/build output and file lists before calling output “deployed”; generated output should not be treated as an edited application feature.

## Unverified boundary
This repository does not include Pages/CI deploy configuration besides the published files. Publishing behavior outside this repository is not verified.
