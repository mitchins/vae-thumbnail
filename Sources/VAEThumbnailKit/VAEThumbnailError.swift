import CoreGraphics
import Foundation

public enum VAEThumbnailError: LocalizedError, Equatable {
    case noBundledModelsAvailable
    case metadataNotFound(model: VAEThumbnailBundledModel)
    case modelNotFound(model: VAEThumbnailBundledModel)
    case invalidMetadata
    case invalidPayloadBase64
    case invalidPayloadLength(expectedBytes: Int, actualBytes: Int)
    case invalidOutputSize(CGSize)
    case unexpectedModelInterface
    case unexpectedOutputShape(elementCount: Int, expectedPixels: Int)
    case requestedModelUnavailable(VAEThumbnailBundledModel)
    case noCompatibleModelForPayload(
        actualBytes: Int,
        requestedColorMode: VAEThumbnailColorMode,
        requestedModel: VAEThumbnailBundledModel?
    )
    case unsupportedOutputType
    case colorModelUnavailable
    case imageCreationFailed

    public var errorDescription: String? {
        switch self {
        case .noBundledModelsAvailable:
            return "No bundled VAE thumbnail models are available in the package resources."
        case let .metadataNotFound(model):
            return "The metadata.json file for bundled model \(model.identifier) is missing from the package resources."
        case let .modelNotFound(model):
            return "The decoder.mlmodelc bundle for bundled model \(model.identifier) is missing from the package resources."
        case .invalidMetadata:
            return "The bundled VAE thumbnail metadata is invalid."
        case .invalidPayloadBase64:
            return "The supplied thumbnail payload is not valid base64."
        case let .invalidPayloadLength(expectedBytes, actualBytes):
            return "The supplied thumbnail payload decoded to \(actualBytes) bytes instead of \(expectedBytes)."
        case let .invalidOutputSize(size):
            return "The requested thumbnail output size \(size.width)x\(size.height) is invalid."
        case .unexpectedModelInterface:
            return "The bundled CoreML decoder does not expose a usable input/output pair."
        case let .unexpectedOutputShape(elementCount, expectedPixels):
            return "The decoder output shape is unsupported. Got \(elementCount) values for \(expectedPixels) expected pixels."
        case let .requestedModelUnavailable(model):
            return "The requested bundled model \(model.identifier) is not available in this package build."
        case let .noCompatibleModelForPayload(actualBytes, requestedColorMode, requestedModel):
            let requested = requestedModel?.identifier ?? "automatic bundled selection"
            return "No bundled model can decode a \(actualBytes)-byte payload for \(requestedColorMode.rawValue) mode using \(requested)."
        case .unsupportedOutputType:
            return "The decoder returned an unsupported output type."
        case .colorModelUnavailable:
            return "A real color decoder is not bundled. Only grayscale-capable models are available."
        case .imageCreationFailed:
            return "Failed to create an image from the decoder output."
        }
    }
}
