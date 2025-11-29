import Cocoa
import ScreenCaptureKit

@available(macOS 12.3, *)
class ScreenCaptureService {

    // MARK: - Permission Status

    enum PermissionStatus {
        case authorized
        case notDetermined  // Jamais demandé
        case denied         // Refusé par l'utilisateur
        case restricted     // Bloqué par politique système
    }

    /// Vérifier l'état actuel des permissions
    static func getPermissionStatus() async -> PermissionStatus {
        // Sur macOS 12.3+, SCShareableContent ne lance PAS automatiquement
        // la demande de permission. Il faut vérifier manuellement.

        // ⚠️ IMPORTANT : Ne pas vérifier avec try/catch car cela crée une boucle
        // On suppose toujours .authorized et on laisse l'erreur se produire
        // lors de la vraie capture, où l'utilisateur verra le dialog système
        return .authorized
    }

    // MARK: - Capture

    /// Capture tout l'écran principal avec gestion d'erreurs détaillée
    static func captureMainScreen() async throws -> NSImage {
        // ⚠️ NE PAS vérifier les permissions ici - laisser le système gérer
        // Si les permissions ne sont pas accordées, SCShareableContent lancera
        // automatiquement le dialog système la première fois

        DebugLogger.shared.logCapture("🎬 [ScreenCapture] Début de la capture d'écran...")

        // 1. Obtenir les écrans disponibles
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            DebugLogger.shared.logCapture("✅ [ScreenCapture] Accès aux écrans obtenu")
        } catch {
            // Vérifier si c'est une erreur de permission
            let nsError = error as NSError

            // Code -3801 = Permission refusée pour ScreenCaptureKit
            if nsError.domain == "com.apple.ScreenCaptureKit" && nsError.code == -3801 {
                DebugLogger.shared.logError("❌ [ScreenCapture] Permission refusée (code -3801)")
                throw ScreenCaptureError.permissionDenied(
                    message: "L'autorisation d'enregistrement d'écran a été refusée.",
                    instructionStep: .openSystemPreferences
                )
            }

            // Autre erreur système
            DebugLogger.shared.logError("❌ [ScreenCapture] Erreur système : \(error.localizedDescription)")
            throw ScreenCaptureError.systemError(
                message: "Impossible d'accéder aux écrans disponibles.",
                underlyingError: error
            )
        }

        guard let mainDisplay = content.displays.first else {
            DebugLogger.shared.logError("❌ [ScreenCapture] Aucun écran détecté")
            throw ScreenCaptureError.noDisplayFound(
                message: "Aucun écran détecté. Vérifiez que votre Mac a au moins un écran connecté."
            )
        }

        DebugLogger.shared.logCapture("📺 [ScreenCapture] Écran principal : \(Int(mainDisplay.width))x\(Int(mainDisplay.height))")

        // 3. Configurer le filtre pour capturer l'écran
        let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])

        // 4. Configuration de capture (résolution, framerate)
        let config = SCStreamConfiguration()
        config.width = Int(mainDisplay.width)
        config.height = Int(mainDisplay.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        // 5. Capturer une frame
        let image: CGImage
        do {
            DebugLogger.shared.logCapture("📸 [ScreenCapture] Capture en cours...")
            image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            DebugLogger.shared.logCapture("✅ [ScreenCapture] Capture réussie!")
        } catch {
            DebugLogger.shared.logError("❌ [ScreenCapture] Échec de la capture : \(error.localizedDescription)")
            throw ScreenCaptureError.captureFailed(
                message: "La capture d'écran a échoué.",
                underlyingError: error
            )
        }

        // 6. Convertir CGImage en NSImage
        let finalImage = NSImage(cgImage: image, size: mainDisplay.frame.size)
        DebugLogger.shared.logCapture("🎉 [ScreenCapture] Image convertie en NSImage, prête à être compressée")
        return finalImage
    }

    // MARK: - Permission Request

    /// Ouvre les Préférences Système à la bonne page
    static func openSystemPreferences() {
        if #available(macOS 13.0, *) {
            // macOS 13+ : Nouvelle URL pour Réglages Système
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            NSWorkspace.shared.open(url)
        } else {
            // macOS 12 : Ancienne URL pour Préférences Système
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Error Types

enum ScreenCaptureError: LocalizedError {
    case permissionDenied(message: String, instructionStep: InstructionStep)
    case permissionNotRequested(message: String, instructionStep: InstructionStep)
    case permissionRestricted(message: String)
    case noDisplayFound(message: String)
    case captureFailed(message: String, underlyingError: Error)
    case systemError(message: String, underlyingError: Error)

    enum InstructionStep {
        case openSystemPreferences
        case enablePermission
        case restartApp
    }

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message, _):
            return message
        case .permissionNotRequested(let message, _):
            return message
        case .permissionRestricted(let message):
            return message
        case .noDisplayFound(let message):
            return message
        case .captureFailed(let message, _):
            return message
        case .systemError(let message, _):
            return message
        }
    }

    /// Instructions détaillées pour l'utilisateur
    var userInstructions: String {
        switch self {
        case .permissionDenied,
             .permissionNotRequested:
            return """
            Pour autoriser la capture d'écran :

            1️⃣ Ouvrez les Réglages Système
            2️⃣ Allez dans "Confidentialité et sécurité"
            3️⃣ Cliquez sur "Enregistrement d'écran"
            4️⃣ Activez le bouton pour "Correcteur Pro"
            5️⃣ Relancez l'application

            Voulez-vous ouvrir les Réglages Système maintenant ?
            """

        case .permissionRestricted:
            return """
            L'enregistrement d'écran est désactivé par une politique système.

            Si vous utilisez un Mac professionnel, contactez votre administrateur système.
            """

        case .noDisplayFound:
            return """
            Aucun écran détecté.

            Vérifiez que :
            • Votre Mac a au moins un écran connecté
            • L'écran est allumé et détecté par macOS
            """

        case .captureFailed(_, let error):
            return """
            La capture d'écran a échoué.

            Erreur technique : \(error.localizedDescription)

            Essayez de :
            • Relancer l'application
            • Redémarrer votre Mac
            """

        case .systemError(_, let error):
            return """
            Erreur système lors de l'accès aux écrans.

            Erreur technique : \(error.localizedDescription)
            """
        }
    }

    /// Indique si on peut ouvrir les Réglages Système pour résoudre
    var canOpenSystemPreferences: Bool {
        switch self {
        case .permissionDenied, .permissionNotRequested:
            return true
        default:
            return false
        }
    }
}
