# Extraction Summary

Date: 2026-05-19

## Outcome

The Filmy iOS AE placeholder decoder has been extracted into a fresh public Swift package, `VAEThumbnailKit`, and Filmy now consumes it via a local path dependency during migration.

App behavior is unchanged at the call-site level:

- `SampleImage.placeholderAEV1` remains the payload source in `FilmyCore`
- Filmy UI call sites in `SampleImageStrip` and `ImageGalleryView` are unchanged
- Filmy now uses a thin `AEPlaceholderService` adapter over `VAEThumbnailKit`

## Files Moved Or Recreated

Logical extraction from Filmy:

- `Filmy/Utilities/AEPlaceholderService.swift` -> `Sources/VAEThumbnailKit/VAEThumbnailGenerator.swift` and companion public API files
- `Filmy/Resources/placeholder_ae_v1.json` -> `Sources/VAEThumbnailKit/Resources/Models/placeholder_ae_v1_gray/metadata.json`
- `Filmy/Resources/PlaceholderModels/placeholder_ae_v1_decoder.mlmodelc/**` -> `Sources/VAEThumbnailKit/Resources/Models/placeholder_ae_v1_gray/decoder.mlmodelc/**`

Rewritten package tests:

- `FilmyTests/AEPlaceholderServiceTests.swift` informed `Tests/VAEThumbnailKitTests/VAEThumbnailGeneratorTests.swift`

Filmy files changed for migration:

- `project.yml`
- `Filmy.xcodeproj/project.pbxproj`
- `Filmy/Utilities/AEPlaceholderService.swift`

Filmy files removed:

- `Filmy/Resources/placeholder_ae_v1.json`
- `Filmy/Resources/PlaceholderModels/placeholder_ae_v1_decoder.mlmodelc/**`

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

Filmy repo text diff after extraction:

- 373 deleted lines
- 34 added lines
- net Filmy reduction: 339 text lines

Main Filmy runtime reduction:

- `AEPlaceholderService.swift`: 250 lines -> 51 lines
- bundled metadata removed from Filmy: 46 text lines
- bundled compiled decoder directory removed from Filmy app resources

New package footprint:

- Swift LOC added under `Sources`, `Tests`, and `Examples`: 820
- shell/support LOC under `Scripts`: 348
- total source/support LOC in the package repo: 1,168

Note: the original private-app reduction is smaller than the initial ~1,000 LOC estimate because most research, training, and service-side placeholder code already lived outside the iOS app before this extraction.

## Tests Moved Or Rewritten

- Package decoder tests were recreated as payload-contract tests in `Tests/VAEThumbnailKitTests/VAEThumbnailGeneratorTests.swift`
- Filmy retained slim adapter coverage in `FilmyTests/AEPlaceholderServiceTests.swift`
- Filmy UI call sites did not need test rewrites because the adapter preserved the synchronous image API

## Runtime And Validation Notes

Measured in this session so far:

- package `swift test`: 6 tests, 0 failures
- package macOS Xcode test path: 6 tests, 0 failures, about 1.66s wall time with coverage after the multi-model registry refactor
- Filmy focused placeholder slice: 2 tests, 0 failures, about 11.41s xcodebuild wall time
- full `make test` in the Filmy workspace: success in 31.73s wall time

Before/after full-suite timing comparison was not captured against a clean pre-extraction baseline in this session, so only the post-extraction runtime is reported here.

## Color Support Status

Status: blocked by missing real color model artifacts.

What exists now:

- the bundled `placeholder_ae_v1_gray` model is grayscale only
- the package now has explicit bundled-model selection via `VAEThumbnailInput.model`
- `VAEThumbnailColorMode` is public
- `.automatic` returns grayscale with the current bundled model
- `.color` throws `VAEThumbnailError.colorModelUnavailable`

Missing artifacts for real color support:

- a 3-channel encoder export analogous to `placeholder_ae_v1_encoder.npz`
- a 3-channel compiled decoder analogous to `placeholder_ae_v1_decoder.mlmodelc`
- matching metadata JSON with latent bounds and output-channel contract

No fake tinting fallback was added.

## Migration Risks

1. The package currently relies on a bundled CoreML resource bundle. Future Filmy or external clients must preserve SwiftPM resource embedding when integrating the library.
2. The model provenance is documented, but the training corpus is not a fully relicensed public dataset. If stricter OSS provenance rules apply, replace the model before the first release tag.
3. The package README currently documents branch-based consumption before the first semver tag. External clients should switch to tagged releases once the first release is cut.
4. Real color output is not yet available. The public API leaves space for it, but shipping color requires a separate model/export effort.

## Planned Release Tag

Planned first public package tag: `1.0.0`

## Suggested Public Repo Description

Small Apple-platform Swift package for decoding versioned VAE thumbnail payloads into placeholder images with a bundled CoreML decoder.