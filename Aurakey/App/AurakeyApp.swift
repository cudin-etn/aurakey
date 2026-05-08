//
//  AurakeyApp.swift
//  Aurakey
//
//  Main app entry point
//

import SwiftUI
import Foundation

@main
struct AurakeyApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // AurakeyApp initialized
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

