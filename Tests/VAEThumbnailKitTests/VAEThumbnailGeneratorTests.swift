import CoreGraphics
import Foundation
#if canImport(AppKit)
    import AppKit
#endif
@testable import VAEThumbnailKit
import XCTest

private struct ResizeThumbnailTestCase {
    let input: VAEThumbnailInput
    let configuration: VAEThumbnailConfiguration
    let expectedPixelSize: CGSize
    let expectedColorMode: VAEThumbnailRenderedColorMode
}

private struct TemporaryModelFixture {
    let model: VAEThumbnailBundledModel
    let metadataJSON: String?
    let includeDecoder: Bool
}

private struct SelectionThumbnailTestCase {
    let fixtures: [TemporaryModelFixture]
    let input: VAEThumbnailInput
    let configuration: VAEThumbnailConfiguration
    let expectedError: VAEThumbnailError
}

final class VAEThumbnailGeneratorTests: XCTestCase {
    private let validPayload = "iHF9oYBndICMcZqMeXeZjwD/"
    private let validRGBPayload = "j5OydX+gm5Z2jHKJjYxpd5jCiLmSkFNq"

    func testValidV1PayloadDecodesBundledModel() async throws {
        let generator = try VAEThumbnailGenerator()

        let output = try await generator.generateThumbnail(from: .init(latentPayload: validPayload))

        XCTAssertEqual(output.pixelSize, CGSize(width: 16, height: 16))
        XCTAssertEqual(output.renderedColorMode, .grayscale)
        XCTAssertEqual(output.model, .grayscaleV1)
        XCTAssertEqual(output.modelName, "placeholder_ae_v1")
    }

    func testAutomaticModeSelectsBundledRGBModelForRGBPayload() async throws {
        let generator = try VAEThumbnailGenerator()

        let output = try await generator.generateThumbnail(from: .init(latentPayload: validRGBPayload))

        XCTAssertEqual(output.pixelSize, CGSize(width: 16, height: 16))
        XCTAssertEqual(output.renderedColorMode, .color)
        XCTAssertEqual(output.model, .rgbV2)
        XCTAssertEqual(output.modelName, "placeholder_ae_v2_rgb")
    }

    func testExplicitBundledModelHintUsesV1() async throws {
        let generator = try VAEThumbnailGenerator()

        let output = try await generator.generateThumbnail(
            from: .init(latentPayload: validPayload, model: .grayscaleV1)
        )

        XCTAssertEqual(output.modelIdentifier, VAEThumbnailBundledModel.grayscaleV1.identifier)
        XCTAssertEqual(output.renderedColorMode, .grayscale)
    }

    func testExplicitBundledModelHintUsesV2ColorOutput() async throws {
        let generator = try VAEThumbnailGenerator()
        let configuration = VAEThumbnailConfiguration(colorMode: .color)

        let output = try await generator.generateThumbnail(
            from: .init(latentPayload: validRGBPayload, model: .rgbV2),
            configuration: configuration
        )

        XCTAssertEqual(output.modelIdentifier, VAEThumbnailBundledModel.rgbV2.identifier)
        XCTAssertEqual(output.renderedColorMode, .color)
    }

    func testInvalidPayloadThrowsBase64Error() async throws {
        let generator = try VAEThumbnailGenerator()

        do {
            _ = try await generator.generateThumbnail(from: .init(latentPayload: "not-base64"))
            XCTFail("Expected invalid base64 payload to throw.")
        } catch let error as VAEThumbnailError {
            XCTAssertEqual(error, .invalidPayloadBase64)
        }
    }

    func testColorRequestForV1PayloadThrowsNoCompatibleColorModelForThatPayload() async throws {
        let generator = try VAEThumbnailGenerator()
        let configuration = VAEThumbnailConfiguration(colorMode: .color)

        do {
            _ = try await generator.generateThumbnail(
                from: .init(latentPayload: validPayload),
                configuration: configuration
            )
            XCTFail("Expected the v1 payload to reject a color request without a compatible rgb payload shape.")
        } catch let error as VAEThumbnailError {
            XCTAssertEqual(
                error,
                .noCompatibleModelForPayload(actualBytes: 18, requestedColorMode: .color, requestedModel: nil)
            )
        }
    }

    func testGrayscaleModeConvertsRGBModelOutputToGrayscale() async throws {
        let generator = try VAEThumbnailGenerator()
        let configuration = VAEThumbnailConfiguration(colorMode: .grayscale)

        let output = try await generator.generateThumbnail(
            from: .init(latentPayload: validRGBPayload),
            configuration: configuration
        )

        XCTAssertEqual(output.model, .rgbV2)
        XCTAssertEqual(output.renderedColorMode, .grayscale)
    }

