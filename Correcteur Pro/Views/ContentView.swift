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
    @State private var isSidebarVisible: Bool = false
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
            DebugLogger.shared.log("📱 ContentView apparue", category: "System")

            // Vérifier inactivité et créer nouvelle conversation si nécessaire
            viewModel.checkInactivityAndResetIfNeeded()

            // Vérifier s'il y a une image en attente (capturée avant que la vue soit prête)
            checkForPendingImage()
        }
        // Écouter les captures d'écran depuis AppDelegate
        .onReceive(NotificationCenter.default.publisher(for: .screenCaptured)) { notification in
            if let image = notification.object as? NSImage {
                handleCapturedImage(image)
            }
        }
        // Écouter les erreurs de capture
        .onReceive(NotificationCenter.default.publisher(for: .captureError)) { notification in
            if let errorMessage = notification.object as? String {
                viewModel.captureError = errorMessage
            }
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

    // MARK: - Capture Handling

    /// Vérifie s'il y a une image en attente dans AppDelegate (avec retry)
    private func checkForPendingImage() {
        checkForPendingImageWithRetry(attempts: 0)
    }

    /// Vérifie l'image en attente avec plusieurs tentatives
    private func checkForPendingImageWithRetry(attempts: Int) {
        let maxAttempts = 5
        let delayMs = 300  // 300ms entre chaque vérification

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
            if let pendingImage = AppDelegate.consumePendingImage() {
                DebugLogger.shared.logCapture("📸 Image en attente récupérée (tentative \(attempts + 1))")
                handleCapturedImage(pendingImage)
            } else if attempts < maxAttempts {
                // Réessayer au cas où l'image arrive après
                checkForPendingImageWithRetry(attempts: attempts + 1)
            }
        }
    }

    /// Traite une image capturée reçue via notification
    private func handleCapturedImage(_ image: NSImage) {
        // Auto-envoi si activé ET conversation sélectionnée
        if PreferencesManager.shared.preferences.autoSendOnCapture,
           viewModel.selectedConversationID != nil {
            _ = viewModel.sendMessage("", images: [image])
            DebugLogger.shared.logCapture("✅ Capture envoyée automatiquement")

            // Forcer le scroll vers le bas après un délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .forceScrollToBottom, object: nil)
            }
        } else {
            viewModel.capturedImage = image
            DebugLogger.shared.logCapture("✅ Capture ajoutée en attente")
        }
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

