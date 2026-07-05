import AppKit
import Core
import Foundation
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "followupqueue",
        title: "Follow Ups",
        defaultSize: GridSize(width: 8, height: 5)
    ) { context in
        Runtime(context: context)
    }
}

@MainActor
final class Runtime: ObservableObject, BlockRuntime {
    @Published private(set) var status = "Ready"
    @Published private(set) var items: [FollowUpItem] = []

    private let context: Block.Context
    private let reader: FollowUpReader
    private var reloadTask: Task<Void, Never>?

    init(context: Block.Context, reader: FollowUpReader? = nil) {
        self.context = context
        self.reader = reader ?? FollowUpReader(context: context)
    }

    func start() {
        refreshNow()
    }

    func stop() {
        reloadTask?.cancel()
        reloadTask = nil
    }

    func refresh() async {
        refreshNow()
    }

    func makeView() -> AnyView {
        AnyView(FollowUpView(runtime: self))
    }

    func copy(_ item: FollowUpItem) {
        guard context.allowsExternalWrites else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.markdownSummary, forType: .string)
    }

    private func refreshNow() {
        if context.storageDirectory != nil || !context.allowsLiveProcesses {
            reload()
        } else {
            status = "Loading"
            items = []
            reloadTask?.cancel()
            let reader = reader
            reloadTask = Task.detached {
                let state = reader.state()
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    self.status = state.status
                    self.items = state.items
                }
            }
        }
    }

    private func reload() {
        let state = reader.state()
        status = state.status
        items = state.items
    }
}

struct FollowUpReader: Sendable {
    var context: Block.Context
    var command: @Sendable ([String]) throws -> String = LocalCommand.run

    func state() -> FollowUpState {
        if let storageDirectory = context.storageDirectory {
            return fixtureState(in: storageDirectory)
        }
        guard context.allowsLiveProcesses else {
            return FollowUpState(status: "Live Cued disabled", items: [])
        }
        return liveState()
    }

    private func fixtureState(in directory: URL) -> FollowUpState {
        let url = directory.appendingPathComponent("followupqueue-items.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return FollowUpState(status: "No fixture", items: [])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(FollowUpState.self, from: data)
        } catch {
            return FollowUpState(status: error.localizedDescription, items: [])
        }
    }

    private func liveState() -> FollowUpState {
        do {
            let data = try command(["cued", "sql", Self.sql]).data(using: .utf8) ?? Data()
            let rows = try JSONDecoder().decode([CuedFollowUpRow].self, from: data)
            return FollowUpState(status: rows.isEmpty ? "Clear" : "Live Cued", items: rows.map(\.item))
        } catch {
            return FollowUpState(status: "Cued unavailable", items: [])
        }
    }

    static let sql = """
    with last_messages as (
      select
        m.conversation_id,
        m.sender_name,
        m.sent_at,
        m.is_from_me,
        m.content,
        c.platform,
        c.name as conversation_name,
        c.participant_names,
        c.type,
        c.unread_count,
        row_number() over (partition by m.conversation_id order by m.sent_at desc) as rn
      from messages m
      join conversations c on c.id = m.conversation_id
      where c.type = 'dm'
    )
    select
      conversation_id,
      platform,
      coalesce(conversation_name, participant_names, sender_name) as person,
      datetime(sent_at/1000,'unixepoch','localtime') as last_message_at,
      is_from_me,
      unread_count,
      substr(coalesce(content,''),1,180) as preview
    from last_messages
    where rn = 1
      and (
        (is_from_me = 1 and sent_at < unixepoch('now','-3 days')*1000)
        or (is_from_me = 0 and unread_count > 0)
      )
    order by
      case when unread_count > 0 and is_from_me = 0 then 0 else 1 end,
      sent_at desc
    limit 12
    """
}

struct FollowUpState: Codable, Equatable, Sendable {
    var status: String
    var items: [FollowUpItem]
}

struct FollowUpItem: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var platform: String
    var person: String
    var lastMessageAt: String
    var isFromMe: Bool
    var unreadCount: Int
    var preview: String

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case platform
        case person
        case lastMessageAt = "last_message_at"
        case isFromMe = "is_from_me"
        case unreadCount = "unread_count"
        case preview
    }

    init(
        id: String,
        platform: String,
        person: String,
        lastMessageAt: String,
        isFromMe: Bool,
        unreadCount: Int,
        preview: String
    ) {
        self.id = id
        self.platform = platform
        self.person = person
        self.lastMessageAt = lastMessageAt
        self.isFromMe = isFromMe
        self.unreadCount = unreadCount
        self.preview = preview
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .conversationID)
        platform = try container.decode(String.self, forKey: .platform)
        person = try container.decode(String.self, forKey: .person)
        lastMessageAt = try container.decode(String.self, forKey: .lastMessageAt)
        if let bool = try? container.decode(Bool.self, forKey: .isFromMe) {
            isFromMe = bool
        } else {
            isFromMe = (try container.decode(Int.self, forKey: .isFromMe)) != 0
        }
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        preview = try container.decodeIfPresent(String.self, forKey: .preview) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(platform, forKey: .platform)
        try container.encode(person, forKey: .person)
        try container.encode(lastMessageAt, forKey: .lastMessageAt)
        try container.encode(isFromMe, forKey: .isFromMe)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(preview, forKey: .preview)
    }

    var kind: String {
        if unreadCount > 0 && !isFromMe {
            return "Unread"
        }
        return "Follow up"
    }

    var markdownSummary: String {
        """
        # \(person)
        - Platform: \(platform)
        - State: \(kind)
        - Last message: \(lastMessageAt)
        - Preview: \(preview)
        """
    }
}

private struct CuedFollowUpRow: Decodable {
    var conversation_id: String
    var platform: String
    var person: String
    var last_message_at: String
    var is_from_me: Int
    var unread_count: Int
    var preview: String

    var item: FollowUpItem {
        FollowUpItem(
            id: conversation_id,
            platform: platform,
            person: person,
            lastMessageAt: last_message_at,
            isFromMe: is_from_me != 0,
            unreadCount: unread_count,
            preview: preview
        )
    }
}

private struct FollowUpView: View {
    @ObservedObject var runtime: Runtime

    private var unreadCount: Int {
        runtime.items.filter { !$0.isFromMe && $0.unreadCount > 0 }.count
    }

    private var waitingCount: Int {
        runtime.items.count - unreadCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if runtime.items.isEmpty {
                Text("No follow-ups right now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        ForEach(runtime.items.prefix(8)) { item in
                            itemRow(item)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            pill(runtime.status)
            Text("\(unreadCount) unread")
                .font(.caption2.weight(.medium))
                .foregroundStyle(unreadCount > 0 ? .red : .secondary)
            Text("\(waitingCount) waiting")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
        }
    }

    private func itemRow(_ item: FollowUpItem) -> some View {
        Button {
            runtime.copy(item)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(item.kind == "Unread" ? Color.red : Color.orange)
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.person)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(item.kind)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(item.preview.isEmpty ? item.lastMessageAt : item.preview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy follow-up summary")
        .overlay(alignment: .bottom) {
            Rectangle().fill(.primary.opacity(0.08)).frame(height: 1)
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(.primary.opacity(0.055), in: Capsule())
    }
}