    func testRequestedOutputSizeResizesDecodedImageAcrossQualities() async throws {
        let generator = try VAEThumbnailGenerator()

        let cases: [ResizeThumbnailTestCase] = [
            .init(
                input: .init(latentPayload: validPayload),
                configuration: VAEThumbnailConfiguration(
                    outputSize: CGSize(width: 32, height: 24),
                    colorMode: .automatic,
                    quality: .balanced
                ),
                expectedPixelSize: CGSize(width: 32, height: 24),
                expectedColorMode: .grayscale
            ),
            .init(
                input: .init(latentPayload: validRGBPayload),
                configuration: VAEThumbnailConfiguration(
                    outputSize: CGSize(width: 20, height: 18),
                    colorMode: .color,
                    quality: .fast
                ),
                expectedPixelSize: CGSize(width: 20, height: 18),
                expectedColorMode: .color
            ),
            .init(
                input: .init(latentPayload: validPayload),
                configuration: VAEThumbnailConfiguration(
                    outputSize: CGSize(width: 24, height: 24),
                    colorMode: .automatic,
                    quality: .best
                ),
                expectedPixelSize: CGSize(width: 24, height: 24),
                expectedColorMode: .grayscale
            )
        ]

        for item in cases {
            let output = try await generator.generateThumbnail(from: item.input, configuration: item.configuration)
            XCTAssertEqual(output.pixelSize, item.expectedPixelSize)
            XCTAssertEqual(output.renderedColorMode, item.expectedColorMode)
        }
    }

    #if canImport(AppKit)
        func testOutputNSImageMatchesPixelSize() async throws {
            let generator = try VAEThumbnailGenerator()
            let output = try await generator.generateThumbnail(from: .init(latentPayload: validPayload))

            XCTAssertEqual(output.nsImage.size, output.pixelSize)
        }
    #endif

    func testInvalidBundledMetadataThrowsInvalidMetadata() throws {
        let (bundle, bundleURL) = try makeInvalidMetadataBundle()
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        XCTAssertThrowsError(try VAEThumbnailGenerator(bundle: bundle)) { error in
            XCTAssertEqual(error as? VAEThumbnailError, .invalidMetadata)
        }
    }

    func testGeneratorInitializationRejectsEmptyBundleResources() throws {
        let (bundle, bundleURL) = try makeTemporaryBundle(models: [])
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        XCTAssertThrowsError(try VAEThumbnailGenerator(bundle: bundle)) { error in
            XCTAssertEqual(error as? VAEThumbnailError, .noBundledModelsAvailable)
        }
    }

    func testGenerateThumbnailRejectsZeroSizedOutputRequest() async throws {
        let generator = try VAEThumbnailGenerator()

        do {
            _ = try await generator.generateThumbnail(
                from: .init(latentPayload: validPayload),
                configuration: VAEThumbnailConfiguration(outputSize: CGSize(width: 0, height: 16))
            )
            XCTFail("Expected zero-sized output to throw.")
        } catch let error as VAEThumbnailError {
            XCTAssertEqual(error, .invalidOutputSize(CGSize(width: 0, height: 16)))
        } catch {
            XCTFail("Expected VAEThumbnailError, got \(error).")
        }
    }

    func testGeneratorInitializationRejectsMalformedBundles() throws {
        let validMetadata = try makeMetadataJSON()
        let invalidQuantizeMetadata = try makeMetadataJSON(quantizeBits: 7)
        let invalidLatentRangeMetadata = try makeMetadataJSON(latentMax: Array(repeating: 0.0, count: 18))

        let cases: [(
            fixtures: [TemporaryModelFixture],
            expectedError: VAEThumbnailError
        )] = [
            (
                [],
                .noBundledModelsAvailable
            ),
            (
                [
                    .init(model: .grayscaleV1, metadataJSON: nil, includeDecoder: true)
                ],
                .metadataNotFound(model: .grayscaleV1)
            ),
            (
                [
                    .init(model: .grayscaleV1, metadataJSON: validMetadata, includeDecoder: false)
                ],
                .modelNotFound(model: .grayscaleV1)
            ),
            (
                [
                    .init(model: .grayscaleV1, metadataJSON: invalidQuantizeMetadata, includeDecoder: true)
                ],
                .invalidMetadata
            ),
            (
                [
                    .init(model: .grayscaleV1, metadataJSON: invalidLatentRangeMetadata, includeDecoder: true)
                ],
                .invalidMetadata
            )
        ]

        for item in cases {
            let (bundle, bundleURL) = try makeTemporaryBundle(models: item.fixtures)
            defer {
                try? FileManager.default.removeItem(at: bundleURL)
            }

            XCTAssertThrowsError(try VAEThumbnailGenerator(bundle: bundle)) { error in
                XCTAssertEqual(error as? VAEThumbnailError, item.expectedError)
            }
        }
    }

