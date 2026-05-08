//
//  SharedSettings.swift
//  Aurakey
//
//  Shared settings for Aurakey app
//  Uses App Group for cross-app communication
//

import Foundation

/// App Group identifier for sharing data
/// Note: macOS Sequoia+ requires TeamID prefix for native apps distributed outside App Store
let kAurakeyAppGroup = "7E6Z9B4F2H.com.tdev.inputmethod.Aurakey"

/// Keys for shared settings
enum SharedSettingsKey: String {
    // Hotkey settings
    case toggleHotkeyCode = "Aurakey.toggleHotkeyCode"
    case toggleHotkeyModifiers = "Aurakey.toggleHotkeyModifiers"
    case toggleHotkeyIsModifierOnly = "Aurakey.toggleHotkeyIsModifierOnly"
    case undoTypingEnabled = "Aurakey.undoTypingEnabled"
    case undoTypingHotkeyCode = "Aurakey.undoTypingHotkeyCode"
    case undoTypingHotkeyModifiers = "Aurakey.undoTypingHotkeyModifiers"
    case undoTypingHotkeyIsModifierOnly = "Aurakey.undoTypingHotkeyIsModifierOnly"
    case beepOnToggle = "Aurakey.beepOnToggle"

    // Input settings
    case inputMethod = "Aurakey.inputMethod"
    case codeTable = "Aurakey.codeTable"
    case modernStyle = "Aurakey.modernStyle"
    case spellCheckEnabled = "Aurakey.spellCheckEnabled"

    // Advanced settings
    case quickTelexEnabled = "Aurakey.quickTelexEnabled"
    case quickStartConsonantEnabled = "Aurakey.quickStartConsonantEnabled"
    case quickEndConsonantEnabled = "Aurakey.quickEndConsonantEnabled"
    case upperCaseFirstChar = "Aurakey.upperCaseFirstChar"
    case restoreIfWrongSpelling = "Aurakey.restoreIfWrongSpelling"
    case instantRestoreOnWrongSpelling = "Aurakey.instantRestoreOnWrongSpelling"

    case customConsonantEnabled = "Aurakey.customConsonantEnabled"
    case customConsonants = "Aurakey.customConsonants"
    case tempOffToolbarEnabled = "Aurakey.tempOffToolbarEnabled"
    case tempOffToolbarHotkeyCode = "Aurakey.tempOffToolbarHotkeyCode"
    case tempOffToolbarHotkeyModifiers = "Aurakey.tempOffToolbarHotkeyModifiers"
    case convertToolHotkeyCode = "Aurakey.convertToolHotkeyCode"
    case convertToolHotkeyModifiers = "Aurakey.convertToolHotkeyModifiers"

    // Macro settings
    case macroEnabled = "Aurakey.macroEnabled"
    case macroInEnglishMode = "Aurakey.macroInEnglishMode"
    case autoCapsMacro = "Aurakey.autoCapsMacro"
    case addSpaceAfterMacro = "Aurakey.addSpaceAfterMacro"
    case macros = "Aurakey.macros"

    // Smart switch settings
    case smartSwitchEnabled = "Aurakey.smartSwitchEnabled"
    case smartSwitchData = "Aurakey.smartSwitchData"          // JSON-encoded [String: Int] per-app language map

    // Debug settings
    case debugModeEnabled = "Aurakey.debugModeEnabled"
    case debugHotkeyCode = "Aurakey.debugHotkeyCode"
    case debugHotkeyModifiers = "Aurakey.debugHotkeyModifiers"
    case openDebugOnLaunch = "Aurakey.openDebugOnLaunch"

    // UI settings
    case startAtLogin = "Aurakey.startAtLogin"
    case menuBarIconStyle = "Aurakey.menuBarIconStyle"
    case autoCheckForUpdates = "Aurakey.autoCheckForUpdates"

    // Excluded apps
    case excludedApps = "Aurakey.excludedApps"

    // Input Source Management
    case inputSourceConfig = "Aurakey.inputSourceConfig"
    
    // Local data (macros, window title rules)
    case macrosData = "Aurakey.macrosData"
    case windowTitleRules = "Aurakey.windowTitleRules"
    case disabledBuiltInRules = "Aurakey.disabledBuiltInRules"        // Rules enabled by default, now disabled by user
    case enabledBuiltInRules = "Aurakey.enabledBuiltInRules"          // Rules disabled by default, now enabled by user
    
    // User dictionary (custom words to skip spell check)
    case userDictionaryWords = "Aurakey.userDictionaryWords"
    
    

}

