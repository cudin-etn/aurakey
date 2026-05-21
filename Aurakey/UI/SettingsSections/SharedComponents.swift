import SwiftUI

struct AurakeyTheme {
    static let accent = Color(red: 0.0, green: 0.65, blue: 0.72)
    static let accentTeal = Color(red: 0.0, green: 0.75, blue: 0.78)
    static let accentSoft = Color(red: 0.2, green: 0.75, blue: 0.85)
    static let accentWarm = Color(red: 0.95, green: 0.56, blue: 0.18)
    static let gradient = LinearGradient(colors: [accent, accentSoft], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let sidebarBackground = Color(nsColor: .windowBackgroundColor)
    static let panelBackground = Color(nsColor: .controlBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)

    static func sectionGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.1), color.opacity(0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: Content

    init(title: String, color: Color = AurakeyTheme.accent, @ViewBuilder content: () -> Content) {
        self.title = title
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            content
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AurakeyTheme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

struct SettingsCaption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundColor(.secondary)
    }
}

struct SettingsInfoBox: View {
    let text: String
    let icon: String
    let color: Color

    init(_ text: String, icon: String = "info.circle", color: Color = .blue) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color.opacity(0.12), lineWidth: 1)
        )
    }
}

struct MappingPill: View {
    let text: String
    let color: Color

    init(text: String, color: Color = .orange) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.16), lineWidth: 1)
            )
    }
}

struct SettingsRadioButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    init(title: String, isSelected: Bool, color: Color = AurakeyTheme.accent, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? color : Color.secondary.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? color.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SettingsSidebarButton: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 26, height: 26)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? iconColor : .secondary)
                        .frame(width: 26, height: 26)
                }

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)

                Spacer()

                if isSelected {
                    Capsule()
                        .fill(iconColor)
                        .frame(width: 3, height: 16)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? iconColor.opacity(0.08) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