    func testGenerateThumbnailRejectsInvalidSelectionAndOutputMetadata() async throws {
        let validMetadata = try makeMetadataJSON()
        let zeroOutputSizeMetadata = try makeMetadataJSON(outputSize: 0)
        let mismatchedOutputSizeMetadata = try makeMetadataJSON(outputSize: 15)

        let baseFixtures: [TemporaryModelFixture] = [
            .init(model: .grayscaleV1, metadataJSON: validMetadata, includeDecoder: true)
        ]

        let cases: [SelectionThumbnailTestCase] = [
            .init(
                fixtures: baseFixtures,
                input: .init(latentPayload: validPayload, model: .rgbV2),
                configuration: .default,
                expectedError: .requestedModelUnavailable(.rgbV2)
            ),
            .init(
                fixtures: baseFixtures,
                input: .init(latentPayload: "AA==", model: .grayscaleV1),
                configuration: .default,
                expectedError: .invalidPayloadLength(expectedBytes: 18, actualBytes: 1)
            ),
            .init(
                fixtures: baseFixtures,
                input: .init(latentPayload: validPayload, model: .grayscaleV1),
                configuration: VAEThumbnailConfiguration(colorMode: .color),
                expectedError: .colorModelUnavailable
            ),
            .init(
                fixtures: [
                    .init(model: .grayscaleV1, metadataJSON: zeroOutputSizeMetadata, includeDecoder: true)
                ],
                input: .init(latentPayload: validPayload),
                configuration: .default,
                expectedError: .invalidMetadata
            ),
            .init(
                fixtures: [
                    .init(model: .grayscaleV1, metadataJSON: mismatchedOutputSizeMetadata, includeDecoder: true)
                ],
                input: .init(latentPayload: validPayload),
                configuration: .default,
                expectedError: .unexpectedOutputShape(elementCount: 256, expectedPixels: 225)
            )
        ]

        for item in cases {
            let (bundle, bundleURL) = try makeTemporaryBundle(models: item.fixtures)
            defer {
                try? FileManager.default.removeItem(at: bundleURL)
            }

            let generator = try VAEThumbnailGenerator(bundle: bundle)

            do {
                _ = try await generator.generateThumbnail(from: item.input, configuration: item.configuration)
                XCTFail("Expected generation to throw \(item.expectedError).")
            } catch let error as VAEThumbnailError {
                XCTAssertEqual(error, item.expectedError)
            } catch {
                XCTFail("Expected VAEThumbnailError, got \(error).")
            }
        }
    }

    func testErrorDescriptionsStayStableForAllCases() {
        let cases: [(error: VAEThumbnailError, description: String)] = [
            (
                .noBundledModelsAvailable,
                "No bundled VAE thumbnail models are available in the package resources."
            ),
            (
                .metadataNotFound(model: .grayscaleV1),
                "The metadata.json file for bundled model placeholder_ae_v1_gray is missing from the package resources."
            ),
            (
                .modelNotFound(model: .rgbV2),
                "The decoder.mlmodelc bundle for bundled model placeholder_ae_v2_rgb is missing from the package resources."
            ),
            (
                .invalidMetadata,
                "The bundled VAE thumbnail metadata is invalid."
            ),
            (
                .invalidPayloadBase64,
                "The supplied thumbnail payload is not valid base64."
            ),
            (
                .invalidPayloadLength(expectedBytes: 18, actualBytes: 24),
                "The supplied thumbnail payload decoded to 24 bytes instead of 18."
            ),
            (
                .invalidOutputSize(CGSize(width: 0, height: 0)),
                "The requested thumbnail output size 0.0x0.0 is invalid."
            ),
            (
                .unexpectedModelInterface,
                "The bundled CoreML decoder does not expose a usable input/output pair."
            ),
            (
                .unexpectedOutputShape(elementCount: 12, expectedPixels: 16),
                "The decoder output shape is unsupported. Got 12 values for 16 expected pixels."
            ),
            (
                .requestedModelUnavailable(.rgbV2),
                "The requested bundled model placeholder_ae_v2_rgb is not available in this package build."
            ),
            (
                .noCompatibleModelForPayload(
                    actualBytes: 18,
                    requestedColorMode: .color,
                    requestedModel: nil
                ),
                "No bundled model can decode a 18-byte payload for color mode using automatic bundled selection."
            ),
            (
                .unsupportedOutputType,
                "The decoder returned an unsupported output type."
            ),
            (
                .colorModelUnavailable,
                "A compatible color decoder is not available in this package build."
            ),
            (
                .imageCreationFailed,
                "Failed to create an image from the decoder output."
            )
        ]

        for item in cases {
            XCTAssertEqual(item.error.errorDescription, item.description)
        }
    }

