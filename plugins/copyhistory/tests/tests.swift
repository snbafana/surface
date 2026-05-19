import CopyHistory
import Core
import Testing

@Suite("Copy History plugin")
struct CopyHistoryTests {
    @MainActor
    @Test func blockCreatesRuntimeAndView() {
        #expect(Plugin.block.id == "copyhistory")

        let runtime = Plugin.block.makeRuntime(Block.Context())
        runtime.start()
        _ = runtime.makeView()
        runtime.stop()
    }
}
