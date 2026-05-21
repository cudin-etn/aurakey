//
//  CursorHUDView.swift
//  Aurakey
//
//  Minimal premium status card for VI/EN toggle.
//

import SwiftUI

struct CursorHUDView: View {
    @Environment(\.colorScheme) private var colorScheme

    let isVietnamese: Bool

    private let cardSize = CGSize(width: 120, height: 120)
    private let cornerRadius: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(baseGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tintOverlay)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderGradient, lineWidth: 1.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.black.opacity(colorScheme == .dark ? 0.45 : 0.16), lineWidth: 0.5)
                        .blur(radius: 0.2)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.50 : 0.22), radius: 22, x: 0, y: 12)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 6, x: 0, y: 2)

            Text(isVietnamese ? "V" : "E")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(symbolColor)
                .shadow(color: symbolShadow, radius: 10, x: 0, y: 4)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .compositingGroup()
    }

    private var baseGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(white: 0.18), Color(white: 0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        // Light mode: intentionally not white, to avoid blending into bright apps.
        return LinearGradient(
            colors: [Color(red: 0.84, green: 0.86, blue: 0.90), Color(red: 0.74, green: 0.77, blue: 0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var tintOverlay: LinearGradient {
        let tintTop = isVietnamese ? Color.teal.opacity(0.16) : Color.black.opacity(colorScheme == .dark ? 0.10 : 0.05)
        let tintBottom = isVietnamese ? Color.green.opacity(0.10) : Color.black.opacity(colorScheme == .dark ? 0.16 : 0.08)

        return LinearGradient(
            colors: [tintTop, tintBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.24), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white.opacity(0.45), Color.black.opacity(0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var symbolColor: Color {
        if isVietnamese {
            return colorScheme == .dark
                ? Color(red: 0.48, green: 0.95, blue: 0.86)
                : Color(red: 0.06, green: 0.47, blue: 0.42)
        }

        return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.80)
    }

    private var symbolShadow: Color {
        if isVietnamese {
            return Color.teal.opacity(colorScheme == .dark ? 0.34 : 0.20)
        }
        return Color.black.opacity(colorScheme == .dark ? 0.26 : 0.14)
    }
}
