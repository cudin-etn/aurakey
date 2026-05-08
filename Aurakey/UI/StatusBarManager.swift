import SwiftUI
import Cocoa
import Combine

class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    let viewModel: StatusBarViewModel
    private var menuBarIconStyle: MenuBarIconStyle = .aura
    var onCheckForUpdates: (() -> Void)?
    
    init(keyboardHandler: KeyboardEventHandler?, eventTapManager: EventTapManager?) {
        self.viewModel = StatusBarViewModel(
            keyboardHandler: keyboardHandler,
            eventTapManager: eventTapManager
        )
        self.menuBarIconStyle = SharedSettings.shared.loadPreferences().menuBarIconStyle
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else {
            return
        }
        
        updateStatusIcon()
        
        button.action = #selector(togglePopover)
        button.target = self
        
        setupPopover()
        
        viewModel.$isVietnameseEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
        
        viewModel.$currentInputMethod
            .receive(on: DispatchQueue.main)
            .sink { _ in
            }
            .store(in: &cancellables)
        
        viewModel.$currentCodeTable
            .receive(on: DispatchQueue.main)
            .sink { _ in
            }
            .store(in: &cancellables)
    }
    
    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        
        let contentView = StatusBarPopoverView(
            viewModel: viewModel,
            onCheckForUpdates: { [weak self] in
                self?.onCheckForUpdates?()
            },
            onDismiss: { [weak self] in
                self?.closePopover()
            }
        )
        
        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController
        
        popover.contentViewController?.view.wantsLayer = true
        
        self.popover = popover
    }
    
    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if popover.isShown {
            closePopover()
        } else {
            let contentView = StatusBarPopoverView(
                viewModel: viewModel,
                onCheckForUpdates: { [weak self] in
                    self?.onCheckForUpdates?()
                },
                onDismiss: { [weak self] in
                    self?.closePopover()
                }
            )
            let hostingController = NSHostingController(rootView: contentView)
            popover.contentViewController = hostingController
            
            NSApp.activate(ignoringOtherApps: true)
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            popover.contentViewController?.view.window?.makeKey()
            
            startEventMonitor()
        }
    }
    
    private func closePopover() {
        popover?.performClose(nil)
        stopEventMonitor()
    }
    
    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }
    
    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        
        switch menuBarIconStyle {
        case .aura:
            if let customImage = NSImage(named: "MenuBarIcon") {
                customImage.isTemplate = true
                button.image = customImage
            }
        case .v:
            drawVStatusIcon(on: button)
        }
    }
    
    private func drawVStatusIcon(on button: NSStatusBarButton) {
        let isActive = viewModel.isVietnameseEnabled
        let iconText = isActive ? "V" : "E"
        let size = NSSize(width: 22, height: 22)
        
        let teal = CGColor(red: 0x14/255, green: 0xC8/255, blue: 0xC0/255, alpha: 1)
        let cyan = CGColor(red: 0x00/255, green: 0xD4/255, blue: 0xFF/255, alpha: 1)
        let tealLight = CGColor(red: 0x4D/255, green: 0xE0/255, blue: 0xD8/255, alpha: 1)
        
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            
            let inset: CGFloat = 2.0
            let borderRect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
            let borderPath = CGPath(roundedRect: borderRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            
            if isActive {
                ctx.addPath(borderPath)
                ctx.clip()
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let colors = [tealLight, teal, cyan] as CFArray
                let locs: [CGFloat] = [0, 0.45, 1]
                if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locs) {
                    ctx.drawLinearGradient(gradient, start: CGPoint(x: borderRect.minX, y: borderRect.minY),
                                           end: CGPoint(x: borderRect.maxX, y: borderRect.maxY), options: [])
                }
                
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: NSColor.white
                ]
                let textSize = (iconText as NSString).size(withAttributes: textAttributes)
                let textRect = NSRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                (iconText as NSString).draw(in: textRect, withAttributes: textAttributes)
            } else {
                ctx.addPath(borderPath)
                ctx.setStrokeColor(CGColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1))
                ctx.setLineWidth(1.2)
                ctx.strokePath()
                
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                let textSize = (iconText as NSString).size(withAttributes: textAttributes)
                let textRect = NSRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                (iconText as NSString).draw(in: textRect, withAttributes: textAttributes)
            }
            return true
        }
        button.image = image
    }
    
    func updateHotkeyDisplay(_ hotkey: Hotkey) {
        viewModel.updateHotkeyDisplay(hotkey)
    }
    
    func updateMenuBarIconStyle(_ style: MenuBarIconStyle) {
        menuBarIconStyle = style
        updateStatusIcon()
    }
    
    private var cancellables = Set<AnyCancellable>()
}
