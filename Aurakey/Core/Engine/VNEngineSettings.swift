//
//  VNEngineSettings.swift
//  Aurakey
//
//  Settings structure for VNEngine
//

import Foundation

extension VNEngine {
    
    /// Settings structure for configuring the engine
    struct EngineSettings {
        // Basic settings
        var inputMethod: InputMethod = .telex
        var codeTable: CodeTable = .unicode
        var modernStyle: Bool = true
        var spellCheckEnabled: Bool = true
        
        // Advanced features
        var upperCaseFirstChar: Bool = false
        var restoreIfWrongSpelling: Bool = true

        var customConsonants: Set<UInt16> = []
        
        // Macro settings
        var macroEnabled: Bool = false
        var macroInEnglishMode: Bool = false
        var autoCapsMacro: Bool = false
        var addSpaceAfterMacro: Bool = false
        
        // Smart switch
        var smartSwitchEnabled: Bool = true
    }
    
    /// Update engine settings
    func updateSettings(_ settings: EngineSettings) {
        // Map InputMethod to vInputType
        switch settings.inputMethod {
        case .telex:
            vInputType = 0
        case .vni:
            vInputType = 1
        case .simpleTelex1:
            vInputType = 2
        case .simpleTelex2:
            vInputType = 3
        }
        
        // Map CodeTable to vCodeTable
        vCodeTable = settings.codeTable.rawValue
        
        // Basic settings
        vUseModernOrthography = settings.modernStyle ? 1 : 0
        vCheckSpelling = settings.spellCheckEnabled ? 1 : 0
        useSpellCheckingBefore = settings.spellCheckEnabled  // Sync internal state to prevent restoration to old value
        
        // Advanced features
        vUpperCaseFirstChar = settings.upperCaseFirstChar ? 1 : 0
        vRestoreIfWrongSpelling = settings.restoreIfWrongSpelling ? 1 : 0

        vCustomConsonants = settings.customConsonants
        
        // Macro settings
        vUseMacro = settings.macroEnabled ? 1 : 0
        vUseMacroInEnglishMode = settings.macroInEnglishMode ? 1 : 0
        vAutoCapsMacro = settings.autoCapsMacro ? 1 : 0
        vAddSpaceAfterMacro = settings.addSpaceAfterMacro ? 1 : 0
        
        // Smart switch
        vUseSmartSwitchKey = settings.smartSwitchEnabled ? 1 : 0
    }
    
    /// Get current settings
    var settings: EngineSettings {
        var settings = EngineSettings()
        
        // Map vInputType to InputMethod
        switch vInputType {
        case 0:
            settings.inputMethod = .telex
        case 1:
            settings.inputMethod = .vni
        case 2:
            settings.inputMethod = .simpleTelex1
        case 3:
            settings.inputMethod = .simpleTelex2
        default:
            settings.inputMethod = .telex
        }
        
        // Map vCodeTable to CodeTable
        settings.codeTable = CodeTable(rawValue: vCodeTable) ?? .unicode
        
        // Basic settings
        settings.modernStyle = vUseModernOrthography == 1
        settings.spellCheckEnabled = vCheckSpelling == 1
        
        // Advanced features
        settings.upperCaseFirstChar = vUpperCaseFirstChar == 1
        settings.restoreIfWrongSpelling = vRestoreIfWrongSpelling == 1
        settings.customConsonants = vCustomConsonants
        
        // Macro settings
        settings.macroEnabled = vUseMacro == 1
        settings.macroInEnglishMode = vUseMacroInEnglishMode == 1
        settings.autoCapsMacro = vAutoCapsMacro == 1
        settings.addSpaceAfterMacro = vAddSpaceAfterMacro == 1
        
        // Smart switch
        settings.smartSwitchEnabled = vUseSmartSwitchKey == 1
        
        return settings
    }
}
