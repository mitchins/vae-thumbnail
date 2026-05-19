import CoreGraphics
import Foundation
#if canImport(AppKit)
    import AppKit
#endif
#if canImport(UIKit)
    import UIKit
#endif

public enum VAEThumbnailRenderedColorMode: String, Sendable, Hashable, Codable {
    case grayscale
    case color
}

public struct VAEThumbnailOutput: @unchecked Sendable {
    public let cgImage: CGImage
    public let renderedColorMode: VAEThumbnailRenderedColorMode
    public let model: VAEThumbnailBundledModel
    public let modelName: String

    public init(
        cgImage: CGImage,
        renderedColorMode: VAEThumbnailRenderedColorMode,
        model: VAEThumbnailBundledModel,
        modelName: String
    ) {
        self.cgImage = cgImage
        self.renderedColorMode = renderedColorMode
        self.model = model
        self.modelName = modelName
    }

    public var pixelSize: CGSize {
        CGSize(width: cgImage.width, height: cgImage.height)
    }

    public var modelIdentifier: String {
        model.identifier
    }
}

#if canImport(UIKit)
    public extension VAEThumbnailOutput {
        var uiImage: UIImage {
            UIImage(cgImage: cgImage)
        }
    }
#endif

#if canImport(AppKit)
    public extension VAEThumbnailOutput {
        var nsImage: NSImage {
            NSImage(cgImage: cgImage, size: pixelSize)
        }
    }
#endif
