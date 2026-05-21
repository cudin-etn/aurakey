//
//  AppearanceSection.swift
//  Aurakey
//

import SwiftUI

struct AppearanceSection: View {
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup(title: "Thanh menu", color: .indigo) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Biểu tượng menubar:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                            SettingsRadioButton(
                                title: style.displayName,
                                isSelected: viewModel.preferences.menuBarIconStyle == style
                            ) {
                                viewModel.preferences.menuBarIconStyle = style
                            }
                        }
                    }
                    .padding(.leading, 8)
                }
            }

            SettingsGroup(title: "Cursor Mode HUD", color: AurakeyTheme.accent) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Hiện huy hiệu V/E bên cạnh con trỏ khi đổi ngôn ngữ", isOn: $viewModel.preferences.cursorHUDEnabled)

                    Text("HUD kính mờ trượt lên cạnh con trỏ: \"V\" ngọc bích (Tiếng Việt) hoặc \"E\" xám (Tiếng Anh), tự ẩn sau 1.2 giây.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            SettingsGroup(title: "Khởi động & cập nhật", color: .indigo) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Khởi động cùng hệ thống", isOn: $viewModel.preferences.startAtLogin)

                    Toggle("Tự động kiểm tra cập nhật", isOn: $viewModel.preferences.autoCheckForUpdates)
                }
            }
        }
    }
}
