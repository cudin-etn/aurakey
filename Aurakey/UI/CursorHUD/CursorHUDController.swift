//
//  CursorHUDController.swift
//  Aurakey
//
//  Floating HUD above the text caret when the user toggles Vietnamese/English.
//

import AppKit
import SwiftUI

final class CursorHUDController {
    static let shared = CursorHUDController()

    private var panel: NSPanel?
    private var hideTimer: Timer?
    private let displayDuration: TimeInterval = 1.4
    private let hudSize: CGFloat = 118

    private init() {}

    func show(isVietnamese: Bool) {
        guard SharedSettings.shared.cursorHUDEnabled else { return }

        hideTimer?.invalidate()
        hideTimer = nil

        let hudView = CursorHUDView(isVietnamese: isVietnamese)
        let panel = ensurePanel(rootView: hudView)
        centerPanel(panel)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        hideTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.fadeOutAndHide()
        }
    }

    private func centerPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        let size = NSSize(width: hudSize, height: hudSize)
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2
        panel.setContentSize(size)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func ensurePanel(rootView: CursorHUDView) -> NSPanel {
        if let panel {
            let hosting = NSHostingController(rootView: rootView)
            panel.contentViewController = hosting
            applyTransparentCircularHosting(hosting.view)
            return panel
        }

        let hosting = NSHostingController(rootView: rootView)
        applyTransparentCircularHosting(hosting.view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: hudSize, height: hudSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setContentSize(NSSize(width: hudSize, height: hudSize))

        self.panel = panel
        return panel
    }

    private func applyTransparentCircularHosting(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false
        view.layer?.masksToBounds = true
        view.layer?.cornerRadius = hudSize / 2
    }

    private func fadeOutAndHide() {
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })

        hideTimer = nil
    }
}
