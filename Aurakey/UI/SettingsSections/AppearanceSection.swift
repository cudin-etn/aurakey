//
//  AppearanceSection.swift
//  Aurakey
//
//  Appearance Settings — Menubar icon + startup
//

import SwiftUI

struct AppearanceSection: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsGroup(title: "Thanh menu", color: .indigo) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Biểu tượng menubar:")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
