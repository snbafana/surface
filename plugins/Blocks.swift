import ActivityContext
import CodexLog
import CopyHistory
import Core
import FollowUpQueue
import GitHubQueue
import Quicksave

public enum Blocks {
    public static let registry = try! BlockRegistry([
        Quicksave.Plugin.block,
        CopyHistory.Plugin.block,
        CodexLog.Plugin.block,
        ActivityContext.Plugin.block,
        FollowUpQueue.Plugin.block,
        GitHubQueue.Plugin.block
    ])
}
