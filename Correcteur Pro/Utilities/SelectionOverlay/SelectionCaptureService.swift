//
//  SelectionCaptureService.swift
//  Correcteur Pro
//
//  Service pour capturer une zone spécifique de l'écran
//

import Cocoa
import ScreenCaptureKit

@available(macOS 12.3, *)
class SelectionCaptureService {

    // MARK: - Public Methods

    /// Capture une zone spécifique de l'écran
    /// - Parameter rect: Rectangle à capturer (coordonnées écran)
    /// - Returns: NSImage de la zone capturée
    /// - Throws: ScreenCaptureError en cas d'erreur
    static func captureRect(_ rect: NSRect) async throws -> NSImage {
        let msg1 = "📸 [SelectionCapture] Début capture de zone: \(Int(rect.width))x\(Int(rect.height))"
        print(msg1)
        DebugLogger.shared.logCapture(msg1)

        // 1. Obtenir tous les écrans
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            DebugLogger.shared.logCapture("✅ [SelectionCapture] Accès aux écrans obtenu")
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.apple.ScreenCaptureKit" && nsError.code == -3801 {
                DebugLogger.shared.logError("❌ [SelectionCapture] Permission refusée")
                throw ScreenCaptureError.permissionDenied(
                    message: "L'autorisation d'enregistrement d'écran a été refusée.",
                    instructionStep: .openSystemPreferences
                )
            }
            DebugLogger.shared.logError("❌ [SelectionCapture] Erreur système : \(error.localizedDescription)")
            throw ScreenCaptureError.systemError(
                message: "Impossible d'accéder aux écrans disponibles.",
                underlyingError: error
            )
        }

        // 2. Trouver l'écran qui contient la zone
        guard let display = findDisplayContaining(rect: rect, in: content.displays) else {
            DebugLogger.shared.logError("❌ [SelectionCapture] Aucun écran trouvé pour la zone sélectionnée")
            throw ScreenCaptureError.noDisplayFound(
                message: "Impossible de trouver l'écran contenant la zone sélectionnée."
            )
        }

        let msg2 = "📺 [SelectionCapture] Écran trouvé: \(display.displayID)"
        print(msg2)
        DebugLogger.shared.logCapture(msg2)

        // 3. Convertir le rectangle en coordonnées relatives à l'écran
        let relativeRect = CGRect(
            x: rect.origin.x - display.frame.origin.x,
            y: rect.origin.y - display.frame.origin.y,
            width: rect.width,
            height: rect.height
        )

        print("📐 [SelectionCapture] Rectangle relatif: \(relativeRect)")

        // 4. Configurer le filtre pour capturer tout l'écran
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // 5. Configuration de capture
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        // 6. Capturer l'écran complet
        let fullImage: CGImage
        do {
            DebugLogger.shared.logCapture("📸 [SelectionCapture] Capture de l'écran en cours...")
            fullImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            DebugLogger.shared.logCapture("✅ [SelectionCapture] Capture écran réussie")
        } catch {
            DebugLogger.shared.logError("❌ [SelectionCapture] Échec de la capture : \(error.localizedDescription)")
            throw ScreenCaptureError.captureFailed(
                message: "La capture d'écran a échoué.",
                underlyingError: error
            )
        }

        // 7. Découper la zone sélectionnée
        guard let croppedImage = cropImage(fullImage, to: relativeRect) else {
            struct CropError: Error {}
            DebugLogger.shared.logError("❌ [SelectionCapture] Échec du découpage")
            throw ScreenCaptureError.captureFailed(
                message: "Impossible de découper la zone sélectionnée.",
                underlyingError: CropError()
            )
        }

        let finalImage = NSImage(cgImage: croppedImage, size: NSSize(width: rect.width, height: rect.height))
        let msg3 = "✅ [SelectionCapture] Capture réussie: \(Int(finalImage.size.width))x\(Int(finalImage.size.height))"
        print(msg3)
        DebugLogger.shared.logCapture(msg3)

        return finalImage
    }

    // MARK: - Private Methods

    /// Trouve l'écran qui contient le rectangle donné
    private static func findDisplayContaining(rect: NSRect, in displays: [SCDisplay]) -> SCDisplay? {
        for display in displays {
            if display.frame.intersects(rect) {
                return display
            }
        }
        return displays.first // Fallback sur le premier écran
    }

    /// Découpe une image CGImage selon un rectangle
    private static func cropImage(_ image: CGImage, to rect: CGRect) -> CGImage? {
        // Vérifier que le rectangle est dans les limites de l'image
        let imageRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard imageRect.contains(rect) else {
            print("⚠️ [SelectionCapture] Rectangle hors limites: \(rect) vs \(imageRect)")
            // Ajuster le rectangle aux limites de l'image
            let adjustedRect = rect.intersection(imageRect)
            return image.cropping(to: adjustedRect)
        }

        return image.cropping(to: rect)
    }

    // MARK: - Overlay Management

    /// Affiche l'overlay de sélection et capture la zone
    /// - Parameter completion: Callback avec l'image capturée ou nil si annulé
    static func showSelectionOverlay(completion: @escaping (NSImage?) -> Void) {
        let window = SelectionOverlayWindow()

        window.onSelectionComplete = { rect in
            print("📸 [SelectionCapture] Zone sélectionnée: \(rect)")

            // Capturer la zone de manière asynchrone
            Task {
                do {
                    let image = try await captureRect(rect)
                    await MainActor.run {
                        completion(image)
                    }
                } catch {
                    print("❌ [SelectionCapture] Erreur: \(error.localizedDescription)")
                    await MainActor.run {
                        completion(nil)
                    }
                }
            }
        }

        window.onCancel = {
            print("❌ [SelectionCapture] Sélection annulée")
            completion(nil)
        }

        window.show()
    }
}
