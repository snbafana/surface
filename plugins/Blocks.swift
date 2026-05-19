import CodexLog
import CopyHistory
import Core
import Quicksave

public enum Blocks {
    public static let registry = try! BlockRegistry([
        Quicksave.Plugin.block,
        CopyHistory.Plugin.block,
        CodexLog.Plugin.block
    ])
}
