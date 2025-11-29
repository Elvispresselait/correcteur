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
                .frame(minWidth: 450, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 700)

        // Fenêtre de préférences (Cmd+,)
        Settings {
            PreferencesWindow()
        }
    }
}

