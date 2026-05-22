import Core

public enum Plugin {
    public static let block = Block(
        id: "codexlog",
        title: "Codex Log",
        defaultSize: GridSize(width: 8, height: 10)
    ) { context in
        let codexHome = context.storageDirectory ?? CodexStateReader.defaultCodexHome
        return Runtime(
            reader: CodexStateReader(
                codexHome: codexHome,
                includeProcesses: context.allowsLiveProcesses
            )
        )
    }
}
