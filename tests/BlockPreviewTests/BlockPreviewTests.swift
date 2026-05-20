import BlockPreviewSupport
import Foundation
import Testing

@Suite("Block preview")
struct BlockPreviewTests {
    @MainActor
    @Test func rendersEveryPreviewFixture() throws {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-block-preview-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let results = try BlockPreview.renderAll(outputDirectory: outputDirectory)

        #expect(results.count == BlockPreview.cases.count)
        for result in results {
            #expect(FileManager.default.fileExists(atPath: result.url.path))
            #expect(result.metrics.width >= Int(result.previewCase.size.width))
            #expect(result.metrics.height >= Int(result.previewCase.size.height))
            #expect(result.metrics.isVisuallyNonBlank)
        }
    }

    @MainActor
    @Test func rendersWholeSurfacePreview() throws {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-block-preview-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let result = try BlockPreview.renderSurface(
            size: CGSize(width: 1440, height: 900),
            outputDirectory: outputDirectory
        )

        #expect(FileManager.default.fileExists(atPath: result.url.path))
        #expect(result.metrics.width >= 1440)
        #expect(result.metrics.height >= 900)
        #expect(result.metrics.isVisuallyNonBlank)
    }

    @Test func previewCasesCoverEveryCurrentPlugin() {
        let covered = Set(BlockPreview.cases.map(\.blockID.rawValue))

        #expect(covered == ["quicksave", "copyhistory", "codexlog"])
    }
}
