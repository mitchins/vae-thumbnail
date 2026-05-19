import Foundation

public enum VAEThumbnailBundledModel: String, Sendable, Hashable, Codable, CaseIterable {
    case grayscaleV1 = "placeholder_ae_v1_gray"
    case rgbV2 = "placeholder_ae_v2_rgb"

    public var identifier: String {
        rawValue
    }
}
