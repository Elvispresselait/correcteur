//
//  MenuBarMenu.swift
//  Correcteur Pro
//
//  Menu déroulant pour l'icône de la barre de menu
//

import SwiftUI

struct MenuBarMenu: View {
    @Environment(\.openWindow) var openWindow

    var body: some View {
        // Ouvrir la fenêtre principale
        Button("Ouvrir Correcteur Pro") {
            openMainWindow()
        }
        .keyboardShortcut("o", modifiers: .command)
        .task {
            // Configurer WindowOpener ici car MenuBarExtra est TOUJOURS actif
            // (contrairement à ContentView qui est détruit quand la fenêtre ferme)
            WindowOpener.shared.openMainWindowAction = { [openWindow] in
                openWindow(id: "main")
            }
            DebugLogger.shared.log("📱 WindowOpener configuré depuis MenuBarMenu", category: "System")
        }

        Divider()

        // Actions de capture
        Button("Capturer zone (⌥⇧S)") {
            GlobalHotKeyManager.shared.onSelectionCapture?()
        }

        Button("Capturer écran (⌥⇧X)") {
            GlobalHotKeyManager.shared.onMainDisplayCapture?()
        }

        Divider()

        // Préférences
        SettingsLink {
            Text("Préférences...")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        // Quitter
        Button("Quitter Correcteur Pro") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    /// Ouvre la fenêtre principale et l'active
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
    }
}

#Preview {
    MenuBarMenu()
}
