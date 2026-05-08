//
//  SharedComponents.swift
//  Aurakey
//
//  Premium UI Components for Settings
//

import SwiftUI

// MARK: - Accent Colors (shared across all settings)

struct AurakeyTheme {
    static let accentTeal = Color(red: 0.0, green: 0.75, blue: 0.78)
    static let accentCyan = Color(red: 0.15, green: 0.85, blue: 0.88)
    
    static let gradient = LinearGradient(
        colors: [accentTeal, accentCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Card gradient factory — parameterized by accent color
    static func cardGradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.04), color.opacity(0.015), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static func borderGradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.25), color.opacity(0.15), color.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static func headerGradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Settings Group (Card with per-section color)

struct SettingsGroup<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: Content
    
    init(title: String, color: Color = AurakeyTheme.accentTeal, @ViewBuilder content: () -> Content) {
        self.title = title
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with accent bar
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AurakeyTheme.headerGradient(for: color))
                    .frame(width: 3, height: 16)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            // Content card with color-matched gradient
            content
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AurakeyTheme.cardGradient(for: color))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AurakeyTheme.borderGradient(for: color), lineWidth: 1)
                )
        }
    }
}

// MARK: - Settings Radio Button

struct SettingsRadioButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    init(title: String, isSelected: Bool, color: Color = AurakeyTheme.accentTeal, action: @escaping () -> Void) {
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
                        .strokeBorder(isSelected ? color : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    
                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isSelected)
                
                Text(title)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? color.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Settings Section Header

struct SettingsSectionHeader: View {
    let title: String
    let icon: String?
    let color: Color
    
    init(_ title: String, icon: String? = nil, color: Color = AurakeyTheme.accentTeal) {
        self.title = title
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Info Box

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
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(color.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Caption Text

struct SettingsCaption: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(.secondary)
    }
}

// MARK: - Mapping Pill Badge

struct MappingPill: View {
    let text: String
    let color: Color
    
    init(text: String, color: Color = .orange) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                    )
            )
    }
}
