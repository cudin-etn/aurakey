//
//  AboutSection.swift
//  Aurakey
//
//  Premium About Section — tdev.studio branding
//

import SwiftUI

struct AboutSection: View {
    @State private var showDonationDialog = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
                // Hero area
                VStack(spacing: 14) {
                    // App Logo with entrance animation
                    Group {
                        if let logo = NSImage(named: "AurakeyLogo") {
                            Image(nsImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 72, height: 72)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(AurakeyTheme.gradient)
                                    .frame(width: 72, height: 72)
                                Image(systemName: "keyboard.badge.ellipsis")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            logoScale = 1.0
                            logoOpacity = 1.0
                        }
                    }
                    
                    // App Name
                    VStack(spacing: 4) {
                        Text("Aurakey")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Phương thức nhập liệu tiếng Việt cho macOS")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    // Version badge
                    Text("\(AppVersion.fullVersion)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(AurakeyTheme.accentTeal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AurakeyTheme.accentTeal.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(AurakeyTheme.accentTeal.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                }
                .padding(.top, 24)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
                
                // Cards
                VStack(spacing: 14) {
                    // Developer card
                    AboutCard {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AurakeyTheme.accentTeal)
                                Text("TDEV.STUDIO")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            Text("Code chill · Build app đa nền tảng · Thiết kế web")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Links grid — 3 columns
                    HStack(spacing: 10) {
                        AboutLinkCard(
                            title: "GitHub",
                            icon: "chevron.left.forwardslash.chevron.right",
                            customIcon: "GitHubIcon",
                            color: .purple
                        ) {
                            if let url = URL(string: "https://github.com/cudin-etn/") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        
                        AboutLinkCard(
                            title: "Telegram",
                            icon: "paperplane.fill",
                            customIcon: nil,
                            color: .blue
                        ) {
                            if let url = URL(string: "https://t.me/HaQuangTung") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        
                        AboutLinkCard(
                            title: "Website",
                            icon: "globe",
                            customIcon: nil,
                            color: .green
                        ) {
                            if let url = URL(string: "https://tdev.site") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                    
                    // Donate + Bug report row
                    HStack(spacing: 10) {
                        // Donate card
                        AboutCard {
                            Button(action: {
                                showDonationDialog = true
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.orange)
                                    Text("Ủng hộ")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("Mua tôi một ly cà phê")
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Bug report card
                        AboutCard {
                            Button(action: {
                                if let url = URL(string: "https://github.com/cudin-etn/aurakey/issues/new/choose") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "ladybug.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.red)
                                    Text("Báo lỗi")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("Báo cáo lỗi")
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Update card
                    AboutCard {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 16))
                                .foregroundColor(AurakeyTheme.accentTeal)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Kiểm tra phiên bản mới")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if let settingsWindow = NSApp.keyWindow {
                                    settingsWindow.level = .normal
                                }
                                if let appDelegate = AppDelegate.shared {
                                    appDelegate.checkForUpdatesFromUI()
                                } else if let delegate = NSApplication.shared.delegate as? AppDelegate {
                                    delegate.checkForUpdatesFromUI()
                                }
                            }) {
                                Text("Kiểm tra")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer(minLength: 16)
                
                // Footer
                Text("Phát triển dựa trên mã nguồn của XKey, OpenKey & Unikey.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.bottom, 14)
            }
        .sheet(isPresented: $showDonationDialog) {
            DonationView()
        }
    }
}

// MARK: - About Card (gradient bg + gradient border)

private struct AboutCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AurakeyTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AurakeyTheme.accent.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - About Link Card

private struct AboutLinkCard: View {
    let title: String
    let icon: String
    let customIcon: String?
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let customIcon = customIcon, let img = NSImage(named: customIcon) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? color.opacity(0.08) : AurakeyTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isHovered ? color.opacity(0.3) : color.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
