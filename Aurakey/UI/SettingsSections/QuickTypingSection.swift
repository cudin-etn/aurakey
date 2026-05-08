//
//  QuickTypingSection.swift
//  Aurakey
//
//  Quick Typing Settings with pill badge layout
//

import SwiftUI

struct QuickTypingSection: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Quick Telex
                SettingsGroup(title: "Quick Telex", color: .orange) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Bật Quick Telex", isOn: $viewModel.preferences.quickTelexEnabled)
                        
                        // Mapping pills
                        WrappingHStack {
                            MappingPill(text: "cc→ch")
                            MappingPill(text: "gg→gi")
                            MappingPill(text: "kk→kh")
                            MappingPill(text: "nn→ng")
                            MappingPill(text: "pp→ph")
                            MappingPill(text: "qq→qu")
                            MappingPill(text: "tt→th")
                        }
                    }
                }
                
                // Quick consonants side by side
                HStack(alignment: .top, spacing: 16) {
                    // Start consonant
                    SettingsGroup(title: "Quick Consonant — Đầu từ", color: .orange) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Bật", isOn: $viewModel.preferences.quickStartConsonantEnabled)
                            
                            WrappingHStack {
                                MappingPill(text: "f→ph")
                                MappingPill(text: "j→gi")
                                MappingPill(text: "w→qu")
                            }
                        }
                    }
                    
                    // End consonant
                    SettingsGroup(title: "Quick Consonant — Cuối từ", color: .orange) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Bật", isOn: $viewModel.preferences.quickEndConsonantEnabled)
                            
                            WrappingHStack {
                                MappingPill(text: "g→ng")
                                MappingPill(text: "h→nh")
                                MappingPill(text: "k→ch")
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

// MARK: - Wrapping HStack (macOS 12 compatible)

/// Simple wrapping horizontal layout using GeometryReader
struct WrappingHStack: View {
    let content: [AnyView]
    let spacing: CGFloat
    
    init<Data: RandomAccessCollection, Content: View>(
        spacing: CGFloat = 6,
        @ViewBuilder content: () -> ForEach<Data, Data.Element.ID, Content>
    ) where Data.Element: Identifiable {
        self.spacing = spacing
        let forEach = content()
        self.content = forEach.data.map { AnyView(forEach.content($0)) }
    }
    
    init(spacing: CGFloat = 6, @ViewBuilder content: () -> TupleView<some Any>) {
        self.spacing = spacing
        // Mirror to extract children from TupleView
        let tuple = content()
        let mirror = Mirror(reflecting: tuple.value)
        self.content = mirror.children.compactMap { child in
            (child.value as? any View).map { AnyView($0) }
        }
    }
    
    var body: some View {
        // Use simple HStack with wrapping via LazyVGrid
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 120), spacing: spacing)], alignment: .leading, spacing: spacing) {
            ForEach(content.indices, id: \.self) { index in
                content[index]
            }
        }
    }
}
