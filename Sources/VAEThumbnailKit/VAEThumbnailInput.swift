import Foundation

public struct VAEThumbnailInput: Sendable, Hashable {
    public var latentPayload: String
    public var model: VAEThumbnailBundledModel?

    public init(latentPayload: String, model: VAEThumbnailBundledModel? = nil) {
        self.latentPayload = latentPayload
        self.model = model
    }
}

public protocol VAEThumbnailGenerating: Sendable {
    func generateThumbnail(
        from input: VAEThumbnailInput,
        configuration: VAEThumbnailConfiguration
    ) async throws -> VAEThumbnailOutput
}

public extension VAEThumbnailGenerating {
    func generateThumbnail(from input: VAEThumbnailInput) async throws -> VAEThumbnailOutput {
        try await generateThumbnail(from: input, configuration: .default)
    }
}
