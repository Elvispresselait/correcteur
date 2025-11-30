//
//  ContentView.swift
//  Correcteur Pro
//
//  Vue principale de l'application avec sidebar et zone de chat
//

import SwiftUI

// MARK: - Content View

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var debugLogger = DebugLogger.shared
    @State private var isSidebarVisible: Bool = true
    @State private var inputText: String = ""
    @State private var isPromptEditorOpen: Bool = false

    /// Seuil de largeur pour passer en mode colonne (éditeur à droite)
    /// 1000px permet d'être en mode compact sur la moitié d'un écran 1920x1080 (960px)
    private let columnModeThreshold: CGFloat = 1000

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
        GeometryReader { geometry in
            let isColumnMode = geometry.size.width >= columnModeThreshold

            ZStack {
                // Helper pour rendre la fenêtre transparente
                TransparentWindowHelper()
                    .frame(width: 0, height: 0)

                // Couche 1 : Effet de flou (verre dépoli)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()

                // Couche 2 : Dégradé avec légère transparence
                backgroundGradient
                    .opacity(0.80) // 20% de transparence pour voir derrière
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Sidebar
                        if isSidebarVisible {
                            SidebarView(viewModel: viewModel)
                                .frame(width: 230)
                                .transition(.move(edge: .leading))
                        }

                        // Zone de chat
                        ChatView(
                            viewModel: viewModel,
                            isSidebarVisible: $isSidebarVisible,
                            inputText: $inputText,
                            isPromptEditorOpen: $isPromptEditorOpen,
                            isColumnMode: isColumnMode
                        )

                        // Colonne éditeur de prompt (mode large uniquement)
                        if isColumnMode && isPromptEditorOpen {
                            PromptEditorColumn(viewModel: viewModel, isOpen: $isPromptEditorOpen)
                                .frame(width: 320)
                                .transition(.move(edge: .trailing))
                        }
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
        }
        .onAppear {
            setupGlobalHotKey()
            DebugLogger.shared.log("🚀 Application démarrée", category: "System")
        }
        .alert("Erreur de capture", isPresented: Binding(
            get: { viewModel.captureError != nil },
            set: { if !$0 { viewModel.captureError = nil } }
        )) {
            Button("Ouvrir Préférences Système") {
                ScreenCaptureService.openSystemPreferences()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.captureError ?? "")
        }
    }

    // MARK: - Screen Capture Setup

    /// Configure les raccourcis globaux pour la capture d'écran.
    ///
    /// Cette méthode initialise les callbacks pour les raccourcis clavier :
    /// - `⌥⇧S` : Capture de l'écran principal
    /// - `⌥⇧X` : Capture d'une zone sélectionnée (overlay interactif)
    ///
    /// Les images capturées sont stockées dans `viewModel.capturedImage` puis
    /// transférées vers `pendingImages` via un `onChange` dans `ChatView`.
    private func setupGlobalHotKey() {
        let vm = viewModel

        // Callback pour écran principal (⌥⇧S)
        GlobalHotKeyManager.shared.onMainDisplayCapture = { [weak vm] in
            DebugLogger.shared.logCapture("📸 Capture écran principal demandée")

            Task {
                do {
                    let image = try await ScreenCaptureService.captureMainScreen()
                    await MainActor.run {
                        vm?.capturedImage = image
                        NSSound(named: "Tink")?.play()
                        DebugLogger.shared.logCapture("✅ Capture écran principal réussie")
                    }
                } catch let error as ScreenCaptureError {
                    await MainActor.run {
                        vm?.captureError = error.userInstructions
                        DebugLogger.shared.logError("❌ Capture échouée: \(error.errorDescription ?? "Erreur inconnue")")
                    }
                } catch {
                    await MainActor.run {
                        vm?.captureError = "Erreur inattendue: \(error.localizedDescription)"
                        DebugLogger.shared.logError("❌ Capture échouée: \(error.localizedDescription)")
                    }
                }
            }
        }

        // Callback pour tous les écrans (non implémenté)
        GlobalHotKeyManager.shared.onAllDisplaysCapture = {
            DebugLogger.shared.logWarning("⚠️ Capture tous écrans non implémentée")
        }

        // Callback pour zone sélectionnée (⌥⇧X)
        GlobalHotKeyManager.shared.onSelectionCapture = { [weak vm] in
            DebugLogger.shared.logCapture("📸 Capture zone demandée")

            SelectionCaptureService.showSelectionOverlay(
                onSuccess: { image in
                    vm?.capturedImage = image
                    NSSound(named: "Tink")?.play()
                    DebugLogger.shared.logCapture("✅ Capture zone réussie")
                },
                onError: { error in
                    // Afficher l'erreur pour que l'utilisateur puisse ouvrir les réglages
                    if let captureError = error as? ScreenCaptureError {
                        vm?.captureError = captureError.userInstructions
                        DebugLogger.shared.logError("❌ Capture zone échouée: \(captureError.localizedDescription ?? "Erreur inconnue")")
                    } else {
                        vm?.captureError = "Erreur inattendue: \(error.localizedDescription)"
                        DebugLogger.shared.logError("❌ Capture zone échouée: \(error.localizedDescription)")
                    }
                },
                onCancel: {
                    DebugLogger.shared.logWarning("⚠️ Capture zone annulée par l'utilisateur")
                }
            )
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

