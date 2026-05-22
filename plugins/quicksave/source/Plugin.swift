import Core

public enum Plugin {
    public static let block = Block(
        id: "quicksave",
        title: "Quicksave",
        defaultSize: GridSize(width: 10, height: 5)
    ) { context in
        Runtime(context: context)
    }
}
