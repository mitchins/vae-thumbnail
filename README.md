# VAEThumbnailKit

VAEThumbnailKit is a small Apple-platform Swift package for decoding compact,
base64-packed VAE thumbnail payloads into placeholder images.

The package includes two bundled Core ML decoders:

- `placeholder_ae_v1_gray`: the original grayscale decoder for legacy payloads.
- `placeholder_ae_v2_rgb`: an RGB decoder trained from a public Places365 small subset.

Callers provide a payload string and, optionally, a bundled model hint. The
package returns a Core Graphics image plus convenience wrappers for UIKit and
AppKit where available.

## Features

- Bundled grayscale and RGB Core ML decoders
- Versioned model metadata and explicit model selection
- Automatic model selection for compatible payloads
- Small Swift API with input, configuration, output, and error types
- SwiftPM resource loading with no app-specific bundle assumptions
- Payload-only tests; no training images are shipped

## Requirements

- Xcode 16 or later
- Swift 5.10
- iOS 17+
- macOS 14+

## Installation

During local development, use a local path dependency:

```swift
dependencies: [
  .package(path: "../vae-thumbnail")
]
```

If you need an unreleased snapshot, pin a revision explicitly instead of tracking a branch:

```swift
dependencies: [
  .package(url: "https://github.com/mitchins/vae-thumbnail.git", revision: "<commit-sha>")
]
```

After the first semver release is tagged, prefer the normal version-based form:

```swift
dependencies: [
  .package(url: "https://github.com/mitchins/vae-thumbnail.git", from: "1.0.0")
]
```

Then add the product to your target:

```swift
.product(name: "VAEThumbnailKit", package: "vae-thumbnail")
```

## Usage

```swift
import VAEThumbnailKit

let generator = try VAEThumbnailGenerator()
let input = VAEThumbnailInput(
  latentPayload: "iHF9oYBndICMcZqMeXeZjwD/",
  model: .grayscaleV1
)
let output = try generator.generateThumbnailSynchronously(from: input)

#if canImport(UIKit)
let image = output.uiImage
#endif
```

Resize or force output behavior through `VAEThumbnailConfiguration`:

```swift
let configuration = VAEThumbnailConfiguration(
    outputSize: CGSize(width: 48, height: 48),
    colorMode: .automatic,
    quality: .best
)

let output = try generator.generateThumbnailSynchronously(
    from: input,
    configuration: configuration
)
```

RGB v2 payloads can use automatic model selection:

```swift
let rgbInput = VAEThumbnailInput(latentPayload: "j5OydX+gm5Z2jHKJjYxpd5jCiLmSkFNq")
let rgbOutput = try generator.generateThumbnailSynchronously(from: rgbInput)
```

## Preview

The samples below compare public Places365 source images with the bundled RGB
reconstruction and grayscale rendering paths.

| Original | Color | BW |
| --- | --- | --- |
| <img src="README-assets/preview-1-original.png" alt="Public Places365 original sample 1" width="84" /> | <img src="README-assets/preview-1-color.png" alt="Public Places365 color reconstruction sample 1" width="84" /> | <img src="README-assets/preview-1-bw.png" alt="Public Places365 grayscale reconstruction sample 1" width="84" /> |
| <img src="README-assets/preview-2-original.png" alt="Public Places365 original sample 2" width="84" /> | <img src="README-assets/preview-2-color.png" alt="Public Places365 color reconstruction sample 2" width="84" /> | <img src="README-assets/preview-2-bw.png" alt="Public Places365 grayscale reconstruction sample 2" width="84" /> |
| <img src="README-assets/preview-3-original.png" alt="Public Places365 original sample 3" width="84" /> | <img src="README-assets/preview-3-color.png" alt="Public Places365 color reconstruction sample 3" width="84" /> | <img src="README-assets/preview-3-bw.png" alt="Public Places365 grayscale reconstruction sample 3" width="84" /> |

## Color Support

Color behavior depends on the payload and selected bundled model.

- `placeholder_ae_v1_gray` is grayscale only.
- `placeholder_ae_v2_rgb` is a real three-channel decoder.
- `.automatic` selects a compatible bundled model and prefers RGB for RGB v2 payloads.
- `.grayscale` forces grayscale rendering, including when the underlying bundled model is color-capable.
- `.color` returns true color only when the payload bytes match a bundled RGB-capable model.
- `VAEThumbnailInput.model` can pin a specific bundled model such as `.grayscaleV1` or `.rgbV2` when the caller knows the payload version explicitly.

No fake tinting fallback is applied.

## Example CLI

The package includes a minimal executable example target:

```bash
swift run BasicThumbnailCLI \
  --payload iHF9oYBndICMcZqMeXeZjwD/ \
  --output /tmp/vae-thumbnail.png \
  --width 64 \
  --height 64
```

## Model Provenance

The bundled decoders and metadata are generated artifacts with separate
provenance notes.

- `placeholder_ae_v1_gray` is the legacy grayscale model retained for
  backward-compatible payloads.
- `placeholder_ae_v2_rgb` was trained on a public Places365 small validation
  subset capped to 32 images per class, then exported to Core ML.
- The shipped files live under `Sources/VAEThumbnailKit/Resources/Models/`.
- The training corpora themselves are not included in this repository.
- No private app credentials, analytics IDs, signing assets, or user images are
  included here.
- `placeholder_ae_v2_rgb` uses only public Places365 inputs and does not bundle
  any source images.

## Dataset Recipe

The RGB v2 model uses this dataset recipe:

- source: Places365 `val` split with `small=True` (256px source images)
- balancing: cap to 32 images per class for 365 classes
- preprocessing: RGB conversion, square pad, resize to 16x16
- payload contract: 24 latent bytes, base64-encoded to 32 characters

Dataset preparation and export scripts live under `research/placeholders/src/`.

## Limitations

- Legacy grayscale payloads still use the `placeholder_ae_v1` contract.
- Both bundled models currently reconstruct 16x16 square previews before client-side scaling.
- Public consumers should choose a payload/version contract explicitly when compatibility matters.

## Development

```bash
make test
make lint
make sonar-coverage
```

The CI workflow runs SwiftFormat, SwiftLint, macOS package tests with coverage,
and SonarCloud analysis.

See [reports/extraction_summary.md](reports/extraction_summary.md) for the
extraction notes and measured impact.