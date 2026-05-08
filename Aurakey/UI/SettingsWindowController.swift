//
//  SettingsWindowController.swift
//  Aurakey
//
//  Window controller for unified Settings with Apple-style design
//

import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    
    private var pinManager: WindowPinManager?
    
    /// Callback when window is closed - used to nil out reference in AppDelegate
    var onWindowClosed: (() -> Void)?

    convenience init(selectedSection: SettingsSection = .general, onSave: @escaping (Preferences) -> Void) {
        // Create window with modern style
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 700, height: 500)

        window.title = "Cài đặt Aurakey"
        window.titlebarAppearsTransparent = false
        // Allow window to be released when closed to free memory
        window.isReleasedWhenClosed = true
        window.level = .floating
        window.center()

        self.init(window: window)
        
        // Set window delegate to handle close
        window.delegate = self

        // Create SwiftUI view with auto-save callback
        let settingsView = SettingsView(
            selectedSection: selectedSection,
            onSave: onSave
        )

        // Wrap in hosting controller
        let hostingController = NSHostingController(rootView: settingsView)
        window.contentViewController = hostingController
        
        // Add pin button to title bar
        pinManager = WindowPinManager(window: window)
        pinManager?.setupPinButton()
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        WindowPinManager.handleWindowClose(window, onClosed: onWindowClosed)
    }
}
