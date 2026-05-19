import BlockPreviewSupport
import Core
import Foundation

enum BlockPreviewCommand {
    static func runMain() async throws {
        do {
            try await MainActor.run {
                try run()
            }
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            Foundation.exit(1)
        }
    }

    @MainActor
    private static func run() throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsage()
            return
        }
        arguments.removeFirst()

        let options = PreviewOptions(arguments: arguments)
        switch command {
        case "list":
            for previewCase in BlockPreview.cases {
                print("\(previewCase.blockID.rawValue)\t\(previewCase.fixture)\t\(Int(previewCase.size.width))x\(Int(previewCase.size.height))")
            }
        case "all":
            let results = try BlockPreview.renderAll(outputDirectory: options.outputDirectory)
            printResults(results)
        case "help", "--help", "-h":
            printUsage()
        default:
            let fixture = options.fixture ?? "empty"
            let size = options.size ?? defaultSize(for: BlockID(rawValue: command), fixture: fixture)
            let result = try BlockPreview.render(
                blockID: BlockID(rawValue: command),
                fixture: fixture,
                size: size,
                outputDirectory: options.outputDirectory
            )
            printResults([result])
        }
    }

    private static func defaultSize(for blockID: BlockID, fixture: String) -> CGSize {
        BlockPreview.cases
            .first { $0.blockID == blockID && $0.fixture == fixture }?
            .size ?? CGSize(width: 420, height: 420)
    }

    private static func printResults(_ results: [BlockPreviewResult]) {
        for result in results {
            let metrics = result.metrics
            print(
                [
                    result.previewCase.blockID.rawValue,
                    result.previewCase.fixture,
                    result.url.path,
                    "\(metrics.width)x\(metrics.height)",
                    "bytes=\(metrics.byteCount)",
                    "colors=\(metrics.distinctSampledColors)",
                    "nonBackground=\(metrics.nonBackgroundSampleCount)"
                ].joined(separator: "\t")
            )
        }
    }

    private static func printUsage() {
        print(
            """
            Usage:
              swift run block-preview list
              swift run block-preview all [--output .build/block-previews]
              swift run block-preview <block-id> [--fixture name] [--size 420x520] [--output dir]

            Examples:
              swift run block-preview quicksave --fixture notes-and-captures --size 420x520
              swift run block-preview copyhistory --fixture mixed-clipboard
              swift run block-preview codexlog --fixture active-thread
            """
        )
    }
}

do {
    try await BlockPreviewCommand.runMain()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    Foundation.exit(1)
}

private struct PreviewOptions {
    var fixture: String?
    var size: CGSize?
    var outputDirectory = BlockPreview.defaultOutputDirectory

    init(arguments: [String]) {
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            let value = index + 1 < arguments.count ? arguments[index + 1] : nil
            switch argument {
            case "--fixture":
                fixture = value
                index += 2
            case "--size":
                size = value.flatMap(Self.parseSize)
                index += 2
            case "--output":
                if let value {
                    outputDirectory = URL(fileURLWithPath: value, isDirectory: true)
                }
                index += 2
            default:
                index += 1
            }
        }
    }

    private static func parseSize(_ raw: String) -> CGSize? {
        let parts = raw.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]) else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}
