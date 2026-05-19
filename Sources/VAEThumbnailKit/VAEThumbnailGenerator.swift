import CoreGraphics
import CoreML
import Foundation

public final class VAEThumbnailGenerator: VAEThumbnailGenerating, @unchecked Sendable {
    private struct Metadata: Decodable {
        let name: String
        let modelID: String?
        let latentDim: Int
        let quantizeBits: Int
        let inputSize: Int?
        let outputSize: Int
        let colorChannels: Int?
        let latentMin: [Float]
        let latentMax: [Float]

        enum CodingKeys: String, CodingKey {
            case name
            case modelID = "model_id"
            case latentDim = "latent_dim"
            case quantizeBits = "quantize_bits"
            case inputSize = "input_size"
            case outputSize = "output_size"
            case colorChannels = "color_channels"
            case latentMin = "latent_min"
            case latentMax = "latent_max"
        }

        var resolvedColorChannels: Int {
            max(colorChannels ?? 1, 1)
        }
    }

    private struct LoadedResources {
        let bundledModel: VAEThumbnailBundledModel
        let metadata: Metadata
        let model: MLModel
        let inputName: String
        let outputName: String
        let latentRange: [Float]

        var expectedPayloadBytes: Int {
            Int(ceil(Double(metadata.latentDim * metadata.quantizeBits) / 8.0))
        }

        var supportsColorOutput: Bool {
            metadata.resolvedColorChannels >= 3
        }
    }

    private final class CachedOutput: NSObject {
        let value: VAEThumbnailOutput

        init(value: VAEThumbnailOutput) {
            self.value = value
        }
    }

    private let resourcesByModel: [VAEThumbnailBundledModel: LoadedResources]
    private let cache = NSCache<NSString, CachedOutput>()

    public convenience init() throws {
        try self.init(bundle: .module)
    }

    public init(bundle: Bundle) throws {
        resourcesByModel = try Self.loadAvailableResources(bundle: bundle)
        cache.countLimit = 2048
    }

    public func generateThumbnailSynchronously(
        from input: VAEThumbnailInput,
        configuration: VAEThumbnailConfiguration = .default
    ) throws -> VAEThumbnailOutput {
        let cacheKey = Self.cacheKey(for: input, configuration: configuration) as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached.value
        }

