//
//  WindowTitleRulesSection.swift
//  Aurakey
//

import SwiftUI

struct WindowTitleRulesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tuỳ chỉnh cách Aurakey gửi ký tự và nhận diện từng ứng dụng hoặc trang web.")
                .font(.caption)
                .foregroundColor(.secondary)

            if #available(macOS 13.0, *) {
                WindowTitleRulesView()
            } else {
                Text("Tính năng này yêu cầu macOS 13.0 trở lên")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
