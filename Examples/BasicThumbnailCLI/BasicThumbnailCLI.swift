import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VAEThumbnailKit

private enum CLIError: LocalizedError {
    case missingValue(String)
    case invalidArgument(String)
    case invalidColorMode(String)
    case invalidInteger(String, String)
    case failedToCreateImageDestination(URL)
    case failedToWriteImage(URL)

    var errorDescription: String? {
        switch self {
        case let .missingValue(flag):
            "Missing value for \(flag)."
        case let .invalidArgument(value):
            "Unsupported argument: \(value)."
        case let .invalidColorMode(value):
            "Unsupported color mode: \(value). Use grayscale, color, or automatic."
        case let .invalidInteger(flag, value):
            "Invalid integer for \(flag): \(value)."
        case let .failedToCreateImageDestination(url):
            "Could not create an image destination at \(url.path)."
        case let .failedToWriteImage(url):
            "Could not write PNG output to \(url.path)."
        }
    }
}

private struct Arguments {
    let payload: String
    let outputURL: URL
    let width: Int
    let height: Int
    let colorMode: VAEThumbnailColorMode

    static func parse(_ arguments: ArraySlice<String>) throws -> Arguments {
        var payload = "iHF9oYBndICMcZqMeXeZjwD/"
        var outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "vae-thumbnail.png")
        var width = 64
        var height = 64
        var colorMode: VAEThumbnailColorMode = .automatic

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--payload":
                guard let value = iterator.next() else { throw CLIError.missingValue(argument) }
                payload = value
            case "--output":
                guard let value = iterator.next() else { throw CLIError.missingValue(argument) }
                outputURL = URL(fileURLWithPath: value)
            case "--width":
                guard let value = iterator.next() else { throw CLIError.missingValue(argument) }
                guard let parsed = Int(value) else { throw CLIError.invalidInteger(argument, value) }
                width = parsed
            case "--height":
                guard let value = iterator.next() else { throw CLIError.missingValue(argument) }
                guard let parsed = Int(value) else { throw CLIError.invalidInteger(argument, value) }
                height = parsed
            case "--color":
                guard let value = iterator.next() else { throw CLIError.missingValue(argument) }
                guard let parsed = VAEThumbnailColorMode(rawValue: value) else {
                    throw CLIError.invalidColorMode(value)
                }
                colorMode = parsed
            case "--help", "-h":
                printUsage()
                Foundation.exit(0)
            default:
                throw CLIError.invalidArgument(argument)
            }
        }

        return Arguments(
            payload: payload,
            outputURL: outputURL,
            width: width,
            height: height,
            colorMode: colorMode
        )
    }

    static func printUsage() {
        print(
            """
            Usage: swift run BasicThumbnailCLI [options]

              --payload <base64>    VAE thumbnail payload. Defaults to the synthetic test payload.
              --output <path>       PNG output path. Defaults to ./vae-thumbnail.png.
              --width <int>         Output width. Defaults to 64.
              --height <int>        Output height. Defaults to 64.
              --color <mode>        grayscale | automatic | color. Defaults to automatic.
            """
        )
    }
}

@main
private struct BasicThumbnailCLI {
    static func main() throws {
        do {
            let arguments = try Arguments.parse(CommandLine.arguments.dropFirst())
            let generator = try VAEThumbnailGenerator()
            let output = try generator.generateThumbnailSynchronously(
                from: .init(latentPayload: arguments.payload),
                configuration: .init(
                    outputSize: CGSize(width: arguments.width, height: arguments.height),
                    colorMode: arguments.colorMode,
                    quality: .best
                )
            )
            try writePNG(output.cgImage, to: arguments.outputURL)
            print(
                "Wrote \(output.renderedColorMode.rawValue) thumbnail \(Int(output.pixelSize.width))x\(Int(output.pixelSize.height)) to \(arguments.outputURL.path)"
            )
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            Arguments.printUsage()
            Foundation.exit(1)
        }
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CLIError.failedToCreateImageDestination(url)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CLIError.failedToWriteImage(url)
        }
    }
}
