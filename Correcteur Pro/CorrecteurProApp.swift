//
//  CorrecteurProApp.swift
//  Correcteur Pro
//
//  Point d'entrée de l'application - Menu Bar App
//

import SwiftUI

@main
struct CorrecteurProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Fenêtre principale avec ID pour contrôle programmatique
        WindowGroup(id: "main") {
            ContentView()
                .frame(minWidth: 450, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                    // Géré ici pour avoir accès à openWindow
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 700)

        // Menu bar extra - icône dans la barre de menu
        MenuBarExtra {
            MenuBarMenu()
        } label: {
            Image(systemName: "checkmark.circle")
        }
        .menuBarExtraStyle(.menu)

        // Fenêtre de préférences (Cmd+,)
        Settings {
            PreferencesWindow()
        }
    }
}

// MARK: - AppDelegate

/// Gère le cycle de vie de l'application pour le mode menu bar
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // FIX CRITIQUE: Restaurer le delegate pour que applicationShouldHandleReopen fonctionne
        // SwiftUI intercepte le delegate, cette ligne le restaure
        NSApplication.shared.delegate = self

        // Appliquer la préférence de visibilité Dock
        let showInDock = PreferencesManager.shared.preferences.showInDock
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

        // Enregistrer les raccourcis globaux
        setupHotKeyCallbacks()
        GlobalHotKeyManager.shared.registerAllHotKeys()

        DebugLogger.shared.log("🚀 Application démarrée (mode menu bar)", category: "System")
    }

    /// CRITIQUE : Empêche l'app de quitter quand on ferme la fenêtre
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Gère le clic sur l'icône Dock quand aucune fenêtre n'est visible
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DebugLogger.shared.log("🖱️ applicationShouldHandleReopen appelé (hasVisibleWindows: \(flag))", category: "System")
        if !flag {
            openMainWindowDirectly()
        }
        return true
    }

    /// Appelé quand l'app devient active (backup pour clic Dock)
    func applicationWillBecomeActive(_ notification: Notification) {
        // Vérifier s'il y a une fenêtre principale visible
        let hasVisibleMainWindow = NSApp.windows.contains { window in
            window.isVisible &&
            window.canBecomeKey &&
            window.frame.width > 300 &&
            window.frame.height > 400
        }

        if !hasVisibleMainWindow {
            DebugLogger.shared.log("🖱️ applicationWillBecomeActive - aucune fenêtre visible, ouverture...", category: "System")
            openMainWindowDirectly()
        }
    }

    /// Ouvre la fenêtre principale de manière fiable
    private func openMainWindowDirectly() {
        NSApp.activate(ignoringOtherApps: true)

        // Chercher une fenêtre principale existante à réactiver
        let mainWindow = NSApp.windows.first { window in
            window.contentView != nil &&
            window.frame.width > 300 &&
            window.frame.height > 400 &&
            !window.title.lowercased().contains("préférences") &&
            !window.title.lowercased().contains("settings")
        }

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            DebugLogger.shared.log("📱 Fenêtre existante réactivée", category: "System")
        } else {
            // Demander l'ouverture via notification (sera capté par CorrecteurProApp)
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
            DebugLogger.shared.log("📱 Demande création nouvelle fenêtre", category: "System")
        }
    }

    // MARK: - Hotkey Callbacks

    /// Configure les callbacks pour les raccourcis globaux
    private func setupHotKeyCallbacks() {
        // Callback pour capture écran principal (⌥⇧X)
        GlobalHotKeyManager.shared.onMainDisplayCapture = {
            DebugLogger.shared.logCapture("📸 Capture écran principal demandée")

            Task {
                do {
                    let image = try await ScreenCaptureService.captureMainScreen()
                    await MainActor.run {
                        // Ouvrir la fenêtre et envoyer l'image
                        Self.openWindowAndSendImage(image)
                        Self.playCaptureSound()
                        DebugLogger.shared.logCapture("✅ Capture écran principal réussie")
                    }
                } catch let error as ScreenCaptureError {
                    await MainActor.run {
                        Self.handleCaptureError(error)
                    }
                } catch {
                    await MainActor.run {
                        Self.handleGenericError(error)
                    }
                }
            }
        }

        // Callback pour tous les écrans (non implémenté)
        GlobalHotKeyManager.shared.onAllDisplaysCapture = {
            DebugLogger.shared.logWarning("⚠️ Capture tous écrans non implémentée")
        }

        // Callback pour capture zone sélectionnée (⌥⇧S)
        GlobalHotKeyManager.shared.onSelectionCapture = {
            DebugLogger.shared.logCapture("📸 Capture zone demandée")

            SelectionCaptureService.showSelectionOverlay(
                onSuccess: { image in
                    Self.openWindowAndSendImage(image)
                    Self.playCaptureSound()
                    DebugLogger.shared.logCapture("✅ Capture zone réussie")
                },
                onError: { error in
                    if let captureError = error as? ScreenCaptureError {
                        Self.handleCaptureError(captureError)
                    } else {
                        Self.handleGenericError(error)
                    }
                },
                onCancel: {
                    DebugLogger.shared.logWarning("⚠️ Capture zone annulée par l'utilisateur")
                }
            )
        }
    }

    // MARK: - Capture Helpers

    /// Joue le son de capture si activé dans les préférences
    private static func playCaptureSound() {
        if PreferencesManager.shared.preferences.playsSoundAfterCapture {
            NSSound(named: "Tink")?.play()
        }
    }

    /// Gère une erreur de capture spécifique
    private static func handleCaptureError(_ error: ScreenCaptureError) {
        NotificationCenter.default.post(name: .captureError, object: error.userInstructions)
        DebugLogger.shared.logError("❌ Capture échouée: \(error.errorDescription ?? "Erreur inconnue")")
    }

    /// Gère une erreur générique
    private static func handleGenericError(_ error: Error) {
        NotificationCenter.default.post(name: .captureError, object: "Erreur inattendue: \(error.localizedDescription)")
        DebugLogger.shared.logError("❌ Capture échouée: \(error.localizedDescription)")
    }

    /// Ouvre la fenêtre principale et envoie l'image capturée
    private static func openWindowAndSendImage(_ image: NSImage) {
        // Activer l'app
        NSApp.activate(ignoringOtherApps: true)

        // Chercher une fenêtre principale visible (exclure les fenêtres de menu bar et settings)
        let mainWindow = NSApp.windows.first { window in
            // Exclure les fenêtres de type menu (MenuBarExtra) et les petites fenêtres
            window.contentView != nil &&
            window.frame.width > 300 &&
            window.frame.height > 400 &&
            !window.title.lowercased().contains("préférences") &&
            !window.title.lowercased().contains("settings")
        }

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            DebugLogger.shared.log("📱 Fenêtre existante activée", category: "System")
        } else {
            // Demander l'ouverture d'une nouvelle fenêtre via notification
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
            DebugLogger.shared.log("📱 Demande d'ouverture nouvelle fenêtre", category: "System")
        }

        // Stocker l'image temporairement pour le cas où la notification arrive avant la fenêtre
        pendingCapturedImage = image

        // Envoyer l'image avec retry si la fenêtre n'est pas prête
        sendImageWithRetry(image, attempts: 0)
    }

    /// Image en attente d'envoi (si fenêtre pas encore prête)
    private static var pendingCapturedImage: NSImage?

    /// Récupère et consomme l'image en attente (appelé par ContentView)
    static func consumePendingImage() -> NSImage? {
        let image = pendingCapturedImage
        pendingCapturedImage = nil
        return image
    }

    /// Envoie l'image avec mécanisme de retry
    private static func sendImageWithRetry(_ image: NSImage, attempts: Int) {
        let maxAttempts = 10  // Plus de tentatives pour laisser le temps à la fenêtre de s'ouvrir
        let delayMs = 200     // 200ms entre chaque tentative (total max: 2 secondes)

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs * (attempts + 1))) {
            // Vérifier si une fenêtre principale est visible
            let hasVisibleMainWindow = NSApp.windows.contains { window in
                window.isVisible &&
                window.contentView != nil &&
                window.frame.width > 300 &&
                window.frame.height > 400
            }

            if hasVisibleMainWindow {
                // Fenêtre prête, envoyer l'image
                NotificationCenter.default.post(name: .screenCaptured, object: image)
                pendingCapturedImage = nil
                DebugLogger.shared.log("📸 Image envoyée à ContentView (tentative \(attempts + 1))", category: "System")
            } else if attempts < maxAttempts {
                // Réessayer
                DebugLogger.shared.log("⏳ Fenêtre pas encore prête, retry \(attempts + 1)/\(maxAttempts)", category: "System")
                sendImageWithRetry(image, attempts: attempts + 1)
            } else {
                // Échec après max tentatives - l'image reste en pending pour checkForPendingImage()
                DebugLogger.shared.logWarning("⚠️ Timeout envoi image - stockée en attente")
                // Ne pas poster si la fenêtre n'existe pas, ContentView récupérera via checkForPendingImage()
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Demande l'ouverture de la fenêtre principale
    static let openMainWindow = Notification.Name("openMainWindow")

    /// Une capture d'écran a été effectuée (object: NSImage)
    static let screenCaptured = Notification.Name("screenCaptured")

    /// Une erreur de capture s'est produite (object: String message)
    static let captureError = Notification.Name("captureError")
}

