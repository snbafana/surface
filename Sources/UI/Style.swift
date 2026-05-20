import AppKit
import SwiftUI

public enum Style {
    public static let previewBackground = Color(nsColor: .windowBackgroundColor)
    public static let cardMaterial = Material.ultraThinMaterial
    public static let panelMaterial = Material.ultraThinMaterial
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
    public static let border = Color.primary.opacity(0.14)
    public static let activeBorder = Color.accentColor.opacity(0.45)
}

public struct BlockChrome<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let isActive: Bool
    private let content: Content

    public init(
        title: String,
        subtitle: String? = nil,
        isActive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isActive = isActive
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Style.primaryText)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Style.secondaryText)
                    .lineLimit(1)
            }

            content
                .foregroundStyle(Style.primaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Style.cardMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Style.activeBorder : Style.border, lineWidth: 1)
        }
    }
}

public struct PlaceholderBlockView: View {
    public var text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Style.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
