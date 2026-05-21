//
//  InputSourcesSection.swift
//  Aurakey
//
//  Shared Input Sources Settings Section
//

import SwiftUI

struct InputSourcesSection: View {
    @ObservedObject var preferencesViewModel: PreferencesViewModel
    @StateObject private var viewModel = InputSourcesViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
                // Header with explanation
                SettingsGroup(title: "Quản lý Input Sources", color: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aurakey có thể tự động bật/tắt tính năng thêm dấu tiếng Việt dựa trên Input Source hiện tại của hệ điều hành.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Divider()

                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Input Source hiện tại:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(viewModel.currentInputSource?.displayName ?? "Không xác định")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            Button("Làm mới") {
                                viewModel.refresh()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }


                // Input Sources List
                SettingsGroup(title: "Cấu hình theo Input Source", color: .green) {
                    VStack(alignment: .leading, spacing: 8) {
                        if viewModel.inputSources.isEmpty {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Đang tải danh sách Input Sources...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            VStack(spacing: 8) {
                                ForEach(viewModel.inputSources) { source in
                                    InputSourceRowView(
                                        source: source,
                                        isEnabled: viewModel.isEnabled(for: source.id),
                                        isCurrent: viewModel.currentInputSource?.id == source.id
                                    ) { enabled in
                                        viewModel.setEnabled(enabled, for: source.id)
                                    }
                                }
                            }
                        }

                        Divider()
                            .padding(.top, 8)

                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Bật = Aurakey sẽ tự động thêm dấu tiếng Việt khi Input Source này được chọn")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Vietnamese Input Sources Detection
                if !viewModel.vietnameseInputSources.isEmpty {
                    SettingsGroup(title: "Input Sources tiếng Việt đã phát hiện", color: .green) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.vietnameseInputSources) { source in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.displayName)
                                            .font(.body)
                                        Text(source.id)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }

                            Divider()

                            Text("💡 Với các Input Source tiếng Việt khác (Telex, VNI...), bạn có thể tắt Aurakey để tránh xung đột.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        .onAppear {
            viewModel.loadInputSources()
        }
    }
}

// MARK: - Input Source Row View

struct InputSourceRowView: View {
    let source: InputSourceInfo
    let isEnabled: Bool
    let isCurrent: Bool
    let onToggle: (Bool) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Current indicator
            Circle()
                .fill(isCurrent ? Color.green : Color.clear)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            // Source info
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(source.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isCurrent ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Input Sources ViewModel

class InputSourcesViewModel: ObservableObject {
    @Published var inputSources: [InputSourceInfo] = []
    @Published var currentInputSource: InputSourceInfo?

    private var manager: InputSourceManager?
    private var notificationObserver: Any?

    init() {
        // Use shared singleton - same instance as AppDelegate
        manager = InputSourceManager.shared

        // Listen for input source changes
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .inputSourceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Auto-refresh when input source changes
            self?.refresh()
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var vietnameseInputSources: [InputSourceInfo] {
        inputSources.filter { InputSourceManager.isVietnameseInputSource($0) }
    }

    func loadInputSources() {
        inputSources = InputSourceManager.getAllInputSources()
        currentInputSource = InputSourceManager.getCurrentInputSource()
    }

    func refresh() {
        loadInputSources()
    }

    func isEnabled(for inputSourceID: String) -> Bool {
        return manager?.isEnabled(for: inputSourceID) ?? true
    }

    func setEnabled(_ enabled: Bool, for inputSourceID: String) {
        manager?.setEnabled(enabled, for: inputSourceID)
        objectWillChange.send()
    }
}