        let payloadData = try Self.decodePayloadData(input.latentPayload)
        let resources = try selectResources(
            for: input,
            configuration: configuration,
            payloadByteCount: payloadData.count
        )
        let output = try Self.decodeImage(
            payloadData: payloadData,
            resources: resources,
            configuration: configuration
        )
        cache.setObject(CachedOutput(value: output), forKey: cacheKey)
        return output
    }

    public func generateThumbnail(
        from input: VAEThumbnailInput,
        configuration: VAEThumbnailConfiguration
    ) async throws -> VAEThumbnailOutput {
        try generateThumbnailSynchronously(from: input, configuration: configuration)
    }

    private static func cacheKey(
        for input: VAEThumbnailInput,
        configuration: VAEThumbnailConfiguration
    ) -> String {
        [
            input.latentPayload,
            input.model?.identifier ?? "auto",
            String(format: "%.3f", configuration.outputSize.width),
            String(format: "%.3f", configuration.outputSize.height),
            configuration.colorMode.rawValue,
            configuration.quality.rawValue
        ].joined(separator: "|")
    }

    private static func decodePayloadData(_ payload: String) throws -> Data {
        guard let payloadData = Data(base64Encoded: payload) else {
            throw VAEThumbnailError.invalidPayloadBase64
        }
        return payloadData
    }

    private func selectResources(
        for input: VAEThumbnailInput,
        configuration: VAEThumbnailConfiguration,
        payloadByteCount: Int
    ) throws -> LoadedResources {
        guard !resourcesByModel.isEmpty else {
            throw VAEThumbnailError.noBundledModelsAvailable
        }

        if let requestedModel = input.model {
            guard let resources = resourcesByModel[requestedModel] else {
                throw VAEThumbnailError.requestedModelUnavailable(requestedModel)
            }
            guard resources.expectedPayloadBytes == payloadByteCount else {
                throw VAEThumbnailError.invalidPayloadLength(
                    expectedBytes: resources.expectedPayloadBytes,
                    actualBytes: payloadByteCount
                )
            }
            if configuration.colorMode == .color, !resources.supportsColorOutput {
                throw VAEThumbnailError.colorModelUnavailable
            }
            return resources
        }

        let compatibleResources = resourcesByModel.values.filter { $0.expectedPayloadBytes == payloadByteCount }
        guard !compatibleResources.isEmpty else {
            throw VAEThumbnailError.noCompatibleModelForPayload(
                actualBytes: payloadByteCount,
                requestedColorMode: configuration.colorMode,
                requestedModel: input.model
            )
        }

        let preferenceOrder = Self.preferenceOrder(for: configuration.colorMode)
        for bundledModel in preferenceOrder {
            guard let resources = compatibleResources.first(where: { $0.bundledModel == bundledModel }) else {
                continue
            }
            if configuration.colorMode == .color, !resources.supportsColorOutput {
                continue
            }
            return resources
        }

        if configuration.colorMode == .color {
            if !resourcesByModel.values.contains(where: \.supportsColorOutput) {
                throw VAEThumbnailError.colorModelUnavailable
            }
        }

        throw VAEThumbnailError.noCompatibleModelForPayload(
            actualBytes: payloadByteCount,
            requestedColorMode: configuration.colorMode,
            requestedModel: input.model
        )
    }

    private static func preferenceOrder(for colorMode: VAEThumbnailColorMode) -> [VAEThumbnailBundledModel] {
        switch colorMode {
        case .automatic:
            [.rgbV2, .grayscaleV1]
        case .color:
            [.rgbV2]
        case .grayscale:
            [.grayscaleV1, .rgbV2]
        }
    }

    private static func decodeImage(
        payloadData: Data,
        resources: LoadedResources,
        configuration: VAEThumbnailConfiguration
    ) throws -> VAEThumbnailOutput {
        let requestedSize = CGSize(
            width: configuration.outputSize.width.rounded(),
            height: configuration.outputSize.height.rounded()
        )
        guard requestedSize.width > 0, requestedSize.height > 0 else {
            throw VAEThumbnailError.invalidOutputSize(configuration.outputSize)
        }

        let metadata = resources.metadata
        guard payloadData.count == resources.expectedPayloadBytes else {
            throw VAEThumbnailError.invalidPayloadLength(
                expectedBytes: resources.expectedPayloadBytes,
                actualBytes: payloadData.count
            )
        }
        let latentArray = try MLMultiArray(
            shape: [1, NSNumber(value: metadata.latentDim)],
            dataType: .float32
        )
        let inputPointer = latentArray.dataPointer.bindMemory(to: Float32.self, capacity: metadata.latentDim)
        let levels = Float((1 << metadata.quantizeBits) - 1)

        for index in 0 ..< metadata.latentDim {
            let code = Float(payloadData[payloadData.startIndex.advanced(by: index)])
            inputPointer[index] = metadata.latentMin[index] + (code / levels) * resources.latentRange[index]
        }

        let provider = try MLDictionaryFeatureProvider(
            dictionary: [resources.inputName: MLFeatureValue(multiArray: latentArray)]
        )
        let prediction = try resources.model.prediction(from: provider)
        guard let outputArray = prediction.featureValue(for: resources.outputName)?.multiArrayValue else {
            throw VAEThumbnailError.unsupportedOutputType
        }

        var output = try image(
            from: outputArray,
            sourceSize: metadata.outputSize,
            requestedColorMode: configuration.colorMode,
            bundledModel: resources.bundledModel,
            modelName: metadata.name
        )

        if output.pixelSize != requestedSize {
            let scaled = try scale(
                image: output.cgImage,
                colorMode: output.renderedColorMode,
                outputSize: requestedSize,
                quality: configuration.quality
            )
            output = VAEThumbnailOutput(
                cgImage: scaled,
                renderedColorMode: output.renderedColorMode,
                model: output.model,
                modelName: output.modelName
            )
        }

        return output
    }

    private static func loadAvailableResources(bundle: Bundle) throws -> [VAEThumbnailBundledModel: LoadedResources] {
        var loaded = [VAEThumbnailBundledModel: LoadedResources]()

        for bundledModel in VAEThumbnailBundledModel.allCases {
            guard let modelDirectoryURL = modelDirectoryURL(for: bundledModel, bundle: bundle) else {
                continue
            }

            let metadataURL = modelDirectoryURL.appendingPathComponent("metadata.json")
            guard FileManager.default.fileExists(atPath: metadataURL.path) else {
                throw VAEThumbnailError.metadataNotFound(model: bundledModel)
            }

            let decoderURL = modelDirectoryURL.appendingPathComponent("decoder.mlmodelc", isDirectory: true)
            guard FileManager.default.fileExists(atPath: decoderURL.path) else {
                throw VAEThumbnailError.modelNotFound(model: bundledModel)
            }

            let metadata = try JSONDecoder().decode(Metadata.self, from: Data(contentsOf: metadataURL))
            guard metadata.latentMin.count == metadata.latentDim,
                  metadata.latentMax.count == metadata.latentDim
            else {
                throw VAEThumbnailError.invalidMetadata
            }
            guard metadata.quantizeBits == 8 else {
                throw VAEThumbnailError.invalidMetadata
            }

            let configuration = MLModelConfiguration()
            #if targetEnvironment(simulator)
                configuration.computeUnits = .cpuOnly
            #else
                configuration.computeUnits = .all
            #endif

            let model = try MLModel(contentsOf: decoderURL, configuration: configuration)
            guard let inputName = model.modelDescription.inputDescriptionsByName.keys.first,
                  let outputName = model.modelDescription.outputDescriptionsByName.keys.first
            else {
                throw VAEThumbnailError.unexpectedModelInterface
            }

            let latentRange = try zip(metadata.latentMin, metadata.latentMax).map { minimum, maximum in
                let delta = maximum - minimum
                guard delta > 0 else {
                    throw VAEThumbnailError.invalidMetadata
                }
                return delta
            }

            loaded[bundledModel] = LoadedResources(
                bundledModel: bundledModel,
                metadata: metadata,
                model: model,
                inputName: inputName,
                outputName: outputName,
                latentRange: latentRange
            )
        }

        guard !loaded.isEmpty else {
            throw VAEThumbnailError.noBundledModelsAvailable
        }

        return loaded
    }

    private static func modelDirectoryURL(
        for bundledModel: VAEThumbnailBundledModel,
        bundle: Bundle
    ) -> URL? {
        guard let resourceRoot = bundle.resourceURL else {
            return nil
        }

        let candidates = [
            resourceRoot.appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent(bundledModel.identifier, isDirectory: true),
            resourceRoot.appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent(bundledModel.identifier, isDirectory: true),
            resourceRoot.appendingPathComponent(bundledModel.identifier, isDirectory: true)
        ]

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private static func image(
        from outputArray: MLMultiArray,
        sourceSize: Int,
        requestedColorMode: VAEThumbnailColorMode,
        bundledModel: VAEThumbnailBundledModel,
        modelName: String
    ) throws -> VAEThumbnailOutput {
        let pixelCount = sourceSize * sourceSize
        guard pixelCount > 0 else {
            throw VAEThumbnailError.invalidMetadata
        }

        let values = normalizedValues(from: outputArray)
        let elementCount = values.count
        let channelCount = channelCount(for: elementCount, pixelCount: pixelCount)

        switch channelCount {
        case 1:
            if requestedColorMode == .color {
                throw VAEThumbnailError.colorModelUnavailable
            }
            let pixels = values.prefix(pixelCount).map(Self.byte(from:))
            guard let cgImage = grayscaleImage(width: sourceSize, height: sourceSize, pixels: Array(pixels)) else {
                throw VAEThumbnailError.imageCreationFailed
            }
            return VAEThumbnailOutput(
                cgImage: cgImage,
                renderedColorMode: .grayscale,
                model: bundledModel,
                modelName: modelName
            )
        case 3, 4:
            if requestedColorMode == .grayscale {
                let pixels = grayscalePixels(from: values, pixelCount: pixelCount)
                guard let cgImage = grayscaleImage(width: sourceSize, height: sourceSize, pixels: pixels) else {
                    throw VAEThumbnailError.imageCreationFailed
                }
                return VAEThumbnailOutput(
                    cgImage: cgImage,
                    renderedColorMode: .grayscale,
                    model: bundledModel,
                    modelName: modelName
                )
            }

            let rgbPixels = colorPixels(from: values, pixelCount: pixelCount)
            guard let cgImage = colorImage(width: sourceSize, height: sourceSize, rgbPixels: rgbPixels) else {
                throw VAEThumbnailError.imageCreationFailed
            }
            return VAEThumbnailOutput(
                cgImage: cgImage,
                renderedColorMode: .color,
                model: bundledModel,
                modelName: modelName
            )
        default:
            throw VAEThumbnailError.unexpectedOutputShape(
                elementCount: elementCount,
                expectedPixels: pixelCount
            )
        }
    }

    private static func normalizedValues(from outputArray: MLMultiArray) -> [Double] {
        var values = [Double](repeating: 0, count: outputArray.count)

        switch outputArray.dataType {
        case .float32:
            let pointer = outputArray.dataPointer.bindMemory(to: Float32.self, capacity: outputArray.count)
            for index in 0 ..< outputArray.count {
                values[index] = clamped(Double(pointer[index]))
            }
        case .double:
            let pointer = outputArray.dataPointer.bindMemory(to: Double.self, capacity: outputArray.count)
            for index in 0 ..< outputArray.count {
                values[index] = clamped(pointer[index])
            }
        default:
            for index in 0 ..< outputArray.count {
                values[index] = clamped(outputArray[index].doubleValue)
            }
        }

        return values
    }

    private static func channelCount(for elementCount: Int, pixelCount: Int) -> Int {
        guard pixelCount > 0, elementCount % pixelCount == 0 else {
            return -1
        }
        return elementCount / pixelCount
    }

    private static func grayscalePixels(from values: [Double], pixelCount: Int) -> [UInt8] {
        guard values.count >= pixelCount * 3 else {
            return values.prefix(pixelCount).map(byte(from:))
        }

        return (0 ..< pixelCount).map { index in
            let red = values[index]
            let green = values[pixelCount + index]
            let blue = values[(pixelCount * 2) + index]
            return byte(from: (0.2126 * red) + (0.7152 * green) + (0.0722 * blue))
        }
    }

    private static func colorPixels(from values: [Double], pixelCount: Int) -> [UInt8] {
        (0 ..< pixelCount).flatMap { index in
            let red = byte(from: values[index])
            let green = byte(from: values[pixelCount + index])
            let blue = byte(from: values[(pixelCount * 2) + index])
            return [red, green, blue]
        }
    }

    private static func grayscaleImage(width: Int, height: Int, pixels: [UInt8]) -> CGImage? {
        guard pixels.count == width * height else { return nil }
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func colorImage(width: Int, height: Int, rgbPixels: [UInt8]) -> CGImage? {
        guard rgbPixels.count == width * height * 3 else { return nil }

        var rgbaPixels = [UInt8](repeating: 255, count: width * height * 4)
        for index in 0 ..< (width * height) {
            rgbaPixels[index * 4] = rgbPixels[index * 3]
            rgbaPixels[(index * 4) + 1] = rgbPixels[(index * 3) + 1]
            rgbaPixels[(index * 4) + 2] = rgbPixels[(index * 3) + 2]
        }

        let data = Data(rgbaPixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func scale(
        image: CGImage,
        colorMode: VAEThumbnailRenderedColorMode,
        outputSize: CGSize,
        quality: VAEThumbnailQuality
    ) throws -> CGImage {
        let width = Int(outputSize.width)
        let height = Int(outputSize.height)
        guard width > 0, height > 0 else {
            throw VAEThumbnailError.invalidOutputSize(outputSize)
        }

        let colorSpace: CGColorSpace
        let bitmapInfo: UInt32
        switch colorMode {
        case .grayscale:
            colorSpace = CGColorSpaceCreateDeviceGray()
            bitmapInfo = CGImageAlphaInfo.none.rawValue
        case .color:
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw VAEThumbnailError.imageCreationFailed
        }

        context.interpolationQuality = quality.cgInterpolationQuality
        context.draw(image, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))

        guard let scaled = context.makeImage() else {
            throw VAEThumbnailError.imageCreationFailed
        }
        return scaled
    }

    private static func clamped(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }

    private static func byte(from value: Double) -> UInt8 {
        UInt8((clamped(value) * 255.0).rounded())
    }
}

private extension VAEThumbnailQuality {
    var cgInterpolationQuality: CGInterpolationQuality {
        switch self {
        case .fast:
            .low
        case .balanced:
            .medium
        case .best:
            .high
        }
    }
}
