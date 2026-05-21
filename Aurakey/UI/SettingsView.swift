import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "Cơ bản"
    case advanced = "Nâng cao"
    case windowTitleRules = "Hiệu chỉnh app"
    case macro = "Macro"
    case convertTool = "Chuyển đổi"
    case excludedApps = "Ứng dụng"
    case inputSources = "Nguồn nhập"
    case appearance = "Giao diện"
    case backupRestore = "Sao lưu"
    case about = "Giới thiệu"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .advanced: return "slider.horizontal.3"
        case .windowTitleRules: return "gearshape.2"
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
        case .general: return AurakeyTheme.accent
        case .advanced: return .purple
        case .windowTitleRules: return .purple
        case .macro: return .pink
        case .convertTool: return AurakeyTheme.accentWarm
        case .excludedApps: return .red
        case .inputSources: return .green
        case .appearance: return .indigo
        case .backupRestore: return .cyan
        case .about: return .mint
        }
    }

    var description: String {
        switch self {
        case .general: return "Cấu hình phím tắt, kiểu gõ và bảng mã"
        case .advanced: return "Chính tả, từ điển và công cụ điều khiển"
        case .windowTitleRules: return "Tuỳ chỉnh engine theo từng ứng dụng"
        case .macro: return "Tạo và quản lý từ viết tắt"
        case .convertTool: return "Chuyển đổi chữ hoa/thường và bảng mã"
        case .excludedApps: return "Quản lý Smart Switch và ứng dụng loại trừ"
        case .inputSources: return "Cấu hình theo Input Source"
        case .appearance: return "Giao diện, biểu tượng và khởi động"
        case .backupRestore: return "Sao lưu, khôi phục và đặt lại"
        case .about: return "Thông tin ứng dụng và liên kết"
        }
    }
}

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
            sidebar
                .frame(width: 220)

            Divider()
                .opacity(0)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 560)
        .background(AurakeyTheme.panelBackground)
        .onReceive(viewModel.objectWillChange) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.save()
                onSave?(viewModel.preferences)
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(SettingsSection.allCases) { section in
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
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(AurakeyTheme.sidebarBackground)
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            if let logo = NSImage(named: "AurakeyLogo") {
                Image(nsImage: logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Aurakey")
                    .font(.system(size: 14, weight: .bold))
                Text("Cài đặt")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedSection.rawValue)
                        .font(.system(size: 22, weight: .bold))
                    Text(selectedSection.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Group {
                    switch selectedSection {
                    case .general:
                        GeneralSection(viewModel: viewModel)
                    case .advanced:
                        AdvancedSection(viewModel: viewModel)
                    case .windowTitleRules:
                        WindowTitleRulesSection()
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
            }
            .padding(32)
        }
    }
}

