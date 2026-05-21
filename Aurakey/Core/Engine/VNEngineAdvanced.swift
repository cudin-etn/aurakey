//
//  VNEngineAdvanced.swift
//  Aurakey
//
//  Advanced features implementation for VNEngine
//  Ported from OpenKey Engine.cpp
//

import Foundation

extension VNEngine {
    // MARK: - Upper Case First Character

    /// Auto capitalize first character after sentence end
    func upperCaseFirstCharacter() {
        guard buffer.count >= 1 else { return }

        let firstEntry = buffer[0]
        let keyCode = firstEntry.keyCode

        guard vietnameseData.isLetter(keyCode) else { return }
        guard !firstEntry.isCaps else { return }

        let charAlreadyOnScreen = hookState.code != UInt8(vDoNothing)

        buffer[0].isCaps = true

        hookState.code = UInt8(vWillProcess)
        hookState.backspaceCount = charAlreadyOnScreen ? buffer.count : 0
        hookState.newCharCount = buffer.count

        for i in 0..<buffer.count {
            hookState.charData[buffer.count - 1 - i] = getCharacterCode(buffer[i].processedData)
        }

        logCallback?("Upper Case First Char: Applied (backspace=\(hookState.backspaceCount))")
    }

    // MARK: - Restore If Wrong Spelling

    /// Check and restore if word has wrong spelling
    @discardableResult
    func checkRestoreIfWrongSpelling(handleCode: Int) -> Bool {
        guard tempDisableKey else { return false }
        guard !buffer.isEmpty else { return false }

        if shouldSkipRestoreForSpecialPattern() {
            logCallback?("Restore Wrong Spelling: Skipping (special pattern)")
            return false
        }

        let originalKeystrokes = buffer.getKeystrokeSequence()
        guard !originalKeystrokes.isEmpty else { return false }

        hookState.code = UInt8(handleCode)
        hookState.backspaceCount = buffer.count
        hookState.newCharCount = originalKeystrokes.count

        for (i, keystroke) in originalKeystrokes.enumerated() {
            var charCode = UInt32(keystroke.keyCode)
            if keystroke.isCaps {
                charCode |= VNEngine.CAPS_MASK
            }
            hookState.charData[originalKeystrokes.count - 1 - i] = charCode
        }

        logCallback?("Restore Wrong Spelling: Restoring \(originalKeystrokes.count) chars in actual typing order")

        if handleCode == vRestoreAndStartNewSession {
            reset()
        }

        return true
    }

    // MARK: - Special Pattern Detection

    /// Check if current buffer looks like an emoji autocomplete pattern
    private func shouldSkipRestoreForSpecialPattern() -> Bool {
        guard !buffer.isEmpty else { return false }

        if buffer.count == 1 {
            logCallback?("Special Pattern: Single char, skipping")
            return true
        }

        let firstKeyCode = buffer.keyCode(at: 0)
        if !vietnameseData.isLetter(firstKeyCode) {
            logCallback?("Special Pattern: First char not letter, skipping")
            return true
        }

        return false
    }
}
