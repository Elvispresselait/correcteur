//
//  OCRService.swift
//  Correcteur Pro
//
//  Service d'extraction de texte (OCR) via Apple Vision
//

import Vision
import AppKit

// MARK: - OCR Result

/// Résultat de l'extraction OCR
struct OCRResult: Codable {
    /// Texte extrait avec retours à la ligne préservés
    let text: String

    /// Confiance moyenne (0.0 - 1.0)
    let confidence: Float

    /// Nombre de blocs de texte détectés
    let blockCount: Int

    /// Durée de l'extraction (millisecondes)
    let processingTimeMs: Int

    /// Indique si le texte est vide
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Indique si le fallback vers Vision est recommandé
    func shouldFallbackToVision(threshold: Float = 0.9) -> Bool {
        return isEmpty || confidence < threshold
    }
}

// MARK: - OCR Error

enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextFound
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Impossible de convertir l'image pour l'OCR"
        case .noTextFound:
            return "Aucun texte détecté dans l'image"
        case .recognitionFailed(let error):
            return "Erreur de reconnaissance : \(error.localizedDescription)"
        }
    }
}

// MARK: - OCR Service

/// Service d'extraction de texte via Apple Vision Framework
class OCRService {
    /// Singleton
    static let shared = OCRService()
    private init() {}

    // MARK: - Public API

    /// Extrait le texte d'une image NSImage
    /// - Parameter image: Image source (capture d'écran)
    /// - Returns: OCRResult avec le texte extrait et la confiance
    func extractText(from image: NSImage) async throws -> OCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. Convertir NSImage en CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }

        // 2. Créer la requête de reconnaissance
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["fr-FR", "en-US"]

        // 3. Exécuter la reconnaissance
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw OCRError.recognitionFailed(error)
        }

        // 4. Extraire les résultats
        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextFound
        }

        // 5. Reconstruire le texte avec préservation des retours à la ligne
        let (text, avgConfidence) = reconstructTextWithLineBreaks(
            observations: observations,
            imageHeight: CGFloat(cgImage.height)
        )

        // 6. Calculer le temps de traitement
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTimeMs = Int((endTime - startTime) * 1000)

        DebugLogger.shared.log(
            "📝 OCR terminé: \(observations.count) blocs, confiance \(Int(avgConfidence * 100))%, \(processingTimeMs)ms",
            category: "OCR"
        )

        return OCRResult(
            text: text,
            confidence: avgConfidence,
            blockCount: observations.count,
            processingTimeMs: processingTimeMs
        )
    }

    // MARK: - Private Methods

    /// Reconstruit le texte en préservant les retours à la ligne visuels
    private func reconstructTextWithLineBreaks(
        observations: [VNRecognizedTextObservation],
        imageHeight: CGFloat
    ) -> (text: String, confidence: Float) {

        // Trier par position Y (de haut en bas)
        // Note: Les coordonnées Vision sont normalisées (0-1) avec Y inversé (0 = bas)
        let sortedObservations = observations.sorted { obs1, obs2 in
            // Y plus grand = plus haut dans l'image
            obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
        }

        var lines: [String] = []
        var confidences: [Float] = []
        var lastY: CGFloat = 1.0 // Commence en haut

        // Seuil pour détecter un saut de paragraphe (en proportion de la hauteur)
        let paragraphThreshold: CGFloat = 0.05 // 5% de la hauteur = nouveau paragraphe

        for observation in sortedObservations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let currentY = observation.boundingBox.origin.y + observation.boundingBox.height
            let yDifference = lastY - currentY

            // Détecter si on doit ajouter une ligne vide (nouveau paragraphe)
            if yDifference > paragraphThreshold && !lines.isEmpty {
                lines.append("") // Ligne vide = séparation de paragraphe
            }

            lines.append(candidate.string)
            confidences.append(candidate.confidence)
            lastY = observation.boundingBox.origin.y
        }

        let text = lines.joined(separator: "\n")
        let avgConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)

        return (text, avgConfidence)
    }
}
