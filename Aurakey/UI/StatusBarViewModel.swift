import SwiftUI
import Combine
import Cocoa

class StatusBarViewModel: ObservableObject {
    @Published var isVietnameseEnabled = true
    @Published var currentInputMethod: InputMethod = .telex
    @Published var currentCodeTable: CodeTable = .unicode
    @Published var hotkeyDisplay = "⌘⇧V"
    @Published var hotkeyKeyEquivalent: KeyEquivalent = "v"
    @Published var hotkeyModifiers: EventModifiers = [.command, .shift]
    
    private weak var keyboardHandler: KeyboardEventHandler?
    private weak var eventTapManager: EventTapManager?
    
    var onOpenPreferences: (() -> Void)?
    var onOpenMacroManagement: (() -> Void)?
    var onOpenConvertTool: (() -> Void)?
    
    init(keyboardHandler: KeyboardEventHandler?, eventTapManager: EventTapManager?) {
        self.keyboardHandler = keyboardHandler
        self.eventTapManager = eventTapManager
        
        if let handler = keyboardHandler {
            handler.setVietnamese(isVietnameseEnabled)
        }
        
        updateHotkeyDisplay()
    }
    
    func toggleVietnamese() {
        applyVietnameseState(!isVietnameseEnabled, showCursorHUD: true, playBeep: true)
    }

    /// Apply VI/EN state and optionally show the cursor HUD indicator.
    func applyVietnameseState(_ enabled: Bool, showCursorHUD: Bool, playBeep: Bool = false) {
        guard isVietnameseEnabled != enabled else { return }

        isVietnameseEnabled = enabled
        keyboardHandler?.setVietnamese(enabled)

        if showCursorHUD {
            CursorHUDController.shared.show(isVietnamese: enabled)
        }

        if playBeep {
            let prefs = SharedSettings.shared.loadPreferences()
            if prefs.beepOnToggle {
                AudioManager.shared.playBeep()
            }
        }

        saveLanguageForCurrentApp()
    }
    
    private func saveLanguageForCurrentApp() {
        guard let handler = keyboardHandler else { return }
        guard handler.smartSwitchEnabled else { return }

        if OverlayAppDetector.shared.isOverlayAppVisible() {
            return
        }

        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }

        let language = isVietnameseEnabled ? 1 : 0
        handler.engine.saveAppLanguage(bundleId: bundleId, language: language)
    }
    
    func selectInputMethod(_ method: InputMethod) {
        currentInputMethod = method
        
        if let handler = keyboardHandler {
            handler.inputMethod = method
        }
        
        var prefs = SharedSettings.shared.loadPreferences()
        prefs.inputMethod = method
        SharedSettings.shared.savePreferences(prefs)
    }
    
    func selectCodeTable(_ table: CodeTable) {
        currentCodeTable = table
        keyboardHandler?.codeTable = table
        
        var prefs = SharedSettings.shared.loadPreferences()
        prefs.codeTable = table
        SharedSettings.shared.savePreferences(prefs)
    }
    
    func openPreferences() {
        onOpenPreferences?()
    }
    
    func openMacroManagement() {
        onOpenMacroManagement?()
    }
    
    func openConvertTool() {
        onOpenConvertTool?()
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    func updateHotkeyDisplay(_ hotkey: Hotkey? = nil) {
        let hotkeyToUse = hotkey ?? SharedSettings.shared.loadPreferences().toggleHotkey
        
        hotkeyDisplay = hotkeyToUse.displayString
        
        if hotkeyToUse.isModifierOnly {
            hotkeyKeyEquivalent = KeyEquivalent("\0")
        } else {
            hotkeyKeyEquivalent = keyCodeToKeyEquivalent(hotkeyToUse.keyCode)
        }
        hotkeyModifiers = modifierFlagsToEventModifiers(hotkeyToUse.modifiers)
    }
    
    private func keyCodeToKeyEquivalent(_ keyCode: UInt16) -> KeyEquivalent {
        if let letter = KeyCodeToCharacter.keyCodeToLetterMap[keyCode] {
            return KeyEquivalent(letter)
        }
        if keyCode == 0x31 { return " " }
        return "v"
    }
    
    private func modifierFlagsToEventModifiers(_ flags: ModifierFlags) -> EventModifiers {
        var modifiers: EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }
}
