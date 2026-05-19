# VAEThumbnailKit

VAEThumbnailKit is a small Apple-platform Swift package for decoding versioned,
base64-packed VAE thumbnail payloads into displayable placeholder images.

The package currently ships one bundled decoder, `placeholder_ae_v1`, under the
bundled model identifier `placeholder_ae_v1_gray`. The public surface is still
small: pass a payload string in, optionally provide a bundled-model hint, and
get a Core Graphics image out.

## Features

- Bundled CoreML decoder and metadata for `placeholder_ae_v1_gray`
- Small Swift API with explicit input, configuration, output, and error types
- Explicit bundled-model hints plus automatic model selection
- Grayscale-first default behavior with an explicit future-facing color API
- No Filmy app types, view models, or bundle assumptions in the package
- Payload-only tests; no private or third-party source images are shipped

## Requirements

- Xcode 16 or later
- Swift 5.10
- iOS 17+
- macOS 14+

## Installation

During Filmy migration, use a local path dependency:

```swift
dependencies: [
  .package(path: "../vae-thumbnail")
]
```

For external consumption before the first tag exists, pin the main branch:

```swift
dependencies: [
  .package(url: "https://github.com/mitchins/vae-thumbnail.git", branch: "main")
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

You can also request a resized output image:

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

## Color Support

The bundled `placeholder_ae_v1` model is grayscale only.

- `.automatic` returns grayscale output with the current bundled model.
- `.grayscale` forces grayscale output, including future color-capable models.
- `.color` throws `VAEThumbnailError.colorModelUnavailable` until a real
  three-channel decoder, matching encoder, and matching export metadata are
  bundled.
- `VAEThumbnailInput.model` can pin a specific bundled model such as
  `.grayscaleV1` when the caller knows the payload version explicitly.

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

The bundled decoder and metadata are author-generated artifacts derived from the
Filmy placeholder research pipeline.

- The shipped files currently live under
  `Sources/VAEThumbnailKit/Resources/Models/placeholder_ae_v1_gray/`.
- The training corpus itself is not included in this repository.
- No private app credentials, analytics IDs, signing assets, or user images are
  included here.
- The training inputs were low-resolution Flickr thumbnail derivatives gathered
  in the private Filmy workspace; see [reports/public_safety_audit.md](reports/public_safety_audit.md)
  for the release audit and residual-risk note.

## Development

```bash
make test
make lint
make sonar-coverage
```

The CI workflow runs SwiftFormat, SwiftLint, macOS package tests with coverage,
and SonarCloud analysis. The first public package tag is intended to be
`1.0.0`.

See [reports/extraction_summary.md](reports/extraction_summary.md) for the
Filmy migration notes and measured impact.