import SwiftUI

// MARK: - Premium Glass Design Menu Bar Popover

struct StatusBarPopoverView: View {
    @ObservedObject var viewModel: StatusBarViewModel
    var onCheckForUpdates: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var isInputMethodExpanded = false
    @State private var isCodeTableExpanded = false
    @State private var toggleScale: CGFloat = 1.0

    // Filtered code tables (exclude experimental)
    private var supportedCodeTables: [CodeTable] {
        CodeTable.allCases.filter { $0 != .unicodeCompound && $0 != .vietnameseLocaleCP1258 }
    }

    // MARK: - Accent Colors
    private let accentTeal = Color(red: 0.0, green: 0.75, blue: 0.78)
    private let accentCyan = Color(red: 0.15, green: 0.85, blue: 0.88)

    var body: some View {
        VStack(spacing: 0) {
            // Hero header
            headerSection

            // Content
            VStack(spacing: 2) {
                inputMethodSection
                codeTableSection

                thinDivider
                    .padding(.vertical, 4)

                toolsSection

                thinDivider
                    .padding(.vertical, 4)

                footerSection
            }
            .padding(.bottom, 8)
        }
        .frame(width: 280)
        .background(VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow))
    }

    // MARK: - Hero Header
    private var headerSection: some View {
        VStack(spacing: 10) {
            // Status icon with glow
            ZStack {
                // Glow
                Circle()
                    .fill(
                        viewModel.isVietnameseEnabled
                            ? accentTeal.opacity(0.25)
                            : Color.gray.opacity(0.15)
                    )
                    .frame(width: 52, height: 52)
                    .blur(radius: 8)

                // Icon circle
                Circle()
                    .fill(
                        viewModel.isVietnameseEnabled
                            ? LinearGradient(colors: [accentTeal, accentCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: viewModel.isVietnameseEnabled ? accentTeal.opacity(0.3) : .clear, radius: 6, y: 2)

                Text(viewModel.isVietnameseEnabled ? "V" : "E")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .scaleEffect(toggleScale)

            // Toggle pill
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    toggleScale = 0.9
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.toggleVietnamese()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        toggleScale = 1.0
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isVietnameseEnabled ? accentTeal : Color.gray.opacity(0.5))
                        .frame(width: 7, height: 7)
                    Text(viewModel.isVietnameseEnabled ? "Tiếng Việt" : "Tiếng Anh")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    viewModel.isVietnameseEnabled ? accentTeal.opacity(0.3) : Color.gray.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)

            // Hotkey hint
            Text(viewModel.hotkeyDisplay)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 2)
        }
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input Method Section
    private var inputMethodSection: some View {
        VStack(spacing: 0) {
            compactSectionButton(
                label: "Kiểu gõ",
                value: viewModel.currentInputMethod.displayName,
                isExpanded: isInputMethodExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isInputMethodExpanded.toggle()
                    if isInputMethodExpanded { isCodeTableExpanded = false }
                }
            }

            if isInputMethodExpanded {
                VStack(spacing: 1) {
                    ForEach(InputMethod.allCases, id: \.self) { method in
                        PopoverMenuRow(
                            title: method.displayName,
                            isSelected: method == viewModel.currentInputMethod,
                            accentColor: accentTeal
                        ) {
                            viewModel.selectInputMethod(method)
                        }
                    }
                }
                .popoverCard()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Code Table Section
    private var codeTableSection: some View {
        VStack(spacing: 0) {
            compactSectionButton(
                label: "Bảng mã",
                value: viewModel.currentCodeTable.displayName,
                isExpanded: isCodeTableExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCodeTableExpanded.toggle()
                    if isCodeTableExpanded { isInputMethodExpanded = false }
                }
            }

            if isCodeTableExpanded {
                VStack(spacing: 1) {
                    ForEach(supportedCodeTables, id: \.self) { table in
                        PopoverMenuRow(
                            title: table.displayName,
                            isSelected: table == viewModel.currentCodeTable,
                            accentColor: accentTeal
                        ) {
                            viewModel.selectCodeTable(table)
                        }
                    }
                }
                .popoverCard()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Tools Section
    private var toolsSection: some View {
        VStack(spacing: 1) {
            PopoverActionRow(title: "Macro", icon: "text.badge.plus", accentColor: accentTeal) {
                onDismiss?()
                viewModel.openMacroManagement()
            }
            PopoverActionRow(title: "Chuyển đổi", icon: "arrow.left.arrow.right", accentColor: accentTeal) {
                onDismiss?()
                viewModel.openConvertTool()
            }
        }
        .popoverCard()
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 1) {
            PopoverActionRow(title: "Cập nhật", icon: "arrow.triangle.2.circlepath", accentColor: accentTeal) {
                onDismiss?()
                onCheckForUpdates?()
            }
            PopoverActionRow(title: "Bảng điều khiển", icon: "gearshape", shortcut: "⌘,", accentColor: accentTeal) {
                onDismiss?()
                viewModel.openPreferences()
            }

            thinDivider
                .padding(.horizontal, 6)
                .padding(.vertical, 2)

            PopoverActionRow(title: "Thoát", icon: "power", shortcut: "⌘Q", accentColor: Color.red.opacity(0.8)) {
                viewModel.quit()
            }
        }
        .popoverCard()
    }

    // MARK: - Compact Section Button
    private func compactSectionButton(label: String, value: String, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(value)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 5)
    }

    // MARK: - Thin Divider
    private var thinDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }
}

// MARK: - Popover Card Modifier

private struct PopoverCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
            )
            .padding(.horizontal, 8)
    }
}

private extension View {
    func popoverCard() -> some View {
        self.modifier(PopoverCardModifier())
    }
}

// MARK: - Menu Row (selectable with checkmark)

private struct PopoverMenuRow: View {
    let title: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark" : "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Action Row (clickable row with icon)

private struct PopoverActionRow: View {
    let title: String
    let icon: String
    var shortcut: String? = nil
    let accentColor: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isHovered ? .white.opacity(0.9) : accentColor.opacity(0.7))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(isHovered ? .white : .primary)
                Spacer()
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(isHovered ? .white.opacity(0.6) : .secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - NSVisualEffectView Hosting (Glass Background)

/// NSViewRepresentable wrapping NSVisualEffectView for glass/vibrancy effect
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
