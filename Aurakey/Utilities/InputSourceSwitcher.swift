//
//  InputSourceSwitcher.swift
//  Aurakey
//
//  Utility to switch between input sources programmatically
//

import Carbon
import Cocoa

class InputSourceSwitcher {
    
    static let shared = InputSourceSwitcher()
    
    /// Switch to a specific input source by bundle identifier
    /// - Parameter bundleId: The bundle identifier of the input source
    /// - Returns: true if successfully switched, false otherwise
    func selectInputSource(bundleId: String) -> Bool {
        let filter: [String: Any] = [
            kTISPropertyBundleID as String: bundleId
        ]

        guard let sourceList = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource],
              let source = sourceList.first else {
            return false
        }

        let result = TISSelectInputSource(source)
        return result == noErr
    }

    /// Get currently selected input source bundle ID
    func getCurrentInputSourceId() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        
        if let bundleId = TISGetInputSourceProperty(source, kTISPropertyBundleID) {
            return Unmanaged<CFString>.fromOpaque(bundleId).takeUnretainedValue() as String
        }
        
        return nil
    }
    
    /// Get list of all enabled keyboard input sources
    func getEnabledInputSources() -> [(bundleId: String, name: String)] {
        var result: [(bundleId: String, name: String)] = []
        
        // Get all enabled input sources
        let filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsEnabled as String: true
        ]
        
        guard let sourceList = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
            return result
        }
        
        for source in sourceList {
            var bundleId = ""
            var name = ""
            
            if let bundleIdRef = TISGetInputSourceProperty(source, kTISPropertyBundleID) {
                bundleId = Unmanaged<CFString>.fromOpaque(bundleIdRef).takeUnretainedValue() as String
            }
            
            if let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                name = Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String
            }
            
            if !bundleId.isEmpty {
                result.append((bundleId: bundleId, name: name))
            }
        }
        
        return result
    }
}
