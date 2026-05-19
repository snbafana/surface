import SwiftUI

public enum SurfaceStyle {
    public static let previewBackground = Color(red: 0.08, green: 0.10, blue: 0.12)
    public static let cardBackground = Color(red: 0.07, green: 0.10, blue: 0.12).opacity(0.90)
    public static let panelBackground = Color(red: 0.06, green: 0.08, blue: 0.10).opacity(0.92)
    public static let fieldBackground = Color.white.opacity(0.10)
    public static let rowBackground = Color.white.opacity(0.08)
    public static let primaryText = Color.white
    public static let secondaryText = Color.white.opacity(0.72)
    public static let tertiaryText = Color.white.opacity(0.50)
    public static let border = Color.white.opacity(0.18)
    public static let activeBorder = Color.white.opacity(0.34)
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
                .foregroundStyle(SurfaceStyle.primaryText)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SurfaceStyle.secondaryText)
                    .lineLimit(1)
            }

            content
                .foregroundStyle(SurfaceStyle.primaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SurfaceStyle.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? SurfaceStyle.activeBorder : SurfaceStyle.border, lineWidth: 1)
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
            .foregroundStyle(SurfaceStyle.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
