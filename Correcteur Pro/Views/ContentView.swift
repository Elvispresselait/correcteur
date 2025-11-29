//
//  ContentView.swift
//  Correcteur Pro
//
//  Vue principale de l'application avec sidebar et zone de chat
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var debugLogger = DebugLogger.shared
    @State private var isSidebarVisible: Bool = true
    @State private var inputText: String = ""

    private let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: "020815"),
            Color(hex: "07152C"),
            Color(hex: "0F2D4F")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if isSidebarVisible {
                        SidebarView(viewModel: viewModel)
                            .frame(width: 230)
                            .transition(.move(edge: .leading))
                    }

                    ChatView(
                        viewModel: viewModel,
                        isSidebarVisible: $isSidebarVisible,
                        inputText: $inputText
                    )
                }
                .padding(0)
                .background(
                    Rectangle()
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            Rectangle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 40, x: 0, y: 20)
                )

                // Console de debug (si activée)
                if debugLogger.isEnabled {
                    DebugConsoleView()
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .onAppear {
            setupGlobalHotKey()

            // DIAGNOSTIC: Tester le DebugLogger au démarrage
            print("🔍 [DIAGNOSTIC] onAppear appelé, isEnabled=\(debugLogger.isEnabled), messages.count=\(debugLogger.messages.count)")

            // Forcer l'ajout de logs de test
            DebugLogger.shared.log("🚀 [System] Application démarrée", category: "System")
            DebugLogger.shared.log("📋 [System] Console initialisée avec \(debugLogger.messages.count) messages", category: "System")

            // Vérifier après 0.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔍 [DIAGNOSTIC] Après 0.5s: isEnabled=\(debugLogger.isEnabled), messages.count=\(debugLogger.messages.count)")
                DebugLogger.shared.log("✅ [System] Test logger après 0.5s - Si tu vois ce message, le logger fonctionne!", category: "System")
            }
        }
    }

    // MARK: - Global HotKey Setup

    /// Configure les raccourcis globaux pour la capture d'écran
    private func setupGlobalHotKey() {
        // Callback pour écran principal
        GlobalHotKeyManager.shared.onMainDisplayCapture = {
            // TODO: Réactiver quand sendScreenCapture sera implémenté
            print("📸 Capture d'écran principal demandée")
        }

        // Callback pour tous les écrans
        GlobalHotKeyManager.shared.onAllDisplaysCapture = {
            print("⚠️ Capture de tous les écrans pas encore implémentée")
        }

        // Callback pour zone sélectionnée
        GlobalHotKeyManager.shared.onSelectionCapture = {
            // TODO: Réactiver quand sendScreenCapture sera implémenté
            print("📸 Capture de zone demandée")
        }

        // Enregistrer tous les raccourcis depuis les préférences
        GlobalHotKeyManager.shared.registerAllHotKeys()
    }
}


#Preview("Application complète") {
    ContentView()
        .frame(width: 600, height: 700)
}

#Preview("Mode portrait") {
    ContentView()
        .frame(width: 400, height: 700)
}

#Preview("Mode large") {
    ContentView()
        .frame(width: 800, height: 900)
}

