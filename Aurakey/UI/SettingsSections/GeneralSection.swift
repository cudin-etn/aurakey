//
//  GeneralSection.swift
//  Aurakey
//
//  Shared General Settings Section
//

import SwiftUI

struct GeneralSection: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup(title: "Phím tắt & hành vi", color: AurakeyTheme.accent) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Bật/tắt tiếng Việt")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        HotkeyRecorderView(hotkey: $viewModel.preferences.toggleHotkey)
                            .frame(width: 160)
                    }

                    if viewModel.preferences.toggleHotkey.modifiers.contains(.function) ||
                       (viewModel.preferences.toggleHotkey.modifiers == [.control] && viewModel.preferences.toggleHotkey.keyCode == 49) {
                        SettingsInfoBox(
                            "Phím tắt này có thể trùng với macOS. Nếu bị conflict, hãy tắt shortcut chuyển input source trong Keyboard Shortcuts.",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange
                        )
                    }

                    Toggle("Phát âm thanh khi bật/tắt", isOn: $viewModel.preferences.beepOnToggle)
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Hoàn tác gõ tiếng Việt", isOn: $viewModel.preferences.undoTypingEnabled)

                        if viewModel.preferences.undoTypingEnabled {
                            HStack(alignment: .center, spacing: 12) {
                                Text("Phím tắt hoàn tác")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                HotkeyRecorderView(
                                    hotkey: Binding(
                                        get: {
                                            viewModel.preferences.undoTypingHotkey ?? Hotkey(keyCode: VietnameseData.KEY_ESC, modifiers: [], isModifierOnly: false)
                                        },
                                        set: { newValue in
                                            if newValue.keyCode == VietnameseData.KEY_ESC && newValue.modifiers.isEmpty && !newValue.isModifierOnly {
                                                viewModel.preferences.undoTypingHotkey = nil
                                            } else {
                                                viewModel.preferences.undoTypingHotkey = newValue
                                            }
                                        }
                                    )
                                )
                                .frame(width: 160)
                            }
                            SettingsCaption("Mặc định là Esc. Có thể dùng tổ hợp modifier nếu muốn.")
                        }

                        SettingsCaption("Nhấn phím tắt ngay sau khi gõ để hoàn tác việc bỏ dấu.")
                    }
                }
            }

            SettingsGroup(title: "Kiểu gõ", color: AurakeyTheme.accentWarm) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(InputMethod.allCases, id: \.self) { method in
                        SettingsRadioButton(
                            title: method.displayName,
                            isSelected: viewModel.preferences.inputMethod == method,
                            color: AurakeyTheme.accentWarm
                        ) {
                            viewModel.preferences.inputMethod = method
                        }
                    }
                }
            }

            SettingsGroup(title: "Bảng mã", color: AurakeyTheme.accent) {
                let supportedCodeTables = CodeTable.allCases.filter { table in
                    table != .unicodeCompound && table != .vietnameseLocaleCP1258
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                    ForEach(supportedCodeTables, id: \.self) { table in
                        SettingsRadioButton(
                            title: table.displayName,
                            isSelected: viewModel.preferences.codeTable == table
                        ) {
                            viewModel.preferences.codeTable = table
                        }
                    }
                }
            }

            SettingsGroup(title: "Tùy chọn", color: AurakeyTheme.accentSoft) {
                Toggle("Kiểu gõ hiện đại (oà/uý)", isOn: $viewModel.preferences.modernStyle)
            }
        }
    }
}
