//
//  AppDelegate.swift
//  Aurakey
//
//  Application delegate managing lifecycle and coordination
//

import Cocoa
import SwiftUI
import Sparkle

// MARK: - AXObserver Callback (C function)

/// C callback for AXObserver focus change notifications
/// Must be outside class since AXObserver requires a C function pointer
private func axFocusChangedCallback(
    observer: AXObserver,
    element: AXUIElement,
    notificationName: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    // Get AppDelegate instance from refcon
    guard let refcon = refcon else { return }
    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
    
    // Handle on main thread
    DispatchQueue.main.async {
        appDelegate.handleAXFocusChanged(element)
    }
}

// MARK: - Focused Element Info (typealias to AppBehaviorDetector)

/// Use the unified FocusedElementInfo struct from AppBehaviorDetector
/// to avoid redundant struct definitions and AX queries
private typealias FocusedElementInfo = AppBehaviorDetector.FocusedElementInfo

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Shared Instance
    
    /// Shared instance for access from SwiftUI views
    static var shared: AppDelegate?
    
    // MARK: - Properties

    private var statusBarManager: StatusBarManager?
    private var eventTapManager: EventTapManager?
    private var keyboardHandler: KeyboardEventHandler?
    private var settingsWindowController: SettingsWindowController?
    private var readWordHotKeyMonitor: Any?
    private var readWordGlobalHotKeyMonitor: Any?
    private var appSwitchObserver: NSObjectProtocol?
    private var mouseClickMonitor: Any?
    private var permissionAlertShown = false
    private var permissionCheckTimer: Timer?
    private var inputSourceManager: InputSourceManager?
    private var switchAurakeyHotkeyMonitor: Any?
    private var switchAurakeyGlobalHotkeyMonitor: Any?
    private var tempOffToolbarHotkeyMonitor: Any?
    private var tempOffToolbarGlobalHotkeyMonitor: Any?
    private var focusObserver: AXObserver?
    private var focusObserverPID: pid_t = 0
    private var lastFocusedElement: AXUIElement?
    private var updaterController: SPUStandardUpdaterController?
    private var sparkleUpdateDelegate: SparkleUpdateDelegate?
    
    /// Store the input source ID BEFORE a Window Title Rule switched it
    /// Used to restore when leaving the rule-controlled context
    private var preRuleInputSourceId: String? = nil
    
    /// Track the last focused element's signature for injection detection
    /// Used to detect when user switches from web content to address bar, etc.
    /// Signature includes role, subrole, and description/identifier
    private var lastFocusedElementSignature: String = ""
    
    /// Throttle AXObserver focus change callbacks to prevent rapid-fire AX queries
    /// When apps have animations or autocomplete, AXObserver can fire many times per second
    private var lastAXFocusChangeTime: CFAbsoluteTime = 0
    private let axFocusChangeThrottleInterval: CFAbsoluteTime = 0.1 // 100ms

    // MARK: - Initialization

    override init() {
        super.init()
    }
    
    // MARK: - Public Accessors

    /// Get the keyboard handler for external access
    func getKeyboardHandler() -> KeyboardEventHandler? {
        return keyboardHandler
    }

    /// Get the macro manager for external access
    func getMacroManager() -> MacroManager? {
        if keyboardHandler == nil {
            return nil
        }
        return keyboardHandler?.getMacroManager()
    }

    /// Log message to debug window (for external access)
    func getSparkleUpdater() -> SPUUpdater? {
        return updaterController?.updater
    }

    // MARK: - Application Lifecycle
    
    /// Check if app is running under unit tests
    private var isRunningTests: Bool {
        return NSClassFromString("XCTestCase") != nil
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SINGLE INSTANCE GUARD: Terminate if another instance is already running
        // This prevents duplicate status bar icons when opening from both
        // /Applications and build directory simultaneously
        if !isRunningTests {
            if let bundleId = Bundle.main.bundleIdentifier {
                let runningApps = NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleId
                )
                // Filter to only OTHER instances (exclude self)
                let otherInstances = runningApps.filter { $0 != NSRunningApplication.current }
                if !otherInstances.isEmpty {
                    // Other instance(s) running — terminate them, new instance takes over
                    for oldInstance in otherInstances {
                        NSLog("[Aurakey] Terminating old instance (PID: %d)", oldInstance.processIdentifier)
                        oldInstance.terminate()
                    }
                    // Brief delay to allow old instance(s) to fully clean up
                    // (release status bar icon, event tap, etc.)
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
        
        // Set shared instance for access from SwiftUI views
        AppDelegate.shared = self
        
        // Skip most setup when running under unit tests
        // Tests only need access to VNEngine and related classes
        if isRunningTests {
            // Minimal setup for tests - just create the handler without event tap
            keyboardHandler = KeyboardEventHandler()
            return
        }
        
        // Load and apply preferences
        let preferences = SharedSettings.shared.loadPreferences()
        
        // Load custom Window Title Rules
        AppBehaviorDetector.shared.loadCustomRules()
        
        // Inject OverlayAppDetector into AppBehaviorDetector
        // This allows Shared/AppBehaviorDetector to detect overlay apps without direct dependency
        AppBehaviorDetector.shared.overlayAppNameProvider = {
            return OverlayAppDetector.shared.getVisibleOverlayAppName()
        }
        
        // Initialize components
        setupKeyboardHandling()
        setupStatusBar()
        
        // Apply loaded preferences
        applyPreferences(preferences)

        // Check permissions
        checkAndRequestPermissions()

        // Setup global hotkey
        setupGlobalHotkey()
        
        // Setup read word hotkey
        setupReadWordHotkey()

        // Setup app switch observer
        setupAppSwitchObserver()
        
        // Setup mouse click monitor
        setupMouseClickMonitor()

        // Setup input source manager
        setupInputSourceManager()

        // Setup temp off toolbar (also handles focus change monitoring for injection detection)
        setupTempOffToolbar()

        // Setup convert tool hotkey
        setupConvertToolHotkey()

        // Setup debug hotkey
        setupDebugHotkey()

        // Setup Sparkle auto-update
        setupSparkleUpdater()

        // Load Vietnamese dictionary if spell checking is enabled
        setupSpellCheckDictionary()

        // Initialize AudioManager to handle wake-from-sleep audio issues
        // This must be done at startup to register for system sleep/wake notifications
        _ = AudioManager.shared

    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTapManager?.stop()

        // Remove read word hotkey monitors
        if let monitor = readWordHotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = readWordGlobalHotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Remove switch Aurakey hotkey monitors
        if let monitor = switchAurakeyHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = switchAurakeyGlobalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // Remove temp off toolbar hotkey monitors
        if let monitor = tempOffToolbarHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = tempOffToolbarGlobalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // Stop focus observer
        removeAXObserver()

        // Remove app switch observer
        if let observer = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        
        // Stop permission check timer
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - URL Scheme Handler
    
    /// Handle URL scheme: aurakey://settings opens preferences
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "aurakey" else { continue }
            
            switch url.host {
            case "settings", "preferences":
                // Open settings window
                openPreferences()
            default:
                // Just activate the app
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // MARK: - Setup

    private func setupKeyboardHandling() {
        // Create keyboard handler
        keyboardHandler = KeyboardEventHandler()

        // Create event tap manager
        eventTapManager = EventTapManager()
        eventTapManager?.delegate = keyboardHandler

        // Check permission BEFORE trying to start event tap
        // This prevents macOS system dialog from appearing
        guard let manager = eventTapManager else { return }

        if manager.checkAccessibilityPermission() {
            do {
                try manager.start()
            } catch {
            }
        }
    }
    
    private func setupStatusBar() {
        statusBarManager = StatusBarManager(
            keyboardHandler: keyboardHandler,
            eventTapManager: eventTapManager
        )
        statusBarManager?.viewModel.onOpenPreferences = { [weak self] in
            self?.openPreferences()
        }
        statusBarManager?.viewModel.onOpenMacroManagement = { [weak self] in
            self?.openMacroManagement()
        }
        statusBarManager?.viewModel.onOpenConvertTool = { [weak self] in
            self?.openConvertTool()
        }
        statusBarManager?.onCheckForUpdates = { [weak self] in
            self?.checkForUpdates()
        }

        statusBarManager?.setupStatusBar()
    }
    
    // MARK: - Preferences
    
    func openPreferences() {
        openSettings()
    }
    
    func openSettings(selectedSection: SettingsSection = .general) {
        // Close existing window if section is different
        if let existingController = settingsWindowController {
            existingController.close()
            settingsWindowController = nil
        }
        
        let controller = SettingsWindowController(selectedSection: selectedSection) { [weak self] preferences in
            self?.applyPreferences(preferences)
        }
        
        // Handle window close to release memory
        controller.onWindowClosed = { [weak self] in
            self?.settingsWindowController = nil
        }
        
        settingsWindowController = controller
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openMacroManagement() {
        openSettings(selectedSection: .macro)
    }
    
    func openConvertTool() {
        openSettings(selectedSection: .convertTool)
    }
    
    
    private func applyPreferences(_ preferences: Preferences) {
        // Apply all engine settings at once (batch update - only 1 log message instead of 16+)
        keyboardHandler?.applyAllSettings(
            inputMethod: preferences.inputMethod,
            codeTable: preferences.codeTable,
            modernStyle: preferences.modernStyle,
            spellCheckEnabled: preferences.spellCheckEnabled,
            quickTelexEnabled: preferences.quickTelexEnabled,
            quickStartConsonantEnabled: preferences.quickStartConsonantEnabled,
            quickEndConsonantEnabled: preferences.quickEndConsonantEnabled,
            upperCaseFirstChar: preferences.upperCaseFirstChar,
            restoreIfWrongSpelling: preferences.restoreIfWrongSpelling,
            customConsonants: preferences.customConsonantEnabled ? preferences.customConsonants : "",
            macroEnabled: preferences.macroEnabled,
            macroInEnglishMode: preferences.macroInEnglishMode,
            autoCapsMacro: preferences.autoCapsMacro,
            addSpaceAfterMacro: preferences.addSpaceAfterMacro,
            smartSwitchEnabled: preferences.smartSwitchEnabled,
            excludedApps: preferences.excludedApps,
            undoTypingEnabled: preferences.undoTypingEnabled
        )
        
        // Update status bar manager
        statusBarManager?.viewModel.currentInputMethod = preferences.inputMethod
        statusBarManager?.viewModel.currentCodeTable = preferences.codeTable
        
        // Update hotkey display in menu
        statusBarManager?.updateHotkeyDisplay(preferences.toggleHotkey)
        
        // Update menu bar icon style
        statusBarManager?.updateMenuBarIconStyle(preferences.menuBarIconStyle)
        
        // Update auto-check for updates setting
        updaterController?.updater.automaticallyChecksForUpdates = preferences.autoCheckForUpdates

        // Update hotkey
        setupGlobalHotkey(with: preferences.toggleHotkey)

        // Update undo typing hotkey
        setupUndoTypingHotkey(with: preferences.undoTypingHotkey, enabled: preferences.undoTypingEnabled)
        
        if preferences.undoTypingEnabled {
            if let hotkey = preferences.undoTypingHotkey {
            } else {
            }
        } else {
        }

    }

    
    // MARK: - Debug Window Management

    /// Toggle debug window from menu bar (open if closed, close if open)

    
    /// Handle when debug window is closed via Close button on title bar
    
    // MARK: - Permissions
    
    private func checkAndRequestPermissions() {
        guard let manager = eventTapManager else { return }
        
        if !manager.checkAccessibilityPermission() {
            showPermissionAlert()
            // Start monitoring for permission changes
            startPermissionMonitoring()
        }
    }
    
    private func showPermissionAlert() {
        // Only show alert once
        guard !permissionAlertShown else { return }
        permissionAlertShown = true
        
        let alert = NSAlert()
        alert.messageText = "Yêu cầu quyền Accessibility"
        alert.informativeText = """
        Aurakey cần quyền Accessibility để hoạt động như một phương thức nhập liệu tiếng Việt.
        
        Vui lòng cấp quyền trong Cài đặt hệ thống > Quyền riêng tư & Bảo mật > Accessibility.
        
        Sau khi cấp quyền, Aurakey sẽ tự động hoạt động.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Mở Cài đặt hệ thống")
        alert.addButton(withTitle: "Thoát")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
            // Don't show alert again after opening settings
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        
    }
    
    private func startPermissionMonitoring() {
        // Check permission every 2 seconds
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let manager = self.eventTapManager else { return }
            
            if manager.checkAccessibilityPermission() {
                // Permission granted! Try to start event tap
                
                do {
                    try manager.start()
                    
                    // Stop monitoring
                    self.permissionCheckTimer?.invalidate()
                    self.permissionCheckTimer = nil
                    
                } catch {
                }
            }
        }
        
    }

    private func setupGlobalHotkey() {
        let preferences = SharedSettings.shared.loadPreferences()
        setupGlobalHotkey(with: preferences.toggleHotkey)
    }
    
    private func setupGlobalHotkey(with hotkey: Hotkey) {
        // Configure EventTapManager to handle toggle hotkey
        // This ensures the hotkey is consumed at the lowest level
        // and doesn't reach other applications
        eventTapManager?.toggleHotkey = hotkey
        eventTapManager?.onToggleHotkey = { [weak self] in
            // If using Fn key or Ctrl+Space, temporarily ignore input source changes
            // This prevents macOS's input source switching from interfering
            if hotkey.modifiers.contains(.function) || 
               (hotkey.modifiers == [.control] && hotkey.keyCode == 49) { // Space keyCode
                self?.inputSourceManager?.temporarilyIgnoreInputSourceChanges(forSeconds: 0.5)
            }
            
            self?.statusBarManager?.viewModel.toggleVietnamese()
            
        }

    }
    
    private func setupUndoTypingHotkey(with hotkey: Hotkey?, enabled: Bool) {
        // If undo typing is disabled, clear the hotkey
        guard enabled else {
            eventTapManager?.undoTypingHotkey = nil
            eventTapManager?.onUndoTypingHotkey = nil
            return
        }
        
        // If custom hotkey is set, configure EventTapManager to handle it
        // Otherwise, default Esc behavior is handled in KeyboardEventHandler
        if let hotkey = hotkey {
            eventTapManager?.undoTypingHotkey = hotkey
            eventTapManager?.onUndoTypingHotkey = { [weak self] in
                guard let handler = self?.keyboardHandler else { return false }
                return handler.performUndoTyping()
            }
        } else {
            // Use default Esc key - set a default Esc hotkey
            let defaultEscHotkey = Hotkey(keyCode: VietnameseData.KEY_ESC, modifiers: [], isModifierOnly: false)
            eventTapManager?.undoTypingHotkey = defaultEscHotkey
            eventTapManager?.onUndoTypingHotkey = { [weak self] in
                guard let handler = self?.keyboardHandler else { return false }
                return handler.performUndoTyping()
            }
        }
    }
    
    private func setupReadWordHotkey() {
        // Remove existing monitors
        if let monitor = readWordHotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = readWordGlobalHotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Shortcut: Cmd+Shift+R for "Read Word Before Cursor" (changed from Z to avoid Redo conflict)
        let keyCode: UInt16 = 0x0F // R key
        
        // Helper to check modifiers (only Cmd+Shift, no other modifiers)
        let checkModifiers: (NSEvent) -> Bool = { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return flags.contains(.command) && flags.contains(.shift) && 
                   !flags.contains(.option) && !flags.contains(.control)
        }
        
        // Global monitor - catches hotkey in ALL apps
        readWordGlobalHotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == keyCode && checkModifiers(event) {
                DispatchQueue.main.async {
                    self?.keyboardHandler?.engine.debugReadWordBeforeCursor()
                    
                }
            }
        }
        
        // Local monitor - catches hotkey when Aurakey app is focused
        readWordHotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == keyCode && checkModifiers(event) {
                DispatchQueue.main.async {
                    self?.keyboardHandler?.engine.debugReadWordBeforeCursor()
                    
                }
                // Return nil to consume the event
                return nil
            }
            return event
        }
        
    }
    
    // State tracking for modifier-only switch Aurakey hotkey
    private var switchAurakeyModifierState: (targetReached: Bool, hasTriggered: Bool) = (false, false)
    private var switchAurakeyFlagsMonitor: Any?
    private var switchAurakeyGlobalFlagsMonitor: Any?
    
    private func setupSwitchAurakeyHotkey(with hotkey: Hotkey?) {
        // Remove existing monitors
        if let monitor = switchAurakeyHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            switchAurakeyHotkeyMonitor = nil
        }
        if let monitor = switchAurakeyGlobalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            switchAurakeyGlobalHotkeyMonitor = nil
        }
        if let monitor = switchAurakeyFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            switchAurakeyFlagsMonitor = nil
        }
        if let monitor = switchAurakeyGlobalFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            switchAurakeyGlobalFlagsMonitor = nil
        }
        
        // Reset modifier state
        switchAurakeyModifierState = (false, false)
        
        guard let hotkey = hotkey else {
            return
        }
        
        let keyCode = hotkey.keyCode
        
        // Helper to check modifiers match exactly
        let checkModifiers: (NSEvent) -> Bool = { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var requiredFlags: NSEvent.ModifierFlags = []
            
            if hotkey.modifiers.contains(.command) { requiredFlags.insert(.command) }
            if hotkey.modifiers.contains(.control) { requiredFlags.insert(.control) }
            if hotkey.modifiers.contains(.option) { requiredFlags.insert(.option) }
            if hotkey.modifiers.contains(.shift) { requiredFlags.insert(.shift) }
            
            // Check if flags match exactly (only required modifiers, no extras)
            let significantFlags = NSEvent.ModifierFlags([.command, .control, .option, .shift])
            let actualFlags = flags.intersection(significantFlags)
            return actualFlags == requiredFlags
        }
        
        // Perform the actual toggle
        let performToggle: () -> Void = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let newState = !(self.statusBarManager?.viewModel.isVietnameseEnabled ?? true)
                self.keyboardHandler?.setVietnamese(newState)
                self.statusBarManager?.viewModel.isVietnameseEnabled = newState
            }
        }
        
        // Handle modifier-only hotkey (e.g., Ctrl+Shift)
        if hotkey.isModifierOnly {
            // Helper to handle flagsChanged events
            let handleFlagsChanged: (NSEvent) -> Void = { [weak self] event in
                guard let self = self else { return }
                
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                var requiredFlags: NSEvent.ModifierFlags = []
                
                if hotkey.modifiers.contains(.command) { requiredFlags.insert(.command) }
                if hotkey.modifiers.contains(.control) { requiredFlags.insert(.control) }
                if hotkey.modifiers.contains(.option) { requiredFlags.insert(.option) }
                if hotkey.modifiers.contains(.shift) { requiredFlags.insert(.shift) }
                if hotkey.modifiers.contains(.function) { requiredFlags.insert(.function) }
                
                // Check if all required modifiers are currently pressed
                let significantFlags = NSEvent.ModifierFlags([.command, .control, .option, .shift, .function])
                let actualFlags = flags.intersection(significantFlags)
                let hasAllRequiredModifiers = actualFlags == requiredFlags
                
                if hasAllRequiredModifiers {
                    // All required modifiers are pressed
                    if !self.switchAurakeyModifierState.targetReached {
                        self.switchAurakeyModifierState.targetReached = true
                        self.switchAurakeyModifierState.hasTriggered = false
                    }
                } else {
                    // Modifiers changed (released)
                    if self.switchAurakeyModifierState.targetReached && !self.switchAurakeyModifierState.hasTriggered {
                        // Was holding target modifiers, now released - TRIGGER!
                        self.switchAurakeyModifierState.hasTriggered = true
                        performToggle()
                    }
                    // Reset state
                    self.switchAurakeyModifierState.targetReached = false
                }
            }
            
            // Global monitor for flagsChanged
            switchAurakeyGlobalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
                handleFlagsChanged(event)
            }
            
            // Local monitor for flagsChanged
            switchAurakeyFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                handleFlagsChanged(event)
                return event  // Pass through flagsChanged events
            }
            
            // Also need keyDown monitors to cancel modifier-only hotkey if a key is pressed
            switchAurakeyGlobalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
                // If user presses any key while holding modifiers, cancel the modifier-only hotkey
                if self?.switchAurakeyModifierState.targetReached == true {
                    self?.switchAurakeyModifierState.targetReached = false
                    self?.switchAurakeyModifierState.hasTriggered = true  // Prevent trigger on release
                }
            }
            
            switchAurakeyHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // If user presses any key while holding modifiers, cancel the modifier-only hotkey
                if self?.switchAurakeyModifierState.targetReached == true {
                    self?.switchAurakeyModifierState.targetReached = false
                    self?.switchAurakeyModifierState.hasTriggered = true  // Prevent trigger on release
                }
                return event  // Pass through keyDown events
            }
            
        } else {
            // Regular hotkey (e.g., Cmd+Shift+V)
            
            // Global monitor - catches hotkey in ALL apps
            switchAurakeyGlobalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == keyCode && checkModifiers(event) {
                    performToggle()
                }
            }

            // Local monitor - catches hotkey when Aurakey app is focused
            switchAurakeyHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == keyCode && checkModifiers(event) {
                    performToggle()
                    // Return nil to consume the event
                    return nil
                }
                return event
            }
            
        }
    }

    private func setupAppSwitchObserver() {
        // Listen for app activation changes to reset engine buffer
        // This prevents buffer from previous app affecting typing in new app
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            // Reset keyboard handler engine when switching apps
            // Use resetForAppSwitch() which assumes typing mid-sentence to prevent
            // Forward Delete from deleting text on the right of cursor
            self.keyboardHandler?.resetForAppSwitch()

            AppBehaviorDetector.shared.clearConfirmedInjectionMethod()

            // Handle Smart Switch - auto switch language per app
            self.handleSmartSwitch(notification: notification)
            
            // Apply Force Accessibility (AXManualAccessibility) FIRST if matching rule exists
            // This MUST happen BEFORE detectInjectionMethod() because:
            // 1. Force AX enables enhanced accessibility for Electron/Chromium apps
            // 2. detectInjectionMethod() may need to read AX values
            // 3. AX values won't be available without Force AX enabled first
            ForceAccessibilityManager.shared.applyForCurrentApp()
            
            // Small delay to allow AX tree to update after setting AXManualAccessibility
            // Electron/Chromium apps need a moment to refresh their accessibility tree
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self else { return }
                
                // Detect and set confirmed injection method for the new app
                // This ensures keystrokes use correct method immediately after app switch
                let detector = AppBehaviorDetector.shared
                let injectionInfo = detector.detectInjectionMethod()
                detector.setConfirmedInjectionMethod(injectionInfo)

                let textMethodName = injectionInfo.textSendingMethod == .chunked ? "Chunked" : "OneByOne"
                
                // Setup AXObserver for the new app to monitor focus changes (CMD+T, etc.)
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self.setupAXObserverForApp(app)
                }
            }
            
            // Reset intra-app focus tracking (new app = new baseline)
            self.lastFocusedElementSignature = ""
        }

        // Setup overlay detector callback to restore language when overlay closes
        setupOverlayDetectorCallback()
    }

    /// Setup callback for overlay visibility changes
    private func setupOverlayDetectorCallback() {
        OverlayAppDetector.shared.onOverlayVisibilityChanged = { [weak self] isVisible in
            guard let self = self else { return }
            
            let detector = AppBehaviorDetector.shared
            let injectionInfo = detector.detectInjectionMethod()
            detector.setConfirmedInjectionMethod(injectionInfo)

            if isVisible {
                // When overlay opens (hidden → visible):
                // 1. Detect and set injection method for overlay (Spotlight/Raycast/Alfred)
                // 2. Enable Vietnamese for overlay unless overlay has its own disable rule
                // 3. Reset mid-sentence flag (overlay apps start with empty/fresh input)
                let textMethodName = injectionInfo.textSendingMethod == .chunked ? "Chunked" : "OneByOne"
                self.enableVietnameseForOverlay()
                
                // CRITICAL FIX: When overlay opens (e.g., CMD+Space for Spotlight),
                // reset mid-sentence flag. The resetForAppSwitch() called earlier sets isTypingMidSentence=true
                // to protect text in normal apps, but overlay apps always start fresh.
                // If user clicks into existing text, mouse click handler will set mid-sentence appropriately.
                self.keyboardHandler?.resetMidSentenceFlag()
                let overlayName = OverlayAppDetector.shared.getVisibleOverlayAppName() ?? "Overlay"
            } else {
                // When overlay closes (visible → hidden):
                // 1. Detect and set injection method for the underlying app
                // 2. Restore language for current app
                // 3. Set mid-sentence flag (protect text in underlying app)
                let textMethodName = injectionInfo.textSendingMethod == .chunked ? "Chunked" : "OneByOne"
                self.restoreLanguageForCurrentApp()
                
                // When overlay closes, user returns to previous app where cursor position is unknown.
                // Set mid-sentence flag to protect text on the right of cursor.
                // Note: Overlay close doesn't trigger didActivateApplicationNotification since
                // frontmost app is still the original app (Spotlight runs as overlay, not frontmost).
                self.keyboardHandler?.resetWithCursorMoved()
            }
        }
    }
    
    /// Enable Vietnamese when overlay opens (Spotlight/Raycast/Alfred)
    /// This ensures user can type Vietnamese in overlay, regardless of previous app's rule
    private func enableVietnameseForOverlay() {
        guard keyboardHandler != nil else { return }
        
        // Check Input Source config first - it takes priority
        if let currentSource = InputSourceManager.getCurrentInputSource() {
            let inputSourceEnabled = InputSourceManager.shared.isEnabled(for: currentSource.id)
            if !inputSourceEnabled {
                return
            }
        }
        
        let overlayName = OverlayAppDetector.shared.getVisibleOverlayAppName() ?? "Unknown"
    }

    /// Restore language for the current frontmost app from Smart Switch
    private func restoreLanguageForCurrentApp() {
        guard let handler = keyboardHandler else { return }

        // IMPORTANT: Check Input Source config first - it takes priority
        // If current Input Source is configured as disabled, don't restore Vietnamese
        if let currentSource = InputSourceManager.getCurrentInputSource() {
            let inputSourceEnabled = InputSourceManager.shared.isEnabled(for: currentSource.id)
            if !inputSourceEnabled {
                return
            }
        }

        // Get current frontmost app
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }

        // Smart Switch (if enabled)
        guard handler.smartSwitchEnabled else { return }

        // Get current language state
        let currentLanguage = statusBarManager?.viewModel.isVietnameseEnabled == true ? 1 : 0

        // Check if should restore language using Smart Switch logic
        let result = handler.engine.checkSmartSwitchForApp(bundleId: bundleId, currentLanguage: currentLanguage)

        // If should switch, restore the saved language
        if result.shouldSwitch {
            let newEnabled = result.newLanguage == 1
            statusBarManager?.viewModel.isVietnameseEnabled = newEnabled
            handler.setVietnamese(newEnabled)

        }
    }
    
    // MARK: - Dock Icon
    
    private func updateDockIconVisibility(show: Bool) {
        if show {
            // Show Dock icon - regular app mode
            NSApp.setActivationPolicy(.regular)
        } else {
            // Hide Dock icon - accessory/background app mode
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    /// Handle Smart Switch when app changes
    private func handleSmartSwitch(notification: Notification) {
        guard let handler = keyboardHandler else { return }
        
        // IMPORTANT: Check Input Source config first - it takes priority over everything
        // If current Input Source is configured as disabled, don't allow Vietnamese to be enabled
        if let currentSource = InputSourceManager.getCurrentInputSource() {
            let inputSourceEnabled = InputSourceManager.shared.isEnabled(for: currentSource.id)
            if !inputSourceEnabled {
                return
            }
        }
        
        // Get the new active app
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }
        
        // PRIORITY 1: Check for target input source in Window Title Rules
        let detector = AppBehaviorDetector.shared
        let inputSourceOverride = detector.getTargetInputSourceOverride()
        
        if inputSourceOverride.hasTarget, let targetId = inputSourceOverride.inputSourceId {
            // Save current input source BEFORE switching (for restore later)
            if preRuleInputSourceId == nil {
                preRuleInputSourceId = InputSourceSwitcher.shared.getCurrentInputSourceId()
            }
            
            // Only switch if not already using the target
            let currentId = InputSourceSwitcher.shared.getCurrentInputSourceId()
            if currentId != targetId {
                let success = InputSourceSwitcher.shared.selectInputSource(bundleId: targetId)
                if success {
                } else {
                }
            }
            // Don't proceed to Smart Switch - rule takes priority
            return
        } else {
            // No rule matches - restore pre-rule input source if we have one
            if let savedInputSourceId = preRuleInputSourceId {
                let currentId = InputSourceSwitcher.shared.getCurrentInputSourceId()
                if currentId != savedInputSourceId {
                    let success = InputSourceSwitcher.shared.selectInputSource(bundleId: savedInputSourceId)
                    if success {
                    } else {
                    }
                }
                preRuleInputSourceId = nil
            }
        }
        
        // PRIORITY 2: Smart Switch (if enabled)
        guard handler.smartSwitchEnabled else { return }
        
        // Get current language from UI (StatusBar) - this is the source of truth
        let currentLanguage = statusBarManager?.viewModel.isVietnameseEnabled == true ? 1 : 0
        
        // Check if should switch language, passing the actual current language
        let result = handler.engine.checkSmartSwitchForApp(bundleId: bundleId, currentLanguage: currentLanguage)
        
        if result.shouldSwitch {
            // Switch language
            let newEnabled = result.newLanguage == 1
            statusBarManager?.viewModel.isVietnameseEnabled = newEnabled
            handler.setVietnamese(newEnabled)
            
        } else {
            // App is new or language hasn't changed - save current language
            handler.engine.saveAppLanguage(bundleId: bundleId, language: currentLanguage)
        }
    }
    
    private func setupMouseClickMonitor() {
        // Monitor mouse up events to detect focus changes
        // Using mouseUp instead of mouseDown to avoid triggering during drag operations
        // When user releases mouse, they have completed a click or drag selection
        
        // Global monitor - catches clicks in OTHER apps
        mouseClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { [weak self] event in
            // Arm overlay probe — mouse clicks can dismiss overlays (Spotlight, Raycast, Alfred)
            OverlayAppDetector.shared.armProbe()
            
            // Reset engine when mouse is released (click completed or drag finished)
            // Mark as cursor moved to disable autocomplete fix (avoid deleting text on right)
            self?.keyboardHandler?.resetWithCursorMoved()

            // Reset lastFocusedElement to allow toolbar to re-show after auto-hide
            // When user clicks, they might be moving cursor within same field
            self?.lastFocusedElement = nil

            // Trigger toolbar check with slight delay to allow focus to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.handleFocusCheck()
            }
        }
    }

    /// Log detailed information about the input type when mouse is clicked
    /// Uses 3x retry detection with 0.15s interval to handle AX API timing issues
    /// This fixes false positive overlay detection when clicking another app while Spotlight is visible

    
    private func setupInputSourceManager() {
        inputSourceManager = InputSourceManager.shared

        // Handle input source changes
        inputSourceManager?.onInputSourceChanged = { [weak self] source, shouldEnable in
            self?.handleInputSourceChange(source: source, shouldEnable: shouldEnable)
        }

        // IMPORTANT: Check current input source on startup and apply config
        if let currentSource = InputSourceManager.getCurrentInputSource() {
            let shouldEnable = inputSourceManager?.isEnabled(for: currentSource.id) ?? true
            handleInputSourceChange(source: currentSource, shouldEnable: shouldEnable)
        }
    }

    /// Handle input source changes - apply enable/disable logic
    private func handleInputSourceChange(source: InputSourceInfo, shouldEnable: Bool) {
        // Ensure event tap is running
        guard let manager = eventTapManager else { return }
        do {
            try manager.start()
        } catch EventTapManager.EventTapError.alreadyRunning {
            // Already running
        } catch {
        }

        // Get current state
        let currentlyEnabled = self.statusBarManager?.viewModel.isVietnameseEnabled ?? false

        // Auto enable/disable Vietnamese mode based on configuration
        if shouldEnable {
            // Enable Vietnamese mode
            if !currentlyEnabled {
                self.statusBarManager?.viewModel.isVietnameseEnabled = true
                self.keyboardHandler?.setVietnamese(true)
            }
        } else {
            // Disable Vietnamese mode
            if currentlyEnabled {
                self.statusBarManager?.viewModel.isVietnameseEnabled = false
                self.keyboardHandler?.setVietnamese(false)
            }
        }
    }

    // MARK: - Sparkle Auto-Update

    private func checkForUpdates() {
        // Activate app to bring update dialog to front
        NSApp.activate(ignoringOtherApps: true)
        updaterController?.updater.checkForUpdates()
    }
    
    /// Check for updates from SwiftUI views (activates app to bring dialog to front)
    func checkForUpdatesFromUI() {
        
        // Must be called on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Activate app to bring update dialog to front
            NSApp.activate(ignoringOtherApps: true)
            
            // Use the same method as menu bar - updater.checkForUpdates()
            if let updater = self.updaterController?.updater {
                updater.checkForUpdates()
            } else {
            }
        }
    }

    private func setupSparkleUpdater() {
        // Create the update delegate first
        sparkleUpdateDelegate = SparkleUpdateDelegate()
        
        // Connect debug logging to the delegate
        sparkleUpdateDelegate?.debugLogCallback = { [weak self] message in
        }
        
        // Initialize Sparkle updater controller with our delegate
        // This will automatically check for updates based on Info.plist settings:
        // - SUFeedURL: appcast feed URL
        // - SUPublicEDKey: public key for signature verification
        // - SUEnableAutomaticChecks: enable automatic update checks
        // - SUScheduledCheckInterval: check interval in seconds (86400 = 24 hours)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: sparkleUpdateDelegate,
            userDriverDelegate: sparkleUpdateDelegate  // Also use as user driver delegate to bring update dialog to front
        )
        
        
        // Apply auto-check setting from preferences
        let autoCheckEnabled = SharedSettings.shared.autoCheckForUpdates
        updaterController?.updater.automaticallyChecksForUpdates = autoCheckEnabled
        
        // Check for updates immediately on app launch (silently in background)
        // Only if auto-check is enabled
        if autoCheckEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let updater = self?.updaterController?.updater else { return }
                
                // Use background check - won't show UI if no update available
                if updater.canCheckForUpdates {
                    updater.checkForUpdatesInBackground()
                } else {
                }
            }
        } else {
        }
    }

    // MARK: - Spell Check Dictionary Setup

    private func setupSpellCheckDictionary() {
        let preferences = SharedSettings.shared.loadPreferences()

        guard preferences.spellCheckEnabled else {
            return
        }

        let style: VNDictionaryManager.DictionaryStyle = preferences.modernStyle ? .dauMoi : .dauCu

        // Check if dictionary is already available locally
        if VNDictionaryManager.shared.isDictionaryAvailable(style: style) {
            // Load from local storage
            do {
                try VNDictionaryManager.shared.loadDictionary(style: style)
                let stats = VNDictionaryManager.shared.getDictionaryStats()
                let count = stats[style.rawValue] ?? 0
            } catch {
            }
        } else {
        }
    }

    // MARK: - Temp Off Toolbar

    private func setupTempOffToolbar() {
        // Always setup notification observer for settings changes
        setupTempOffToolbarSettingsObserver()
        
        // Setup AXObserver for focus change monitoring (injection detection)
        // AXObserver runs regardless of toolbar setting for injection method detection
        setupFocusChangeMonitoring()

        let preferences = SharedSettings.shared.loadPreferences()

        // Only setup toolbar-specific features if enabled
        guard preferences.tempOffToolbarEnabled else {
            return
        }

        enableTempOffToolbar()
    }

    /// Setup observer for toolbar settings changes
    private func setupTempOffToolbarSettingsObserver() {
        NotificationCenter.default.addObserver(
            forName: .tempOffToolbarSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleTempOffToolbarSettingsChange()
        }
    }

    /// Handle toolbar settings changes (enable/disable or hotkey change)
    private func handleTempOffToolbarSettingsChange() {
        let preferences = SharedSettings.shared.loadPreferences()

        if preferences.tempOffToolbarEnabled {
            enableTempOffToolbar()
        } else {
            disableTempOffToolbar()
        }
    }

    /// Enable temp off toolbar and setup all related features
    private func enableTempOffToolbar() {
        // Setup toolbar state change callback
        TempOffToolbarController.shared.onStateChange = { [weak self] spellingOff, engineOff in
            guard let self = self else { return }

            // Update engine temp off states
            self.keyboardHandler?.engine.vTempOffSpelling = spellingOff ? 1 : 0
            self.keyboardHandler?.engine.vTempOffEngine = engineOff ? 1 : 0

        }

        // Setup hotkey from preferences
        setupTempOffToolbarHotkey()

        
        // Check if user is already focused on a text input and show toolbar immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.lastFocusedElement = nil  // Reset to force re-check
            self?.handleFocusCheck()
        }
    }

    /// Disable temp off toolbar and cleanup
    /// Note: AXObserver continues for injection detection
    private func disableTempOffToolbar() {
        // Clear hotkey from EventTapManager
        eventTapManager?.toolbarHotkey = nil
        eventTapManager?.onToolbarHotkey = nil

        // Hide toolbar if visible
        TempOffToolbarController.shared.hide()

        // Clear callback
        TempOffToolbarController.shared.onStateChange = nil
        
        // Clear last focused element so re-enable will re-check
        lastFocusedElement = nil

    }

    /// Setup monitoring for focus changes to auto-show toolbar when focusing text fields
    private func setupFocusChangeMonitoring() {
        // Use NSWorkspace notification to detect app activation
        // Then check if focused element is a text field
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleFocusCheck()
        }

        // Mouse clicks are already handled by mouseClickMonitor
        // Focus changes within apps are handled by AXObserver (event-driven, no polling)
        
        // Setup AXObserver for the current frontmost app on launch
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            setupAXObserverForApp(frontApp)
        }

    }
    
    /// Main focus check handler - gets focused element once and passes to both processors
    /// OPTIMIZED: Uses FocusedElementInfo to cache AX attributes in a single query
    private func handleFocusCheck() {
        // Get focused element ONCE (avoid duplicate AX API calls)
        guard let axElement = AXHelper.getFocusedElement() else {
            // No focused element - hide toolbar if visible
            if SharedSettings.shared.tempOffToolbarEnabled && TempOffToolbarController.shared.isVisible {
                TempOffToolbarController.shared.hide()
            }
            return
        }
        
        // OPTIMIZED: Get all AX attributes in a single pass via FocusedElementInfo
        // This reduces AX API calls from ~10 to ~5 per focus check
        let elementInfo = FocusedElementInfo.from(axElement)
        
        // 1. ALWAYS check for injection method changes (CMD+T, Tab, etc.)
        checkIntraAppFocusChange(with: elementInfo)
        
        // 2. Check toolbar display (only if enabled)
        if SharedSettings.shared.tempOffToolbarEnabled {
            checkAndShowToolbarForFocusedElement(with: elementInfo)
        }
    }

    // MARK: - Intra-App Focus Monitoring
    
    /// Check if focused element has changed within the same app (e.g., CMD+T in browser)
    /// If so, re-detect injection method (but DO NOT reset engine - that's handled by user actions)
    /// Also re-primes cache when confirmedInjectionMethod was cleared (e.g., after mouse click)
    /// - Parameter elementInfo: Cached AX element info (passed from handleFocusCheck)
    private func checkIntraAppFocusChange(with elementInfo: FocusedElementInfo) {
        // OPTIMIZED: Use pre-computed signature from FocusedElementInfo
        let currentSignature = elementInfo.signature
        let detector = AppBehaviorDetector.shared
        
        // Check if signature changed (different element type)
        if currentSignature != lastFocusedElementSignature && !lastFocusedElementSignature.isEmpty {
            
            // Re-detect injection method (needed for address bar, terminal, etc.)
            let previousMethod = detector.confirmedInjectionMethod
            let injectionInfo = detector.detectInjectionMethod(focusedInfo: elementInfo)
            
            // Log focus change
            
            // ALWAYS set confirmed method to ensure cache is populated
            detector.setConfirmedInjectionMethod(injectionInfo)
            
            // Log injection method change
            if let prev = previousMethod, (prev.method != injectionInfo.method || prev.description != injectionInfo.description) {
                let textMethodName = injectionInfo.textSendingMethod == .chunked ? "Chunked" : "OneByOne"
                let emptyCharStr = injectionInfo.needsEmptyCharPrefix ? ", emptyCharPrefix=true" : ""
            }
            
            // NOTE: Engine reset is NOT done here!
            // Engine reset is handled by explicit user actions:
            // - Mouse click (setupMouseClickMonitor)
            // - Tab key (KeyboardEventHandler.processKeyEvent)
            // - Arrow keys / Home / End / PageUp / PageDown (KeyboardEventHandler.processKeyEvent)
            // - App switch (handleAppSwitch)
            //
            // Focus change detection is ONLY for re-detecting injection method.
            // This avoids issues where apps "refine" focus after user starts typing
            // (e.g., VSCode: AXWindow → AXTextArea, Facebook: dropdown menus).
            
            // NEW: Notify engine about focus change during typing
            // This is important for suggestion popup scenarios where keystrokes may go to popup
            // causing buffer desync. Engine will use AX verify at next word break.
            keyboardHandler?.engine.notifyFocusChanged()
        } else if detector.confirmedInjectionMethod == nil {
            // Cache was cleared (e.g., by mouse click resetWithCursorMoved)
            // but signature is unchanged (same field).
            // Re-prime cache to avoid live AX detection on every keystroke.
            let injectionInfo = detector.detectInjectionMethod(focusedInfo: elementInfo)
            detector.setConfirmedInjectionMethod(injectionInfo)
        }
        
        // Update last signature
        lastFocusedElementSignature = currentSignature
    }
    
    // MARK: - AXObserver for Focus Changes
    
    /// Setup AXObserver for the given app to receive focus change notifications
    /// This is called when app switches to monitor focus changes within that app (e.g., Cmd+T in browser)
    private func setupAXObserverForApp(_ app: NSRunningApplication) {
        // Skip if it's Aurakey itself
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        
        let pid = app.processIdentifier
        
        // Skip if already observing this app
        guard pid != focusObserverPID else { return }
        
        // Remove existing observer if any
        removeAXObserver()
        
        // Create new observer for this app
        var observer: AXObserver?
        let result = AXObserverCreate(pid, axFocusChangedCallback, &observer)
        
        guard result == .success, let newObserver = observer else {
            return
        }
        
        // Get the app's AXUIElement
        let appElement = AXUIElementCreateApplication(pid)
        
        // Register for focused UI element changed notification
        let addResult = AXObserverAddNotification(
            newObserver,
            appElement,
            kAXFocusedUIElementChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard addResult == .success else {
            return
        }
        
        // Add observer to run loop
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(newObserver),
            .defaultMode
        )
        
        // Save observer and PID
        focusObserver = newObserver
        focusObserverPID = pid
        
    }
    
    /// Remove current AXObserver
    private func removeAXObserver() {
        guard let observer = focusObserver else { return }
        
        // Remove from run loop
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        
        focusObserver = nil
        focusObserverPID = 0
    }
    
    /// Handle focus changed notification from AXObserver
    /// This is called by the C callback function
    /// OPTIMIZED: Uses FocusedElementInfo to cache AX attributes
    /// ALWAYS re-detects injection method (event-driven path, already throttled)
    /// to catch same-app context switches (tab/window) where signature stays the same
    /// but window title rules and injection method may change.
    func handleAXFocusChanged(_ element: AXUIElement) {
        // Throttle: Skip if called too rapidly (< 100ms since last call)
        // This prevents blocking the main thread when AXObserver fires rapidly
        // (e.g., during autocomplete, animations, or rapid UI updates)
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastAXFocusChangeTime > axFocusChangeThrottleInterval else {
            return
        }
        lastAXFocusChangeTime = now
        
        // OPTIMIZED: Get all AX attributes in a single pass via FocusedElementInfo
        let elementInfo = FocusedElementInfo.from(element)
        let currentSignature = elementInfo.signature
        let signatureChanged = currentSignature != lastFocusedElementSignature && !lastFocusedElementSignature.isEmpty
        
        // ALWAYS re-detect injection method in event-driven path.
        // AXObserver fires indicate genuine focus changes (throttle handles spam).
        // With pre-fetched focusedInfo, re-detection is pure logic (no extra AX calls).
        // This ensures same-app tab/window switches re-evaluate window title rules
        // even when AX role/subrole/description are identical.
        let detector = AppBehaviorDetector.shared
        // Read cache BEFORE re-detection to compare correctly
        let previousMethod = detector.confirmedInjectionMethod
        let injectionInfo = detector.detectInjectionMethod(focusedInfo: elementInfo)
        
        // Log focus change (only when signature actually changed)
        if signatureChanged {
        }
        
        // ALWAYS set confirmed method to ensure cache is populated
        // (after mouse click clears cache, this re-populates it)
        detector.setConfirmedInjectionMethod(injectionInfo)
        
        // Log injection method change
        if let prev = previousMethod, (prev.method != injectionInfo.method || prev.description != injectionInfo.description) {
            let textMethodName = injectionInfo.textSendingMethod == .chunked ? "Chunked" : "OneByOne"
            let emptyCharStr = injectionInfo.needsEmptyCharPrefix ? ", emptyCharPrefix=true" : ""
        }
        
        // NOTE: Engine reset is NOT done here!
        // See checkIntraAppFocusChange for explanation.
        
        // NEW: Notify engine about focus change during typing
        if signatureChanged {
            keyboardHandler?.engine.notifyFocusChanged()
        }
        
        // Update last signature (for timer-based checkIntraAppFocusChange)
        lastFocusedElementSignature = currentSignature
        
        // Check toolbar display (only if enabled)
        // This ensures toolbar shows/hides when focus changes via keyboard (CMD+T, Tab, etc.)
        let shouldShowTempOffToolbar = SharedSettings.shared.tempOffToolbarEnabled
        
        if shouldShowTempOffToolbar {
            // Reset lastFocusedElement to force toolbar re-evaluation
            lastFocusedElement = nil
            checkAndShowToolbarForFocusedElement(with: elementInfo)
        } else {
            // Just update for tracking
            lastFocusedElement = element
        }
    }
    
    /// Check if focused element is a text field and show toolbar
    /// - Parameter elementInfo: Cached AX element info (passed from handleFocusCheck)
    /// OPTIMIZED: Uses signature comparison instead of CFEqual, and cached isTextInput
    private func checkAndShowToolbarForFocusedElement(with elementInfo: FocusedElementInfo) {
        // OPTIMIZED: Use signature comparison instead of CFEqual
        // Signature is already computed by FocusedElementInfo, no additional AX calls needed
        let currentSignature = elementInfo.signature
        
        let showTempOff = SharedSettings.shared.tempOffToolbarEnabled
        
        // Check if it's the same element as before (using signature)
        if currentSignature == lastFocusedElementSignature && lastFocusedElement != nil {
            // Same element - update positions if visible, or re-show if hidden (only if has caret)
            let hasTextCursor = elementInfo.hasCaret
            
            if showTempOff {
                if TempOffToolbarController.shared.isVisible {
                    TempOffToolbarController.shared.updatePosition()
                } else if hasTextCursor {
                    // Toolbar was hidden (auto-hide), re-show it on click
                    TempOffToolbarController.shared.show()
                }
            }
            return
        }

        // New focused element
        lastFocusedElement = elementInfo.element

        // Both toolbars use hasCaret check - only show when element has actual text cursor
        let hasTextCursor = elementInfo.hasCaret
        
        if hasTextCursor {
            // Show TempOff toolbar if enabled
            if showTempOff {
                TempOffToolbarController.shared.show()
            }
        } else {
            // No caret - hide both toolbars
            if showTempOff {
                TempOffToolbarController.shared.hide()
            }
        }
    }
    
    private func setupTempOffToolbarHotkey() {
        // Get hotkey from preferences
        let preferences = SharedSettings.shared.loadPreferences()
        let hotkey = preferences.tempOffToolbarHotkey

        // If no keycode, disable hotkey
        guard hotkey.keyCode != 0 else {
            eventTapManager?.toolbarHotkey = nil
            eventTapManager?.onToolbarHotkey = nil
            return
        }

        // Configure EventTapManager to handle toolbar hotkey
        // This ensures the hotkey is consumed at the lowest level
        eventTapManager?.toolbarHotkey = hotkey
        eventTapManager?.onToolbarHotkey = { [weak self] in
            TempOffToolbarController.shared.toggle()
        }

    }

    /// Show temp off toolbar programmatically
    func showTempOffToolbar() {
        TempOffToolbarController.shared.show()
    }

    /// Hide temp off toolbar programmatically
    func hideTempOffToolbar() {
        TempOffToolbarController.shared.hide()
    }

    /// Toggle temp off toolbar programmatically
    func toggleTempOffToolbar() {
        TempOffToolbarController.shared.toggle()
    }

    // MARK: - Convert Tool Hotkey

    private func setupConvertToolHotkey() {
        // Setup notification observer for hotkey changes
        NotificationCenter.default.addObserver(
            forName: .convertToolHotkeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateConvertToolHotkey()
        }

        // Initial setup
        updateConvertToolHotkey()
    }

    private func updateConvertToolHotkey() {
        let preferences = SharedSettings.shared.loadPreferences()
        let hotkey = preferences.convertToolHotkey

        // If no keycode, disable hotkey
        guard hotkey.keyCode != 0 else {
            eventTapManager?.convertToolHotkey = nil
            eventTapManager?.onConvertToolHotkey = nil
            return
        }

        // Configure EventTapManager to handle convert tool hotkey
        eventTapManager?.convertToolHotkey = hotkey
        eventTapManager?.onConvertToolHotkey = { [weak self] in
            self?.openConvertTool()
        }

    }

    // MARK: - Debug Hotkey

    private func setupDebugHotkey() {
        // Setup notification observer for hotkey/settings changes
        NotificationCenter.default.addObserver(
            forName: .debugSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDebugHotkey()
        }

        // Initial setup
        updateDebugHotkey()
    }

    private func updateDebugHotkey() {
        let preferences = SharedSettings.shared.loadPreferences()
        let hotkey = preferences.debugHotkey

        // If no keycode, disable hotkey
        guard hotkey.keyCode != 0 else {
            eventTapManager?.debugHotkey = nil
            eventTapManager?.onDebugHotkey = nil
            return
        }

        // Configure EventTapManager to handle debug hotkey
        eventTapManager?.debugHotkey = hotkey
        eventTapManager?.onDebugHotkey = { }

    }
}

