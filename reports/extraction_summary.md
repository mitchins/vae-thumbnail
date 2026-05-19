# Extraction Summary

Date: 2026-05-19

## Outcome

`VAEThumbnailKit` was extracted into a public Swift package, and the host app now consumes it via a local path dependency during migration.

App behavior stayed the same at the thumbnail boundary:

- The host app still uses the same sample payload source.
- The UI call sites still render thumbnails through the same synchronous image API.
- The host app now uses a thin adapter over `VAEThumbnailKit`.

## Package Surface Moved

Core extraction:

- original app adapter code informed `Sources/VAEThumbnailKit/VAEThumbnailGenerator.swift` and companion public API files
- original app metadata informed `Sources/VAEThumbnailKit/Resources/Models/placeholder_ae_v1_gray/metadata.json`
- original app compiled decoder informed `Sources/VAEThumbnailKit/Resources/Models/placeholder_ae_v1_gray/decoder.mlmodelc/**`

Rewritten package tests:

- adapter tests informed `Tests/VAEThumbnailKitTests/VAEThumbnailGeneratorTests.swift`

App-side migration touch points:

- generated project configuration
- original app adapter source
- legacy metadata and compiled decoder resources

## New Package Files

Core package:

- `Package.swift`
- `Sources/VAEThumbnailKit/VAEThumbnailConfiguration.swift`
- `Sources/VAEThumbnailKit/VAEThumbnailBundledModel.swift`
- `Sources/VAEThumbnailKit/VAEThumbnailInput.swift`
- `Sources/VAEThumbnailKit/VAEThumbnailOutput.swift`
- `Sources/VAEThumbnailKit/VAEThumbnailError.swift`
- `Sources/VAEThumbnailKit/VAEThumbnailGenerator.swift`

Resources:

- `Sources/VAEThumbnailKit/Resources/Models/placeholder_ae_v1_gray/metadata.json`
- `Sources/VAEThumbnailKit/Resources/Models/placeholder_ae_v1_gray/decoder.mlmodelc/**`

Verification and support:

- `Tests/VAEThumbnailKitTests/VAEThumbnailGeneratorTests.swift`
- `Examples/BasicThumbnailCLI/BasicThumbnailCLI.swift`
- `Scripts/swiftformat.sh`
- `Scripts/swiftlint.sh`
- `Scripts/test.sh`
- `Scripts/xccov_to_sonar_generic.sh`
- `.github/workflows/build.yml`
- `.swiftlint.yml`
- `sonar-project.properties`
- `README.md`
- `LICENSE`

## LOC Impact

Host app text diff after extraction:

- 373 deleted lines
- 34 added lines
- net host app reduction: 339 text lines

Main runtime reduction:

- adapter file: 250 lines -> 51 lines
- bundled metadata removed from the host app: 46 text lines
- bundled compiled decoder directory removed from the host app resources

New package footprint:

- Swift LOC added under `Sources`, `Tests`, and `Examples`: 820
- shell/support LOC under `Scripts`: 348
- total source/support LOC in the package repo: 1,168

Note: the original reduction is smaller than the initial ~1,000 LOC estimate because most research, training, and service-side placeholder code already lived outside the iOS app before this extraction.

## Tests Moved Or Rewritten

- Package decoder tests were recreated as payload-contract tests in `Tests/VAEThumbnailKitTests/VAEThumbnailGeneratorTests.swift`
- The host app retained slim adapter coverage
- UI call sites did not need rewrites because the adapter preserved the synchronous image API

## Runtime And Validation Notes

Measured in this session so far:

- package `swift test`: 6 tests, 0 failures
- package macOS Xcode test path: 6 tests, 0 failures, about 1.66s wall time with coverage after the multi-model registry refactor
- focused placeholder slice: 2 tests, 0 failures, about 11.41s xcodebuild wall time
- full `make test` in the workspace: success in 31.73s wall time

Before/after full-suite timing comparison was not captured against a clean pre-extraction baseline in this session, so only the post-extraction runtime is reported here.

## Color Support Status

Status: shipped as a mixed v1/v2 package.

What exists now:

- the bundled `placeholder_ae_v1_gray` model is grayscale only and remains for backward compatibility
- the package also bundles `placeholder_ae_v2_rgb`, a real color decoder trained on a public Places365 small balanced subset
- the package has explicit bundled-model selection via `VAEThumbnailInput.model`
- `VAEThumbnailColorMode` is public
- `.automatic` prefers a compatible color model when the payload matches the RGB contract
- `.grayscale` still forces grayscale output, even for the RGB model

No fake tinting fallback was added.

## Migration Risks

1. The package currently relies on a bundled CoreML resource bundle. Future external clients must preserve SwiftPM resource embedding when integrating the library.
2. The model provenance is documented, but the training corpus is not a fully relicensed public dataset. If stricter OSS provenance rules apply, replace the model before the first release tag.
3. The package now has a first public tag and a remote dependency path. Keep the Git URL and tag in sync when cutting later releases.
4. The public RGB path is now available, but the legacy grayscale v1 payload contract still exists for compatibility.

## Planned Release Tag

First public package tag: `1.0.0`

## Suggested Public Repo Description

Small Apple-platform Swift package for decoding versioned VAE thumbnail payloads into placeholder images with a bundled CoreML decoder.