import AppKit
import Carbon
import Core
import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runtime = SurfaceRuntime()
    private var panel: SurfacePanel?
    private var hotKeys: SurfaceHotKeys?
    private var localKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panel = SurfacePanel()
        panel.contentView = NSHostingView(
            rootView: SurfaceEditorView()
                .environmentObject(runtime)
                .background(.clear)
        )
        self.panel = panel
        runtime.attach(panel: panel)

        hotKeys = SurfaceHotKeys { [weak runtime] in
            runtime?.toggleOverlay()
        }
        hotKeys?.install()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak runtime] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let characters = event.charactersIgnoringModifiers?.lowercased()
            if flags.contains(.command), characters == "e" {
                MainActor.assumeIsolated {
                    runtime?.toggleOverlay()
                }
                return nil
            }

            guard event.keyCode == UInt16(kVK_Escape) else {
                return event
            }
            MainActor.assumeIsolated {
                runtime?.hideOverlay()
            }
            return nil
        }

        runtime.hideOverlay()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }
}

@MainActor
final class SurfaceRuntime: ObservableObject {
    @Published var isOverlayVisible = false
    @Published var mode = SurfaceMode.use

    private weak var panel: SurfacePanel?

    func attach(panel: SurfacePanel) {
        self.panel = panel
        applyOverlayVisibility()
    }

    func toggleOverlay() {
        isOverlayVisible ? hideOverlay() : showUseMode()
    }

    func showUseMode() {
        isOverlayVisible = true
        mode = .use
        applyOverlayVisibility()
    }

    func showEditMode() {
        isOverlayVisible = true
        mode = .edit
        applyOverlayVisibility()
    }

    func hideOverlay() {
        isOverlayVisible = false
        mode = .use
        applyOverlayVisibility()
    }

    private func applyOverlayVisibility() {
        guard let panel else { return }
        if isOverlayVisible {
            panel.prepareForSurfaceDisplay()
            NSApp.activate(ignoringOtherApps: true)
            panel.orderFrontRegardless()
            panel.makeKey()
        } else {
            panel.orderOut(nil)
        }
    }
}

final class SurfacePanel: NSPanel {
    init() {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        prepareForSurfaceDisplay()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func prepareForSurfaceDisplay() {
        let targetFrame = NSScreen.main?.visibleFrame ?? frame
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setFrame(targetFrame, display: true)
    }
}

final class SurfaceHotKeys {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onToggle: @MainActor () -> Void

