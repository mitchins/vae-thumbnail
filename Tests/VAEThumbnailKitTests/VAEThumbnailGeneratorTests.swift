import CoreGraphics
import Foundation
@testable import VAEThumbnailKit
import XCTest

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

    func testRequestedOutputSizeResizesDecodedImage() async throws {
        let generator = try VAEThumbnailGenerator()
        let configuration = VAEThumbnailConfiguration(
            outputSize: CGSize(width: 32, height: 24),
            colorMode: .automatic,
            quality: .best
        )

        let output = try await generator.generateThumbnail(
            from: .init(latentPayload: validPayload),
            configuration: configuration
        )

        XCTAssertEqual(output.pixelSize, CGSize(width: 32, height: 24))
        XCTAssertEqual(output.renderedColorMode, .grayscale)
    }

    func testInvalidBundledMetadataThrowsInvalidMetadata() throws {
        let (bundle, bundleURL) = try makeInvalidMetadataBundle()
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        XCTAssertThrowsError(try VAEThumbnailGenerator(bundle: bundle)) { error in
            XCTAssertEqual(error as? VAEThumbnailError, .invalidMetadata)
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
}
