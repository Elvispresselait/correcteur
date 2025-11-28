//
//  CorrecteurProApp.swift
//  Correcteur Pro
//
//  Point d'entrée de l'application
//

import SwiftUI

@main
struct CorrecteurProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 700)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Préférences...") {
                    // Notification pour ouvrir les préférences
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

