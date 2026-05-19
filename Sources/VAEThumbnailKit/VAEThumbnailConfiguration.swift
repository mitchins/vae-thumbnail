import CoreGraphics
import Foundation

public struct VAEThumbnailConfiguration: Sendable, Hashable {
    public var outputSize: CGSize
    public var colorMode: VAEThumbnailColorMode
    public var quality: VAEThumbnailQuality

    public init(
        outputSize: CGSize = CGSize(width: 16, height: 16),
        colorMode: VAEThumbnailColorMode = .automatic,
        quality: VAEThumbnailQuality = .balanced
    ) {
        self.outputSize = outputSize
        self.colorMode = colorMode
        self.quality = quality
    }

    public static let `default` = Self()
}

public enum VAEThumbnailColorMode: String, Sendable, Hashable, Codable {
    case grayscale
    case color
    case automatic
}

public enum VAEThumbnailQuality: String, Sendable, Hashable, Codable {
    case fast
    case balanced
    case best
}