    private func makeInvalidMetadataBundle() throws -> (Bundle, URL) {
        let fileManager = FileManager.default
        let bundleURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        let modelsURL = bundleURL
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(VAEThumbnailBundledModel.grayscaleV1.identifier, isDirectory: true)

        try fileManager.createDirectory(at: modelsURL, withIntermediateDirectories: true)
        try minimalBundleInfoPlist().write(
            to: bundleURL.appendingPathComponent("Info.plist"),
            atomically: true,
            encoding: .utf8
        )

        let sourceModelURL = try bundledModelDirectory(for: .grayscaleV1)
        try fileManager.copyItem(
            at: sourceModelURL.appendingPathComponent("decoder.mlmodelc", isDirectory: true),
            to: modelsURL.appendingPathComponent("decoder.mlmodelc", isDirectory: true)
        )
        try invalidMetadataJSON().write(
            to: modelsURL.appendingPathComponent("metadata.json"),
            atomically: true,
            encoding: .utf8
        )

        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        return (bundle, bundleURL)
    }

    private func bundledModelDirectory(for model: VAEThumbnailBundledModel) throws -> URL {
        let resourceRoot = try XCTUnwrap(Bundle.module.resourceURL)
        let fileManager = FileManager.default
        let candidates = [
            resourceRoot.appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent(model.identifier, isDirectory: true),
            resourceRoot.appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent(model.identifier, isDirectory: true),
            resourceRoot.appendingPathComponent(model.identifier, isDirectory: true)
        ]

        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        throw XCTSkip("Could not locate bundled model resources for \(model.identifier).")
    }

    private func minimalBundleInfoPlist() -> String {
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
        <plist version=\"1.0\">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.mitchellcurrie.vae-thumbnail.invalid-metadata</string>
            <key>CFBundleName</key>
            <string>InvalidMetadataBundle</string>
        </dict>
        </plist>
        """
    }

    private func invalidMetadataJSON() -> String {
        """
        {
          "name": "broken_v1",
          "model_id": "placeholder_ae_v1_gray",
          "input_size": 16,
          "output_size": 16,
          "color_channels": 1,
          "latent_dim": 18,
          "quantize_bits": 8,
          "latent_min": [0.0],
          "latent_max": [1.0]
        }
        """
    }

    private func makeTemporaryBundle(models: [TemporaryModelFixture]) throws -> (Bundle, URL) {
        let fileManager = FileManager.default
        let bundleURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")

        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try minimalBundleInfoPlist().write(
            to: bundleURL.appendingPathComponent("Info.plist"),
            atomically: true,
            encoding: .utf8
        )

        for fixture in models {
            let modelURL = bundleURL
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent(fixture.model.identifier, isDirectory: true)
            try fileManager.createDirectory(at: modelURL, withIntermediateDirectories: true)

            if fixture.includeDecoder {
                let sourceModelURL = try bundledModelDirectory(for: fixture.model)
                try fileManager.copyItem(
                    at: sourceModelURL.appendingPathComponent("decoder.mlmodelc", isDirectory: true),
                    to: modelURL.appendingPathComponent("decoder.mlmodelc", isDirectory: true)
                )
            }

            if let metadataJSON = fixture.metadataJSON {
                try metadataJSON.write(
                    to: modelURL.appendingPathComponent("metadata.json"),
                    atomically: true,
                    encoding: .utf8
                )
            }
        }

        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        return (bundle, bundleURL)
    }

    private func makeMetadataJSON(
        modelID: String = VAEThumbnailBundledModel.grayscaleV1.identifier,
        outputSize: Int = 16,
        latentDim: Int = 18,
        quantizeBits: Int = 8,
        colorChannels: Int = 1,
        latentMin: [Double]? = nil,
        latentMax: [Double]? = nil
    ) throws -> String {
        let latentMin = latentMin ?? Array(repeating: 0.0, count: latentDim)
        let latentMax = latentMax ?? Array(repeating: 1.0, count: latentDim)

        let payload: [String: Any] = [
            "name": "placeholder_test_model",
            "model_id": modelID,
            "input_size": outputSize,
            "output_size": outputSize,
            "color_channels": colorChannels,
            "latent_dim": latentDim,
            "quantize_bits": quantizeBits,
            "latent_min": latentMin,
            "latent_max": latentMax
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        guard let json = String(bytes: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return json
    }
}
