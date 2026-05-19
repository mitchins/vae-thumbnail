import CoreGraphics
@testable import VAEThumbnailKit
import XCTest

final class VAEThumbnailGeneratorTests: XCTestCase {
    private let validPayload = "iHF9oYBndICMcZqMeXeZjwD/"

    func testValidPayloadDecodesBundledModel() async throws {
        let generator = try VAEThumbnailGenerator()

        let output = try await generator.generateThumbnail(from: .init(latentPayload: validPayload))

        XCTAssertEqual(output.pixelSize, CGSize(width: 16, height: 16))
        XCTAssertEqual(output.renderedColorMode, .grayscale)
        XCTAssertEqual(output.model, .grayscaleV1)
        XCTAssertEqual(output.modelName, "placeholder_ae_v1")
    }

    func testExplicitBundledModelHintUsesV1() async throws {
        let generator = try VAEThumbnailGenerator()

        let output = try await generator.generateThumbnail(
            from: .init(latentPayload: validPayload, model: .grayscaleV1)
        )

        XCTAssertEqual(output.modelIdentifier, VAEThumbnailBundledModel.grayscaleV1.identifier)
        XCTAssertEqual(output.renderedColorMode, .grayscale)
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

    func testColorRequestFailsForGrayscaleOnlyBundledModel() async throws {
        let generator = try VAEThumbnailGenerator()
        let configuration = VAEThumbnailConfiguration(colorMode: .color)

        do {
            _ = try await generator.generateThumbnail(
                from: .init(latentPayload: validPayload),
                configuration: configuration
            )
            XCTFail("Expected the grayscale-only bundled model to reject a color request.")
        } catch let error as VAEThumbnailError {
            XCTAssertEqual(error, .colorModelUnavailable)
        }
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

    func testMissingExplicitRgbModelThrowsRequestedModelUnavailable() async throws {
        let generator = try VAEThumbnailGenerator()

        do {
            _ = try await generator.generateThumbnail(
                from: .init(latentPayload: validPayload, model: .rgbV2)
            )
            XCTFail("Expected unavailable rgb model hint to throw.")
        } catch let error as VAEThumbnailError {
            XCTAssertEqual(error, .requestedModelUnavailable(.rgbV2))
        }
    }
}
