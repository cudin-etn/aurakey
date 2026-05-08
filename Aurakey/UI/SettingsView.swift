//
//  SettingsView.swift
//  Aurakey
//
//  Unified Settings View with custom premium sidebar
//  Supports macOS 13+ (uses same sidebar as PreferencesView)
//  Uses shared components from SettingsSections/
//

import SwiftUI

// MARK: - Settings Section

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "Cơ bản"
    case quickTyping = "Gõ nhanh"
    case advanced = "Nâng cao"
    case macro = "Macro"
    case convertTool = "Chuyển đổi"
    case excludedApps = "Ứng dụng"
    case inputSources = "Input Sources"
    case appearance = "Giao diện"
    case backupRestore = "Sao lưu"
    case about = "Giới thiệu"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .quickTyping: return "keyboard"
        case .advanced: return "slider.horizontal.3"
        case .inputSources: return "globe"
        case .excludedApps: return "app.badge.checkmark"
        case .macro: return "text.badge.plus"
        case .convertTool: return "arrow.left.arrow.right"
        case .appearance: return "paintbrush"
        case .backupRestore: return "arrow.up.arrow.down.circle"
        case .about: return "info.circle"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .general: return .blue
        case .quickTyping: return .orange
        case .advanced: return .purple
        case .macro: return .pink
        case .convertTool: return Color(red: 0, green: 0.75, blue: 0.78)
        case .excludedApps: return .red
        case .inputSources: return .green
        case .appearance: return .indigo
        case .backupRestore: return .cyan
        case .about: return .mint
        }
    }
    
    var groupLabel: String? {
        switch self {
        case .general: return "THIẾT LẬP"
        case .macro: return "CÔNG CỤ"
        case .inputSources: return "HỆ THỐNG"
        default: return nil
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @State private var selectedSection: SettingsSection

    var onSave: ((Preferences) -> Void)?

    init(selectedSection: SettingsSection = .general, onSave: ((Preferences) -> Void)? = nil) {
        self._selectedSection = State(initialValue: selectedSection)
        self.onSave = onSave
    }

    var body: some View {
        HStack(spacing: 0) {
            // Custom premium sidebar (same style as PreferencesView)
            VStack(spacing: 0) {
                // App branding
                HStack(spacing: 8) {
                    if let logo = NSImage(named: "AurakeyLogo") {
                        Image(nsImage: logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                    Text("Aurakey")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Sections
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(SettingsSection.allCases) { section in
                            if let group = section.groupLabel {
                                Text(group)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.top, section == .general ? 0 : 14)
                                    .padding(.bottom, 4)
                            }
                            
                            SettingsSidebarButton(
                                title: section.rawValue,
                                icon: section.icon,
                                iconColor: section.iconColor,
                                isSelected: selectedSection == section
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedSection = section
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 12)
                }
            }
            .frame(width: 170)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 1)

            // Content
            Group {
                switch selectedSection {
                case .general:
                    GeneralSection(viewModel: viewModel)
                case .quickTyping:
                    QuickTypingSection(viewModel: viewModel)
                case .advanced:
                    AdvancedSection(viewModel: viewModel)
                case .inputSources:
                    InputSourcesSection(preferencesViewModel: viewModel)
                case .excludedApps:
                    ExcludedAppsSection(viewModel: viewModel)
                case .macro:
                    MacroSection(prefsViewModel: viewModel)
                case .convertTool:
                    ConvertToolSection()
                case .appearance:
                    AppearanceSection(viewModel: viewModel)
                case .backupRestore:
                    BackupRestoreSection()
                case .about:
                    AboutSection()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 780, minHeight: 580)
        .onReceive(viewModel.objectWillChange) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.save()
                onSave?(viewModel.preferences)
            }
        }
    }
}

// MARK: - Sidebar Button (shared style)

private struct SettingsSidebarButton: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? iconColor : Color.clear)
                    .frame(width: 3, height: 16)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? iconColor : (isHovered ? iconColor.opacity(0.8) : iconColor.opacity(0.6)))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .primary : .primary.opacity(0.75))

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.trailing, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        isSelected
                            ? iconColor.opacity(0.12)
                            : (isHovered ? iconColor.opacity(0.06) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
