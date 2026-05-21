//
//  FloatingToolbarPositioning.swift
//  Aurakey
//
//  Shared positioning logic for floating toolbar panels
//  Handles cursor detection, AX coordinate conversion, and screen-aware placement
//

import Cocoa
import SwiftUI

/// Provides cursor-aware positioning for floating NSPanel toolbars
/// Handles AX-based cursor detection, coordinate conversion, and multi-monitor placement
class FloatingToolbarPositioning {
    
    // MARK: - Panel Factory
    
    /// Create a standard floating toolbar panel with the given SwiftUI view
    /// Configures a non-activating, transparent, always-on-top panel sized to fit content
    static func createPanel<V: View>(rootView: V, initialWidth: CGFloat = 80) -> NSPanel {
        let hostingController = NSHostingController(rootView: rootView)
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: 44),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.contentViewController = hostingController
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // We use SwiftUI shadow
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Size to fit content
        if let contentSize = hostingController.view.fittingSize as NSSize? {
            panel.setContentSize(contentSize)
        }
        
        return panel
    }
    
    // MARK: - Position Near Cursor
    
    /// Position the given panel near the text cursor
    /// Falls back to mouse position if caret position cannot be determined
    /// - Parameters:
    ///   - panel: The panel to position
    ///   - cursorGap: Gap between panel and cursor position (points)
    ///   - mouseGap: Gap between panel and mouse position (points)
    static func positionNearCursor(_ panel: NSPanel, cursorGap: CGFloat = 4, mouseGap: CGFloat = 8) {
        if let caretRect = getTextInsertionRect() {
            positionPanel(panel, relativeTo: caretRect, gap: cursorGap)
        } else {
            let mouseLocation = NSEvent.mouseLocation
            let mouseRect = NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 20)
            positionPanel(panel, relativeTo: mouseRect, gap: mouseGap)
        }
    }

    /// Try to position using the frontmost app's focused element.
    /// Helpful for browsers and web apps where the content caret is not exposed.
    static func positionUsingFocusedElementBounds(_ panel: NSPanel, gap: CGFloat = 8) -> Bool {
        guard let focusedElement = AXHelper.getFocusedElement() else { return false }

        if let anchor = bestAnchorRect(for: focusedElement) {
            positionPanel(panel, relativeTo: anchor, gap: gap)
            return true
        }

        return false
    }

    enum AnchorConfidence {
        case high
        case medium
        case low
    }

    /// Resolve the best anchor rect for a focused element.
    /// Preference order:
    /// 1) Exact caret bounds
    /// 2) Visible-range fallback
    /// 3) Focused element frame, if it looks like a text input
    /// 4) Browser/web-area heuristics
    static func bestAnchorRect(for element: AXUIElement) -> NSRect? {
        bestAnchor(for: element)?.rect
    }

    static func bestAnchor(for element: AXUIElement) -> (rect: NSRect, confidence: AnchorConfidence)? {
        if let caretRect = getCursorBoundsViaRange(element) {
            return (caretRect, .high)
        }

        if let insertionRect = getInsertionPointBounds(element) {
            return (insertionRect, .medium)
        }

        if let rect = elementBoundsAnchor(element), isTextLikeElement(element) {
            return (rect, .low)
        }

        if let rect = elementBoundsAnchor(element, biasTowardTop: true), isBrowserOrWebArea(element) {
            return (rect, .low)
        }

        return nil
    }

    private static func elementBoundsAnchor(_ element: AXUIElement, biasTowardTop: Bool = false) -> NSRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionValue = positionRef,
              let sizeValue = sizeRef else {
            return nil
        }

        var axPosition = CGPoint.zero
        var axSize = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &axPosition),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &axSize) else {
            return nil
        }

        guard let cocoaRect = convertAXToCocoaCoordinates(CGRect(origin: axPosition, size: axSize)) else {
            return nil
        }

        let insetY = min(10, max(2, cocoaRect.height * 0.18))
        let anchorY = biasTowardTop ? cocoaRect.maxY - insetY : cocoaRect.minY + insetY
        return NSRect(
            x: cocoaRect.midX - 1,
            y: anchorY,
            width: 2,
            height: max(cocoaRect.height * 0.22, 18)
        )
    }

    private static func isTextLikeElement(_ element: AXUIElement) -> Bool {
        let role = (AXHelper.getString(element, attribute: kAXRoleAttribute) ?? "").lowercased()
        let subrole = (AXHelper.getString(element, attribute: kAXSubroleAttribute) ?? "").lowercased()
        let description = (AXHelper.getString(element, attribute: kAXDescriptionAttribute) ?? "").lowercased()
        let identifier = (AXHelper.getString(element, attribute: "AXIdentifier") ?? "").lowercased()

        return role.contains("textfield") || role.contains("text area") || role.contains("textview") ||
               role.contains("editable") || subrole.contains("searchfield") || subrole.contains("textarea") ||
               description.contains("text") || description.contains("search") || identifier.contains("input") ||
               identifier.contains("editor")
    }

    private static func isBrowserOrWebArea(_ element: AXUIElement) -> Bool {
        let role = (AXHelper.getString(element, attribute: kAXRoleAttribute) ?? "").lowercased()
        let subrole = (AXHelper.getString(element, attribute: kAXSubroleAttribute) ?? "").lowercased()
        let description = (AXHelper.getString(element, attribute: kAXDescriptionAttribute) ?? "").lowercased()
        return role.contains("webarea") || role.contains("browser") || subrole.contains("webarea") || description.contains("web")
    }

    /// Position above the text insertion point (caret). Does not use mouse position.
    /// - Returns: `true` when a caret/text-field anchor was found.
    @discardableResult
    static func positionAboveTextCaret(_ panel: NSPanel, gap: CGFloat = 10) -> Bool {
        guard let caretRect = getTextInsertionRect() else { return false }
        positionPanel(panel, relativeTo: caretRect, gap: gap)
        return true
    }

    /// Caret anchor for HUD/toolbars — prefers AX insertion point over mouse.
    static func getTextInsertionRect() -> NSRect? {
        if let caretRect = getCursorRectFromAccessibility() {
            let lineHeight = max(caretRect.height, 16)
            return NSRect(
                x: caretRect.midX - 1,
                y: caretRect.minY,
                width: 2,
                height: lineHeight
            )
        }
        if let fallbackRect = getFocusedTextFieldCaretFallbackRect() {
            return fallbackRect
        }
        return nil
    }

    /// Fallback when range bounds are unavailable: anchor near the focused text field's typing line.
    private static func getFocusedTextFieldCaretFallbackRect() -> NSRect? {
        guard let element = AXHelper.getFocusedElement() else { return nil }

        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionValue = positionRef,
              let sizeValue = sizeRef else {
            return nil
        }

        var axPosition = CGPoint.zero
        var axSize = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &axPosition),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &axSize) else {
            return nil
        }

        let axRect = CGRect(origin: axPosition, size: axSize)
        guard let cocoaRect = convertAXToCocoaCoordinates(axRect) else { return nil }

        let lineHeight: CGFloat = 18
        let insetY: CGFloat = min(8, max(2, cocoaRect.height * 0.15))
        return NSRect(
            x: cocoaRect.midX - 1,
            y: cocoaRect.minY + insetY,
            width: 2,
            height: lineHeight
        )
    }
    
    // MARK: - Panel Positioning
    
    /// Position panel relative to a target rect, keeping it on-screen
    /// Places panel above target by default, below if not enough space above
    static func positionPanel(_ panel: NSPanel, relativeTo targetRect: NSRect, gap: CGFloat) {
        let panelSize = panel.frame.size
        
        // Center horizontally on target cursor position
        var x = targetRect.origin.x - panelSize.width / 2 + targetRect.width / 2
        
        // Position ABOVE the target (like macOS Fn popup)
        // In Cocoa coords: higher Y = above
        var y = targetRect.origin.y + targetRect.height + gap
        
        // Find the screen that contains the target position
        let targetPoint = NSPoint(x: targetRect.midX, y: targetRect.midY)
        var containingScreen: NSScreen? = nil
        
        for screen in NSScreen.screens {
            if screen.frame.contains(targetPoint) {
                containingScreen = screen
                break
            }
        }
        
        // If no screen contains the point, find the nearest screen
        if containingScreen == nil {
            containingScreen = NSScreen.screens.min(by: { screen1, screen2 in
                let dist1 = distanceToScreen(point: targetPoint, screen: screen1)
                let dist2 = distanceToScreen(point: targetPoint, screen: screen2)
                return dist1 < dist2
            })
        }
        
        if let screen = containingScreen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            
            // Adjust horizontal position to stay within screen bounds
            x = max(screenFrame.minX + 10, min(x, screenFrame.maxX - panelSize.width - 10))
            
            // If toolbar would go above screen top, position below target instead
            if y + panelSize.height > screenFrame.maxY {
                y = targetRect.origin.y - panelSize.height - gap
            }
            
            // Ensure not below screen bottom
            if y < screenFrame.minY {
                y = screenFrame.minY + 10
            }
        }
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    // MARK: - Screen Distance
    
    /// Calculate shortest distance from a point to a screen's frame
    static func distanceToScreen(point: NSPoint, screen: NSScreen) -> CGFloat {
        let frame = screen.frame
        let clampedX = max(frame.minX, min(point.x, frame.maxX))
        let clampedY = max(frame.minY, min(point.y, frame.maxY))
        let dx = point.x - clampedX
        let dy = point.y - clampedY
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - AX Cursor Detection
    
    /// Get cursor rectangle from focused text element via Accessibility API
    /// Returns coordinates in Cocoa screen space (origin at bottom-left)
    /// Tries three methods: AXBoundsForRange, insertion point bounds, then falls back to nil
    static func getCursorRectFromAccessibility() -> NSRect? {
        // Get focused element
        guard let axElement = AXHelper.getFocusedElement() else {
            return nil
        }
        
        // Try Method 1: Get cursor position via AXBoundsForRange (works in most apps)
        if let cursorRect = getCursorBoundsViaRange(axElement) {
            return cursorRect
        }
        
        // Method 2: Try visible character range bounds (useful for editors
        // that don't support AXBoundsForRange for the cursor position)
        if let insertionRect = getInsertionPointBounds(axElement) {
            return insertionRect
        }
        
        // Fallback: Return nil to use mouse position
        return nil
    }
    
    /// Try to get insertion point bounds by combining visible range with element bounds
    static func getInsertionPointBounds(_ element: AXUIElement) -> NSRect? {
        // Get visible character range to estimate line height
        guard let visibleRangeRef = AXHelper.getRaw(element, attribute: kAXVisibleCharacterRangeAttribute) else {
            return nil
        }
        
        // Try to get bounds for visible range (gives us element content area)
        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            visibleRangeRef,
            &boundsRef
        ) == .success,
              let boundsValue = boundsRef else {
            return nil
        }
        
        var axBounds = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &axBounds) else {
            return nil
        }
        
        // Validate bounds - some apps return invalid bounds (width=0, height=0)
        if axBounds.width == 0 && axBounds.height == 0 {
            return nil
        }
        
        return convertAXToCocoaCoordinates(axBounds)
    }
    
    /// Get cursor bounds using AXBoundsForRangeParameterizedAttribute
    static func getCursorBoundsViaRange(_ element: AXUIElement) -> NSRect? {
        // Get selected text range (cursor position)
        guard let rangeValue = AXHelper.getRaw(element, attribute: kAXSelectedTextRangeAttribute) else {
            return nil
        }
        
        // Get bounds for the cursor position
        var boundsRef: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsRef
        )
        
        if boundsResult != .success {
            return nil
        }
        
        guard let boundsValue = boundsRef else {
            return nil
        }
        
        // Extract CGRect from AXValue
        var axBounds = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &axBounds) else {
            return nil
        }
        
        // Validate bounds - check if both width AND height are 0
        if axBounds.width == 0 && axBounds.height == 0 {
            return nil
        }
        
        // If height is 0 but we have valid position, assume default line height
        if axBounds.height == 0 {
            axBounds.size.height = 18
        }
        
        let result = convertAXToCocoaCoordinates(axBounds)
        
        guard let convertedRect = result else {
            return nil
        }
        
        // Validate: Check if the converted rect falls within any screen
        // This catches coordinate conversion errors on multi-monitor setups
        let centerPoint = NSPoint(x: convertedRect.midX, y: convertedRect.midY)
        var isOnAnyScreen = false
        for screen in NSScreen.screens {
            // Allow some tolerance for cursors at screen edges
            let expandedFrame = screen.frame.insetBy(dx: -100, dy: -100)
            if expandedFrame.contains(centerPoint) {
                isOnAnyScreen = true
                break
            }
        }
        
        if !isOnAnyScreen {
            return nil
        }
        
        return convertedRect
    }
    
    // MARK: - Coordinate Conversion
    
    /// Convert AX coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)
    static func convertAXToCocoaCoordinates(_ axRect: CGRect) -> NSRect? {
        guard let primaryScreen = NSScreen.screens.first else {
            return nil
        }
        
        // Flip Y axis using primary screen height as pivot
        let primaryHeight = primaryScreen.frame.height
        let cocoaY = primaryHeight - axRect.origin.y - axRect.height
        let cocoaX = axRect.origin.x
        
        return NSRect(
            x: cocoaX,
            y: cocoaY,
            width: axRect.width,
            height: axRect.height
        )
    }
}