    init(onToggle: @escaping @MainActor () -> Void) {
        self.onToggle = onToggle
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    func install() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard hotKeyID.signature == OSType("SURF".fourCharCode), hotKeyID.id == 1 else {
                    return noErr
                }

                let pointerAddress = UInt(bitPattern: userData)
                Task { @MainActor in
                    guard let pointer = UnsafeRawPointer(bitPattern: pointerAddress) else {
                        return
                    }
                    Unmanaged<SurfaceHotKeys>.fromOpaque(pointer).takeUnretainedValue().onToggle()
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType("SURF".fourCharCode), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_E), UInt32(cmdKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

struct SurfaceEditorView: View {
    @EnvironmentObject private var runtime: SurfaceRuntime
    @State private var workspace = DemoSurface.workspace
    @State private var dragging: [BlockID: CGSize] = [:]
    @State private var hoveredBlock: BlockID?
    @State private var menuCorner = OverlayCorner.topLeft
    @State private var menuDrag = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let grid = workspace.layout.grid
            let cellWidth = proxy.size.width / CGFloat(grid.columns)
            let cellHeight = proxy.size.height / CGFloat(grid.rows)
            let menuSize = CGSize(width: 270, height: 150)
            let margin = CGFloat(18)
            let menuOrigin = menuCorner.origin(in: proxy.size, size: menuSize, margin: margin)

            ZStack(alignment: .topLeading) {
                if runtime.mode == .edit {
                    Canvas { context, size in
                        var path = Path()
                        for column in 0...grid.columns {
                            let x = size.width * CGFloat(column) / CGFloat(grid.columns)
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for row in 0...grid.rows {
                            let y = size.height * CGFloat(row) / CGFloat(grid.rows)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 1)
                    }
                    .ignoresSafeArea()
                }

                if runtime.mode == .edit {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Surface")
                                .font(.headline)
                            ForEach(workspace.definitions) { definition in
                                Toggle(
                                    definition.title,
                                    isOn: Binding(
                                        get: { workspace.layout.blocks.first(where: { $0.id == definition.id })?.enabled ?? false },
                                        set: { isEnabled in try? workspace.setEnabled(isEnabled, for: definition.id) }
                                    )
                                )
                            }
                        }
                        Button("Use") {
                            withAnimation(.smooth(duration: 0.18)) {
                                dragging.removeAll()
                                hoveredBlock = nil
                                runtime.showUseMode()
                            }
                        }
                        .buttonStyle(.bordered)
                        Button("Esc") {
                            runtime.hideOverlay()
                        }
                        .keyboardShortcut(.escape, modifiers: [])
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .frame(width: menuSize.width, height: menuSize.height, alignment: .topLeading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .offset(x: menuOrigin.x + menuDrag.width, y: menuOrigin.y + menuDrag.height)
                    .animation(.smooth(duration: 0.16), value: menuCorner)
                    .animation(.smooth(duration: 0.12), value: menuDrag)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                menuDrag = value.translation
                            }
                            .onEnded { value in
                                let point = CGPoint(
                                    x: menuOrigin.x + value.translation.width + menuSize.width / 2,
                                    y: menuOrigin.y + value.translation.height + menuSize.height / 2
                                )
                                withAnimation(.smooth(duration: 0.18)) {
                                    menuCorner = OverlayCorner.nearest(to: point, in: proxy.size)
                                    menuDrag = .zero
                                }
                            }
                    )
                    .zIndex(10)
                } else {
                    Button("Edit") {
                        withAnimation(.smooth(duration: 0.18)) {
                            runtime.showEditMode()
                        }
                    }
                    .buttonStyle(.bordered)
                    .offset(x: 18, y: 18)
                    .zIndex(10)
                }

                ForEach(workspace.enabledBlocks) { block in
                    let isDragging = dragging[block.id] != nil
                    let isActive = runtime.mode == .edit && (hoveredBlock == block.id || isDragging)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title(for: block.id))
                            .font(.headline)
                        if isActive {
                            Text("\(block.frame.origin.x), \(block.frame.origin.y) / \(block.frame.size.width)x\(block.frame.size.height)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(
                        width: CGFloat(block.frame.size.width) * cellWidth - 8,
                        height: CGFloat(block.frame.size.height) * cellHeight - 8,
                        alignment: .topLeading
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(isActive ? 0.30 : 0.14), lineWidth: 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        if runtime.mode == .edit && isDragging {
                            Circle()
                                .fill(.white.opacity(0.85))
                                .frame(width: 8, height: 8)
                                .padding(7)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if runtime.mode == .edit && isDragging {
                            Circle()
                                .fill(.white.opacity(0.85))
                                .frame(width: 8, height: 8)
                                .padding(7)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if runtime.mode == .edit && isDragging {
                            Circle()
                                .fill(.white.opacity(0.85))
                                .frame(width: 8, height: 8)
                                .padding(7)
                        }
                    }
                    .shadow(color: .black.opacity(isDragging ? 0.28 : 0.08), radius: isDragging ? 24 : 10, y: isDragging ? 12 : 4)
                    .scaleEffect(isDragging ? 1.015 : 1.0)
                    .offset(
                        x: CGFloat(block.frame.origin.x) * cellWidth + 4,
                        y: CGFloat(block.frame.origin.y) * cellHeight + 4
                    )
                    .offset(dragging[block.id] ?? .zero)
                    .animation(.smooth(duration: 0.18), value: block.frame)
                    .animation(.smooth(duration: 0.12), value: dragging[block.id] ?? .zero)
                    .animation(.smooth(duration: 0.12), value: hoveredBlock)
                    .onHover { isHovering in
                        guard runtime.mode == .edit else { return }
                        hoveredBlock = isHovering ? block.id : (hoveredBlock == block.id ? nil : hoveredBlock)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard runtime.mode == .edit else { return }
                                dragging[block.id] = value.translation
                            }
                            .onEnded { value in
                                guard runtime.mode == .edit else { return }
                                let x = block.frame.origin.x + Int((value.translation.width / cellWidth).rounded())
                                let y = block.frame.origin.y + Int((value.translation.height / cellHeight).rounded())
                                withAnimation(.smooth(duration: 0.18)) {
                                    dragging[block.id] = .zero
                                    try? workspace.moveBlock(block.id, to: GridPoint(x: x, y: y))
                                }
                            }
                    )
                }
            }
        }
    }

    private func title(for id: BlockID) -> String {
        workspace.definitions.first(where: { $0.id == id })?.title ?? id.rawValue
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}

enum SurfaceMode {
    case edit
    case use
}

enum OverlayCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    func origin(in container: CGSize, size: CGSize, margin: CGFloat) -> CGPoint {
        switch self {
        case .topLeft:
            CGPoint(x: margin, y: margin)
        case .topRight:
            CGPoint(x: container.width - size.width - margin, y: margin)
        case .bottomLeft:
            CGPoint(x: margin, y: container.height - size.height - margin)
        case .bottomRight:
            CGPoint(x: container.width - size.width - margin, y: container.height - size.height - margin)
        }
    }

    static func nearest(to point: CGPoint, in container: CGSize) -> OverlayCorner {
        switch (point.x >= container.width / 2, point.y >= container.height / 2) {
        case (false, false):
            .topLeft
        case (true, false):
            .topRight
        case (false, true):
            .bottomLeft
        case (true, true):
            .bottomRight
        }
    }
}

enum DemoSurface {
    static let workspace: Workspace = {
        let definitions = [
            BlockDefinition(id: "command", title: "Command", defaultSize: GridSize(width: 16, height: 4)),
            BlockDefinition(id: "captures", title: "Captures", defaultSize: GridSize(width: 8, height: 8)),
            BlockDefinition(id: "status", title: "Status", defaultSize: GridSize(width: 8, height: 4))
        ]
        let layout = Layout(grid: Grid(columns: 24, rows: 16), blocks: [
            BlockInstance(id: "command", frame: GridFrame(x: 4, y: 1, width: 16, height: 4)),
            BlockInstance(id: "captures", frame: GridFrame(x: 1, y: 6, width: 8, height: 8)),
            BlockInstance(id: "status", frame: GridFrame(x: 15, y: 6, width: 8, height: 4))
        ])
        return try! Workspace(definitions: definitions, layout: layout)
    }()
}