// Note: Logging functions (logError, logWarning, etc.) are provided by Shared/DebugLogger.swift

/// Manager for shared settings
/// ARCHITECTURE: Uses plist file directly for reliable cross-process sync
class SharedSettings {
    
    // MARK: - Singleton
    
    static let shared = SharedSettings()
    
    // MARK: - Properties

    /// Flag to prevent notification spam during batch updates
    private var isBatchUpdating: Bool = false
    
    /// Default values for settings
    private let defaultValues: [String: Any] = [
        SharedSettingsKey.inputMethod.rawValue: InputMethod.telex.rawValue,
        SharedSettingsKey.codeTable.rawValue: CodeTable.unicode.rawValue,
        SharedSettingsKey.modernStyle.rawValue: false,
        SharedSettingsKey.spellCheckEnabled.rawValue: false,
        SharedSettingsKey.quickTelexEnabled.rawValue: false,
        SharedSettingsKey.restoreIfWrongSpelling.rawValue: true,
        SharedSettingsKey.smartSwitchEnabled.rawValue: true
    ]
    
    /// Cache of plist URL (computed once)
    private lazy var plistURL: URL? = {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAurakeyAppGroup) else {
            sharedLogWarning("Cannot get App Group container URL")
            return nil
        }
        
        let prefsDir = containerURL.appendingPathComponent("Library/Preferences")
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: prefsDir, withIntermediateDirectories: true)
        
        return prefsDir.appendingPathComponent("\(kAurakeyAppGroup).plist")
    }()
    
    // MARK: - Initialization

    private init() {}
    
    /// Public read-only access to the plist file path (for debug/diagnostics)
    var settingsFilePath: String {
        plistURL?.path ?? "(unavailable)"
    }

    // MARK: - Plist Read/Write Helpers
    
    /// Read the entire plist dictionary
    private func readPlistDict() -> [String: Any] {
        guard let url = plistURL,
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    /// Write the entire plist dictionary
    private func writePlistDict(_ dict: [String: Any]) {
        guard let url = plistURL else { return }
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
            try data.write(to: url)
        } catch {
            sharedLogError("Failed to write plist: \(error)")
        }
    }
    
    /// Read a Bool value from plist
    private func readBool(forKey key: String) -> Bool {
        let dict = readPlistDict()
        
        if let value = dict[key] as? Bool {
            return value
        }
        if let value = dict[key] as? Int {
            return value != 0
        }
        
        // Return default value if key not found
        return defaultValues[key] as? Bool ?? false
    }
    
    /// Write a Bool value to plist
    private func writeBool(_ value: Bool, forKey key: String) {
        var dict = readPlistDict()
        dict[key] = value
        writePlistDict(dict)
    }
    
    /// Read an Int value from plist
    private func readInt(forKey key: String) -> Int {
        let dict = readPlistDict()
        
        if let value = dict[key] as? Int {
            return value
        }
        
        // Return default value if key not found
        return defaultValues[key] as? Int ?? 0
    }
    
    /// Write an Int value to plist
    private func writeInt(_ value: Int, forKey key: String) {
        var dict = readPlistDict()
        dict[key] = value
        writePlistDict(dict)
    }
    
    /// Read a String value from plist
    private func readString(forKey key: String) -> String? {
        let dict = readPlistDict()
        return dict[key] as? String
    }
    
    /// Write a String value to plist
    private func writeString(_ value: String, forKey key: String) {
        var dict = readPlistDict()
        dict[key] = value
        writePlistDict(dict)
    }
    
    /// Read a Data value from plist
    private func readData(forKey key: String) -> Data? {
        let dict = readPlistDict()
        return dict[key] as? Data
    }
    
    /// Write a Data value to plist
    private func writeData(_ value: Data, forKey key: String) {
        var dict = readPlistDict()
        dict[key] = value
        writePlistDict(dict)
    }
    
    // MARK: - Hotkey Settings

    var toggleHotkeyCode: UInt16 {
        get { UInt16(readInt(forKey: SharedSettingsKey.toggleHotkeyCode.rawValue)) }
        set { writeInt(Int(newValue), forKey: SharedSettingsKey.toggleHotkeyCode.rawValue) }
    }

    var toggleHotkeyModifiers: UInt {
        get { UInt(readInt(forKey: SharedSettingsKey.toggleHotkeyModifiers.rawValue)) }
        set { writeInt(Int(newValue), forKey: SharedSettingsKey.toggleHotkeyModifiers.rawValue) }
    }

    var toggleHotkeyIsModifierOnly: Bool {
        get { readBool(forKey: SharedSettingsKey.toggleHotkeyIsModifierOnly.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.toggleHotkeyIsModifierOnly.rawValue) }
    }

    var undoTypingEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.undoTypingEnabled.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.undoTypingEnabled.rawValue) }
    }

    var undoTypingHotkeyCode: UInt16 {
        get { UInt16(readInt(forKey: SharedSettingsKey.undoTypingHotkeyCode.rawValue)) }
        set { writeInt(Int(newValue), forKey: SharedSettingsKey.undoTypingHotkeyCode.rawValue) }
    }

    var undoTypingHotkeyModifiers: UInt {
        get { UInt(readInt(forKey: SharedSettingsKey.undoTypingHotkeyModifiers.rawValue)) }
        set { writeInt(Int(newValue), forKey: SharedSettingsKey.undoTypingHotkeyModifiers.rawValue) }
    }

    var undoTypingHotkeyIsModifierOnly: Bool {
        get { readBool(forKey: SharedSettingsKey.undoTypingHotkeyIsModifierOnly.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.undoTypingHotkeyIsModifierOnly.rawValue) }
    }

    var beepOnToggle: Bool {
        get { readBool(forKey: SharedSettingsKey.beepOnToggle.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.beepOnToggle.rawValue) }
    }

    // MARK: - Input Method Settings

    var inputMethod: Int {
        get { readInt(forKey: SharedSettingsKey.inputMethod.rawValue) }
        set {
            writeInt(newValue, forKey: SharedSettingsKey.inputMethod.rawValue)
            notifySettingsChanged()
        }
    }

    var codeTable: Int {
        get { readInt(forKey: SharedSettingsKey.codeTable.rawValue) }
        set {
            writeInt(newValue, forKey: SharedSettingsKey.codeTable.rawValue)
            notifySettingsChanged()
        }
    }

    var modernStyle: Bool {
        get { readBool(forKey: SharedSettingsKey.modernStyle.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.modernStyle.rawValue)
            notifySettingsChanged()
        }
    }

    var spellCheckEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.spellCheckEnabled.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.spellCheckEnabled.rawValue)
            notifySettingsChanged()
        }
    }

    // MARK: - Advanced Settings

    var quickTelexEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.quickTelexEnabled.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.quickTelexEnabled.rawValue)
            notifySettingsChanged()
        }
    }

    var quickStartConsonantEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.quickStartConsonantEnabled.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.quickStartConsonantEnabled.rawValue)
            notifySettingsChanged()
        }
    }

    var quickEndConsonantEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.quickEndConsonantEnabled.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.quickEndConsonantEnabled.rawValue)
            notifySettingsChanged()
        }
    }

    var upperCaseFirstChar: Bool {
        get { readBool(forKey: SharedSettingsKey.upperCaseFirstChar.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.upperCaseFirstChar.rawValue) }
    }

    var restoreIfWrongSpelling: Bool {
        get { readBool(forKey: SharedSettingsKey.restoreIfWrongSpelling.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.restoreIfWrongSpelling.rawValue)
            notifySettingsChanged()
        }
    }

    var instantRestoreOnWrongSpelling: Bool {
        get { readBool(forKey: SharedSettingsKey.instantRestoreOnWrongSpelling.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.instantRestoreOnWrongSpelling.rawValue)
            notifySettingsChanged()
        }
    }


    var customConsonantEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.customConsonantEnabled.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.customConsonantEnabled.rawValue)
            notifySettingsChanged()
        }
    }

    var customConsonants: String {
        get { readString(forKey: SharedSettingsKey.customConsonants.rawValue) ?? Preferences.defaultCustomConsonants }
        set {
            writeString(newValue, forKey: SharedSettingsKey.customConsonants.rawValue)
            notifySettingsChanged()
        }
    }
    
    var tempOffToolbarEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.tempOffToolbarEnabled.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.tempOffToolbarEnabled.rawValue)
            notifyToolbarChanged()
        }
    }

    var tempOffToolbarHotkeyCode: UInt16 {
        get { UInt16(readInt(forKey: SharedSettingsKey.tempOffToolbarHotkeyCode.rawValue)) }
        set {
            writeInt(Int(newValue), forKey: SharedSettingsKey.tempOffToolbarHotkeyCode.rawValue)
            notifyToolbarChanged()
        }
    }

    var tempOffToolbarHotkeyModifiers: UInt {
        get { UInt(readInt(forKey: SharedSettingsKey.tempOffToolbarHotkeyModifiers.rawValue)) }
        set {
            writeInt(Int(newValue), forKey: SharedSettingsKey.tempOffToolbarHotkeyModifiers.rawValue)
            notifyToolbarChanged()
        }
    }

    var convertToolHotkeyCode: UInt16 {
        get { UInt16(readInt(forKey: SharedSettingsKey.convertToolHotkeyCode.rawValue)) }
        set {
            writeInt(Int(newValue), forKey: SharedSettingsKey.convertToolHotkeyCode.rawValue)
            notifyConvertToolHotkeyChanged()
        }
    }

    var convertToolHotkeyModifiers: UInt {
        get { UInt(readInt(forKey: SharedSettingsKey.convertToolHotkeyModifiers.rawValue)) }
        set {
            writeInt(Int(newValue), forKey: SharedSettingsKey.convertToolHotkeyModifiers.rawValue)
            notifyConvertToolHotkeyChanged()
        }
    }

    /// Notify that convert tool hotkey has changed
    private func notifyConvertToolHotkeyChanged() {
        guard !isBatchUpdating else { return }
        NotificationCenter.default.post(
            name: .convertToolHotkeyDidChange,
            object: nil
        )
    }

    /// Notify that toolbar settings have changed
    private func notifyToolbarChanged() {
        guard !isBatchUpdating else { return }
        NotificationCenter.default.post(
            name: .tempOffToolbarSettingsDidChange,
            object: nil
        )
    }

    // MARK: - Macro Settings

    var macroEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.macroEnabled.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.macroEnabled.rawValue)
            notifySettingsChanged()
        }
    }

    var macroInEnglishMode: Bool {
        get { readBool(forKey: SharedSettingsKey.macroInEnglishMode.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.macroInEnglishMode.rawValue) }
    }

    var autoCapsMacro: Bool {
        get { readBool(forKey: SharedSettingsKey.autoCapsMacro.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.autoCapsMacro.rawValue) }
    }

    var addSpaceAfterMacro: Bool {
        get { readBool(forKey: SharedSettingsKey.addSpaceAfterMacro.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.addSpaceAfterMacro.rawValue) }
    }

    func getMacros() -> Data? {
        return readData(forKey: SharedSettingsKey.macros.rawValue)
    }

    func setMacros(_ data: Data) {
        writeData(data, forKey: SharedSettingsKey.macros.rawValue)
        notifySettingsChanged()
    }

    // MARK: - Smart Switch Settings

    var smartSwitchEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.smartSwitchEnabled.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.smartSwitchEnabled.rawValue) }
    }
    
    // MARK: - Smart Switch Data
    
    func getSmartSwitchData() -> Data? {
        return readData(forKey: SharedSettingsKey.smartSwitchData.rawValue)
    }
    
    func setSmartSwitchData(_ data: Data) {
        writeData(data, forKey: SharedSettingsKey.smartSwitchData.rawValue)
    }

    // MARK: - Debug Settings

    var debugModeEnabled: Bool {
        get { readBool(forKey: SharedSettingsKey.debugModeEnabled.rawValue) }
        set {
            writeBool(newValue, forKey: SharedSettingsKey.debugModeEnabled.rawValue)
            notifyDebugSettingsChanged()
        }
    }

    var debugHotkeyCode: UInt16 {
        get { UInt16(readInt(forKey: SharedSettingsKey.debugHotkeyCode.rawValue)) }
        set {
            writeInt(Int(newValue), forKey: SharedSettingsKey.debugHotkeyCode.rawValue)
            notifyDebugSettingsChanged()
        }
    }

    var debugHotkeyModifiers: UInt {
        get { UInt(readInt(forKey: SharedSettingsKey.debugHotkeyModifiers.rawValue)) }
        set {
            writeInt(Int(newValue), forKey: SharedSettingsKey.debugHotkeyModifiers.rawValue)
            notifyDebugSettingsChanged()
        }
    }

    /// Open debug window automatically when app launches
    var openDebugOnLaunch: Bool {
        get { readBool(forKey: SharedSettingsKey.openDebugOnLaunch.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.openDebugOnLaunch.rawValue) }
    }

    /// Notify that debug settings have changed
    private func notifyDebugSettingsChanged() {
        guard !isBatchUpdating else { return }
        NotificationCenter.default.post(
            name: .debugSettingsDidChange,
            object: nil
        )
    }

    // MARK: - UI Settings

    var startAtLogin: Bool {
        get { readBool(forKey: SharedSettingsKey.startAtLogin.rawValue) }
        set { writeBool(newValue, forKey: SharedSettingsKey.startAtLogin.rawValue) }
    }

    var menuBarIconStyle: String {
        get { readString(forKey: SharedSettingsKey.menuBarIconStyle.rawValue) ?? "X" }
        set { writeString(newValue, forKey: SharedSettingsKey.menuBarIconStyle.rawValue) }
    }

    var autoCheckForUpdates: Bool {
        get {
            let dict = readPlistDict()
            // Default to true if key not found
            if let value = dict[SharedSettingsKey.autoCheckForUpdates.rawValue] as? Bool {
                return value
            }
            return true
        }
        set { writeBool(newValue, forKey: SharedSettingsKey.autoCheckForUpdates.rawValue) }
    }

    // MARK: - Excluded Apps

    func getExcludedApps() -> Data? {
        return readData(forKey: SharedSettingsKey.excludedApps.rawValue)
    }

    func setExcludedApps(_ data: Data) {
        writeData(data, forKey: SharedSettingsKey.excludedApps.rawValue)
    }

    // MARK: - Input Source Management

    func getInputSourceConfig() -> Data? {
        return readData(forKey: SharedSettingsKey.inputSourceConfig.rawValue)
    }

    func setInputSourceConfig(_ data: Data) {
        writeData(data, forKey: SharedSettingsKey.inputSourceConfig.rawValue)
    }
    
    // MARK: - Macros Data
    
    func getMacrosData() -> Data? {
        return readData(forKey: SharedSettingsKey.macrosData.rawValue)
    }
    
    func setMacrosData(_ data: Data) {
        writeData(data, forKey: SharedSettingsKey.macrosData.rawValue)
    }
    
    // MARK: - Window Title Rules
    
    func getWindowTitleRulesData() -> Data? {
        return readData(forKey: SharedSettingsKey.windowTitleRules.rawValue)
    }
    
    func setWindowTitleRulesData(_ data: Data) {
        writeData(data, forKey: SharedSettingsKey.windowTitleRules.rawValue)
    }
    
    // MARK: - Disabled Built-in Rules
    
    /// Get the list of disabled built-in rule names
    func getDisabledBuiltInRules() -> Set<String> {
        guard let data = readData(forKey: SharedSettingsKey.disabledBuiltInRules.rawValue),
              let names = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(names)
    }
    
    /// Set the list of disabled built-in rule names
    func setDisabledBuiltInRules(_ names: Set<String>) {
        if let data = try? JSONEncoder().encode(Array(names)) {
            writeData(data, forKey: SharedSettingsKey.disabledBuiltInRules.rawValue)
        }
    }
    
    /// Get the list of enabled built-in rule names (for rules that are disabled by default)
    func getEnabledBuiltInRules() -> Set<String> {
        guard let data = readData(forKey: SharedSettingsKey.enabledBuiltInRules.rawValue),
              let names = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(names)
    }
    
    /// Set the list of enabled built-in rule names (for rules that are disabled by default)
    func setEnabledBuiltInRules(_ names: Set<String>) {
        if let data = try? JSONEncoder().encode(Array(names)) {
            writeData(data, forKey: SharedSettingsKey.enabledBuiltInRules.rawValue)
        }
    }
    
    // MARK: - User Dictionary (Custom Words)
    
    /// Get the list of user-defined words (to skip spell check)
    func getUserDictionaryWords() -> Set<String> {
        guard let data = readData(forKey: SharedSettingsKey.userDictionaryWords.rawValue),
              let words = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(words)
    }
    
    /// Set the list of user-defined words
    func setUserDictionaryWords(_ words: Set<String>) {
        if let data = try? JSONEncoder().encode(Array(words).sorted()) {
            writeData(data, forKey: SharedSettingsKey.userDictionaryWords.rawValue)
            notifySettingsChanged()
        }
    }
    
    /// Add a word to the user dictionary
    func addUserDictionaryWord(_ word: String) {
        var words = getUserDictionaryWords()
        words.insert(word.lowercased().trimmingCharacters(in: .whitespaces))
        setUserDictionaryWords(words)
    }
    
    /// Remove a word from the user dictionary
    func removeUserDictionaryWord(_ word: String) {
        var words = getUserDictionaryWords()
        words.remove(word.lowercased().trimmingCharacters(in: .whitespaces))
        setUserDictionaryWords(words)
    }
    
    /// Check if a word exists in the user dictionary
    func isWordInUserDictionary(_ word: String) -> Bool {
        let words = getUserDictionaryWords()
        return words.contains(word.lowercased().trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Sync

    /// Synchronize settings to disk
    /// Note: With plist-only approach, settings are written immediately
    /// This function is kept for compatibility but does nothing
    func synchronize() {
        // No-op: plist writes are immediate
    }
    
    /// Force write all current settings to plist file
    /// This is used before Sparkle restarts the app after an update
    /// to ensure settings are saved to the current App Group container
    /// In case of App Group path change between versions, this ensures
    /// settings are written to the correct location
    func forceWriteCurrentSettings() {
        // Read the current plist dictionary
        let currentDict = readPlistDict()
        
        // If nothing to save, skip
        guard !currentDict.isEmpty else {
            sharedLogWarning("forceWriteCurrentSettings: No settings to save")
            return
        }
        
        // Force write it back to ensure the file exists and is up-to-date
        writePlistDict(currentDict)
        
        sharedLogSuccess("Force saved \(currentDict.count) settings to plist")
    }

    /// Notify that settings have changed (for observers)
    private func notifySettingsChanged() {
        // Skip notification if we're in batch update mode
        guard !isBatchUpdating else { return }

        // Post notification for local observers
        NotificationCenter.default.post(
            name: .sharedSettingsDidChange,
            object: nil
        )

        // Post distributed notification for cross-app communication
        DistributedNotificationCenter.default().post(
            name: .aurakeySettingsDidChange,
            object: nil
        )
    }
    
    // MARK: - Export/Import Settings
    
    /// Export all settings to a plist file
    /// - Returns: The exported plist data (XML format for human readability), or nil if export failed
    func exportSettings() -> Data? {
        var exportDict = readPlistDict()
        
        // Add metadata for version tracking
        exportDict["_exportVersion"] = 1
        exportDict["_exportDate"] = ISO8601DateFormatter().string(from: Date())
        exportDict["_appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        
        // Convert to XML plist for human readability
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: exportDict, format: .xml, options: 0)
            return data
        } catch {
            sharedLogError("Failed to export settings: \(error)")
            return nil
        }
    }
    
    /// Import settings from a plist file
    /// - Parameter data: The plist data to import
    /// - Returns: True if import was successful
    @discardableResult
    func importSettings(from data: Data) -> Bool {
        do {
            guard var importDict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                sharedLogError("Invalid plist format")
                return false
            }
            
            // Remove metadata keys before writing
            importDict.removeValue(forKey: "_exportVersion")
            importDict.removeValue(forKey: "_exportDate")
            importDict.removeValue(forKey: "_appVersion")
            
            // Write all settings
            writePlistDict(importDict)
            sharedLogSuccess("Imported settings successfully")
            
            // Notify observers
            notifySettingsChanged()
            // Post macros notification if available
            if let macrosNotification = Notification.Name(rawValue: "Aurakey.macrosDidChange") as Notification.Name? {
                NotificationCenter.default.post(name: macrosNotification, object: nil)
            }
            
            return true
        } catch {
            sharedLogError("Failed to import settings: \(error)")
            return false
        }
    }
    
    /// Get the suggested filename for export
    func getExportFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return "Aurakey-Settings-\(dateString).plist"
    }
    
    // MARK: - Reset to Factory Default
    
    /// Reset all settings to factory defaults by deleting the plist file.
    /// All getters will automatically fall back to `defaultValues`.
    /// This is the only method needed since ALL config is now centralized in the plist.
    @discardableResult
    func resetToDefaults() -> Bool {
        // Delete the plist file — all getters auto-fallback to defaultValues
        if let url = plistURL {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                sharedLogError("Failed to delete plist file: \(error)")
                return false
            }
        }
        
        // Notify all observers that settings have been reset
        notifySettingsChanged()
        notifyToolbarChanged()
        notifyDebugSettingsChanged()
        
        sharedLogSuccess("Settings reset to factory defaults")
        return true
    }
    
    // MARK: - Load/Save Preferences Object

    /// Load all settings as a Preferences object
    func loadPreferences() -> Preferences {
        var prefs = Preferences()

        // Hotkey settings
        let hotkeyCode = toggleHotkeyCode
        let hotkeyModifiers = toggleHotkeyModifiers
        if hotkeyCode != 0 || hotkeyModifiers != 0 {
            prefs.toggleHotkey = Hotkey(
                keyCode: hotkeyCode,
                modifiers: ModifierFlags(rawValue: hotkeyModifiers),
                isModifierOnly: toggleHotkeyIsModifierOnly
            )
        }
        prefs.undoTypingEnabled = undoTypingEnabled
        
        // Undo typing hotkey
        let undoHotkeyCode = undoTypingHotkeyCode
        let undoHotkeyModifiers = undoTypingHotkeyModifiers
        if undoHotkeyCode != 0 || undoHotkeyModifiers != 0 {
            prefs.undoTypingHotkey = Hotkey(
                keyCode: undoHotkeyCode,
                modifiers: ModifierFlags(rawValue: undoHotkeyModifiers),
                isModifierOnly: undoTypingHotkeyIsModifierOnly
            )
        }
        prefs.beepOnToggle = beepOnToggle

        // Input settings
        if let method = InputMethod(rawValue: inputMethod) {
            prefs.inputMethod = method
        }
        if let table = CodeTable(rawValue: codeTable) {
            prefs.codeTable = table
        }
        prefs.modernStyle = modernStyle
        prefs.spellCheckEnabled = spellCheckEnabled

        // Advanced settings
        prefs.quickTelexEnabled = quickTelexEnabled
        prefs.quickStartConsonantEnabled = quickStartConsonantEnabled
        prefs.quickEndConsonantEnabled = quickEndConsonantEnabled
        prefs.upperCaseFirstChar = upperCaseFirstChar
        prefs.restoreIfWrongSpelling = restoreIfWrongSpelling
        prefs.instantRestoreOnWrongSpelling = instantRestoreOnWrongSpelling

        // Custom consonants (2-prop: enabled + list)
        prefs.customConsonantEnabled = customConsonantEnabled
        prefs.customConsonants = customConsonants
        prefs.tempOffToolbarEnabled = tempOffToolbarEnabled

        // Temp off toolbar hotkey
        let toolbarHotkeyCode = tempOffToolbarHotkeyCode
        let toolbarHotkeyModifiers = tempOffToolbarHotkeyModifiers
        if toolbarHotkeyCode != 0 || toolbarHotkeyModifiers != 0 {
            prefs.tempOffToolbarHotkey = Hotkey(
                keyCode: toolbarHotkeyCode,
                modifiers: ModifierFlags(rawValue: toolbarHotkeyModifiers)
            )
        }

        // Convert tool hotkey
        let convertHotkeyCode = convertToolHotkeyCode
        let convertHotkeyModifiers = convertToolHotkeyModifiers
        if convertHotkeyCode != 0 || convertHotkeyModifiers != 0 {
            prefs.convertToolHotkey = Hotkey(
                keyCode: convertHotkeyCode,
                modifiers: ModifierFlags(rawValue: convertHotkeyModifiers)
            )
        }

        // Macro settings
        prefs.macroEnabled = macroEnabled
        prefs.macroInEnglishMode = macroInEnglishMode
        prefs.autoCapsMacro = autoCapsMacro
        prefs.addSpaceAfterMacro = addSpaceAfterMacro

        prefs.smartSwitchEnabled = smartSwitchEnabled

        // Debug
        prefs.debugModeEnabled = debugModeEnabled

        // UI settings
        prefs.startAtLogin = startAtLogin
        if let style = MenuBarIconStyle(rawValue: menuBarIconStyle) {
            prefs.menuBarIconStyle = style
        }
        prefs.autoCheckForUpdates = autoCheckForUpdates

        // Excluded apps
        if let data = getExcludedApps(),
           let apps = try? JSONDecoder().decode([ExcludedApp].self, from: data) {
            prefs.excludedApps = apps
        }

        // Debug settings
        prefs.debugModeEnabled = debugModeEnabled
        prefs.openDebugOnLaunch = openDebugOnLaunch
        let dbgHotkeyCode = debugHotkeyCode
        let dbgHotkeyModifiers = debugHotkeyModifiers
        if dbgHotkeyCode != 0 || dbgHotkeyModifiers != 0 {
            prefs.debugHotkey = Hotkey(
                keyCode: dbgHotkeyCode,
                modifiers: ModifierFlags(rawValue: dbgHotkeyModifiers)
            )
        }

        return prefs
    }

    /// Save a Preferences object to shared settings
    func savePreferences(_ prefs: Preferences) {
        // Enable batch mode to prevent notification spam
        isBatchUpdating = true
        defer {
            // Always disable batch mode when done, even if error occurs
            isBatchUpdating = false
        }

        // Hotkey settings
        toggleHotkeyCode = prefs.toggleHotkey.keyCode
        toggleHotkeyModifiers = prefs.toggleHotkey.modifiers.rawValue
        toggleHotkeyIsModifierOnly = prefs.toggleHotkey.isModifierOnly
        undoTypingEnabled = prefs.undoTypingEnabled
        
        // Undo typing hotkey (optional)
        if let undoHotkey = prefs.undoTypingHotkey {
            undoTypingHotkeyCode = undoHotkey.keyCode
            undoTypingHotkeyModifiers = undoHotkey.modifiers.rawValue
            undoTypingHotkeyIsModifierOnly = undoHotkey.isModifierOnly
        } else {
            // Clear the hotkey settings when nil (use default Esc)
            undoTypingHotkeyCode = 0
            undoTypingHotkeyModifiers = 0
            undoTypingHotkeyIsModifierOnly = false
        }
        beepOnToggle = prefs.beepOnToggle

        // Input settings
        inputMethod = prefs.inputMethod.rawValue
        codeTable = prefs.codeTable.rawValue
        modernStyle = prefs.modernStyle
        spellCheckEnabled = prefs.spellCheckEnabled

        // Advanced settings
        quickTelexEnabled = prefs.quickTelexEnabled
        quickStartConsonantEnabled = prefs.quickStartConsonantEnabled
        quickEndConsonantEnabled = prefs.quickEndConsonantEnabled
        upperCaseFirstChar = prefs.upperCaseFirstChar
        restoreIfWrongSpelling = prefs.restoreIfWrongSpelling
        instantRestoreOnWrongSpelling = prefs.instantRestoreOnWrongSpelling

        customConsonantEnabled = prefs.customConsonantEnabled
        customConsonants = prefs.customConsonants
        tempOffToolbarEnabled = prefs.tempOffToolbarEnabled
        tempOffToolbarHotkeyCode = prefs.tempOffToolbarHotkey.keyCode
        tempOffToolbarHotkeyModifiers = prefs.tempOffToolbarHotkey.modifiers.rawValue
        convertToolHotkeyCode = prefs.convertToolHotkey.keyCode
        convertToolHotkeyModifiers = prefs.convertToolHotkey.modifiers.rawValue

        // Macro settings
        macroEnabled = prefs.macroEnabled
        macroInEnglishMode = prefs.macroInEnglishMode
        autoCapsMacro = prefs.autoCapsMacro
        addSpaceAfterMacro = prefs.addSpaceAfterMacro

        smartSwitchEnabled = prefs.smartSwitchEnabled

        // Debug
        debugModeEnabled = prefs.debugModeEnabled
        openDebugOnLaunch = prefs.openDebugOnLaunch

        // UI settings
        startAtLogin = prefs.startAtLogin
        menuBarIconStyle = prefs.menuBarIconStyle.rawValue
        autoCheckForUpdates = prefs.autoCheckForUpdates

        // Excluded apps
        if let data = try? JSONEncoder().encode(prefs.excludedApps) {
            setExcludedApps(data)
        }

        // Batch update is done - settings are already written to plist via setters
        isBatchUpdating = false

        // Send ONE notification to notify observers
        notifySettingsChanged()

        // Also notify toolbar settings changed (so toolbar can be enabled/disabled immediately)
        notifyToolbarChanged()

        // Also notify convert tool hotkey changed
        notifyConvertToolHotkeyChanged()

        // Debug settings
        debugModeEnabled = prefs.debugModeEnabled
        debugHotkeyCode = prefs.debugHotkey.keyCode
        debugHotkeyModifiers = prefs.debugHotkey.modifiers.rawValue

        // Also notify debug settings changed
        notifyDebugSettingsChanged()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when shared settings change (local)
    static let sharedSettingsDidChange = Notification.Name("Aurakey.sharedSettingsDidChange")
    
    /// Posted when settings change (distributed, cross-app)
    static let aurakeySettingsDidChange = Notification.Name("Aurakey.settingsDidChange")
    
    /// Posted when temp off toolbar settings change (enabled/disabled or hotkey)
    static let tempOffToolbarSettingsDidChange = Notification.Name("Aurakey.tempOffToolbarSettingsDidChange")

    /// Posted when convert tool hotkey changes
    static let convertToolHotkeyDidChange = Notification.Name("Aurakey.convertToolHotkeyDidChange")

    /// Posted when debug settings change
    static let debugSettingsDidChange = Notification.Name("Aurakey.debugSettingsDidChange")
    
}
