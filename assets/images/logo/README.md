# Flutter Desktop Logo Assets

Orange logo isolated from the provided black-background JPEG. All PNGs are transparent, square, and center-padded; black areas are transparent.

## Contents
- `master/logo_transparent_2048.png`: 2048 × 2048 transparent PNG.
- `master/logo_vector.svg`: scalable traced vector version (the contours are approximated from the supplied JPEG).
- `png/logo_{size}.png`: general application/UI icon sizes.
- `windows/runner/resources/app_icon.ico`: Windows icon containing multiple resolutions.
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/`: Flutter macOS app icon set with `Contents.json`.
- `macos/app_icon.icns`: macOS ICNS when available.
- `linux/icons/`: PNG files for Linux desktop integration.

## Installation
- **Windows**: replace `windows/runner/resources/app_icon.ico` in your Flutter project.
- **macOS**: replace `macos/Runner/Assets.xcassets/AppIcon.appiconset` with the supplied directory.
- **Linux**: choose a suitable PNG (typically 256 or 512 px) and reference/install it through your Linux packaging config or desktop entry.

## Notes
- Color is standardized to `#FF5600` for clean brand consistency.
- The original has a transparent gap/cutout within the symbol. This is preserved.
- Windows/macOS/Linux assets are appropriate for desktop apps; macOS may display its own icon background/shape depending on packaging and OS behavior.
