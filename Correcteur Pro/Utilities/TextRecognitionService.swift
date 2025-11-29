//
//  TextRecognitionService.swift
//  Correcteur Pro
//
//  Service pour extraire et comparer du texte dans les images via Vision Framework
//

import Vision
import CoreImage
import AppKit

/// Service pour extraire et comparer du texte dans les images
class TextRecognitionService {

    // MARK: - Types

    struct RecognizedText {
        let fullText: String
        let lines: [TextLine]
        let confidence: Float
        let characterCount: Int

        var isEmpty: Bool {
            return fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    struct TextLine {
        let text: String
        let confidence: Float
        let boundingBox: CGRect
    }

    struct QualityScore {
        let recognitionRate: Float      // % texte reconnu (0.0 - 1.0)
        let characterAccuracy: Float    // % caractères identiques (0.0 - 1.0)
        let averageConfidence: Float    // Confiance moyenne OCR (0.0 - 1.0)
        let originalCount: Int
        let compressedCount: Int
        let isPassing: Bool
        let details: String

        static func failing(reason: String) -> QualityScore {
            return QualityScore(
                recognitionRate: 0.0,
                characterAccuracy: 0.0,
                averageConfidence: 0.0,
                originalCount: 0,
                compressedCount: 0,
                isPassing: false,
                details: reason
            )
        }
    }

    // MARK: - OCR Methods

    /// Extrait le texte d'une image en utilisant Vision Framework
    /// - Parameter image: Image à analyser
    /// - Returns: Texte reconnu avec métadonnées
    static func extractText(from image: NSImage) async throws -> RecognizedText {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "TextRecognition", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot convert NSImage to CGImage"
            ])
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Créer la requête de reconnaissance
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: RecognizedText(
                        fullText: "",
                        lines: [],
                        confidence: 0.0,
                        characterCount: 0
                    ))
                    return
                }

                // Extraire le texte de chaque observation
                var lines: [TextLine] = []
                var fullText = ""
                var totalConfidence: Float = 0.0

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }

                    let line = TextLine(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: observation.boundingBox
                    )

                    lines.append(line)
                    fullText += topCandidate.string + "\n"
                    totalConfidence += topCandidate.confidence
                }

                let averageConfidence = lines.isEmpty ? 0.0 : totalConfidence / Float(lines.count)

                let result = RecognizedText(
                    fullText: fullText,
                    lines: lines,
                    confidence: averageConfidence,
                    characterCount: fullText.count
                )

                continuation.resume(returning: result)
            }

            // Configurer pour meilleure reconnaissance
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["fr-FR", "en-US"]

            // Exécuter la requête
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Comparison Methods

    /// Compare deux résultats OCR et calcule un score de qualité
    /// - Parameters:
    ///   - original: Texte extrait de l'image originale
    ///   - compressed: Texte extrait de l'image compressée
    /// - Returns: Score de qualité avec validation
    static func compareTexts(_ original: RecognizedText,
                            _ compressed: RecognizedText) -> QualityScore {
        // Si l'original est vide, pas de texte à valider
        if original.isEmpty {
            return QualityScore(
                recognitionRate: 1.0,
                characterAccuracy: 1.0,
                averageConfidence: compressed.confidence,
                originalCount: 0,
                compressedCount: 0,
                isPassing: true,
                details: "No text to validate (original is empty)"
            )
        }

        // Si la compression a perdu tout le texte
        if compressed.isEmpty {
            return .failing(reason: "Compressed image has no recognizable text")
        }

        // 1. Calculer le taux de reconnaissance (nombre de caractères)
        let originalCount = original.characterCount
        let compressedCount = compressed.characterCount
        let recognitionRate = Float(compressedCount) / Float(originalCount)

        // 2. Calculer la précision des caractères (similarité Levenshtein)
        let characterAccuracy = calculateSimilarity(
            original.fullText,
            compressed.fullText
        )

        // 3. Confiance moyenne
        let averageConfidence = compressed.confidence

        // 4. Validation des seuils
        let passingRecognitionRate = recognitionRate >= 0.95
        let passingCharacterAccuracy = characterAccuracy >= 0.98
        let passingConfidence = averageConfidence >= 0.7

        let isPassing = passingRecognitionRate && passingCharacterAccuracy && passingConfidence

        // 5. Détails
        var details = "Recognition: \(String(format: "%.1f%%", recognitionRate * 100))"
        details += ", Accuracy: \(String(format: "%.1f%%", characterAccuracy * 100))"
        details += ", Confidence: \(String(format: "%.1f%%", averageConfidence * 100))"

        if !isPassing {
            details += " | "
            if !passingRecognitionRate {
                details += "⚠️ Low recognition rate. "
            }
            if !passingCharacterAccuracy {
                details += "⚠️ Low character accuracy. "
            }
            if !passingConfidence {
                details += "⚠️ Low OCR confidence. "
            }
        }

        return QualityScore(
            recognitionRate: recognitionRate,
            characterAccuracy: characterAccuracy,
            averageConfidence: averageConfidence,
            originalCount: originalCount,
            compressedCount: compressedCount,
            isPassing: isPassing,
            details: details
        )
    }

    // MARK: - Helper Methods

    /// Calcule la similarité entre deux textes (distance de Levenshtein normalisée)
    /// - Parameters:
    ///   - text1: Premier texte
    ///   - text2: Second texte
    /// - Returns: Similarité entre 0.0 (différent) et 1.0 (identique)
    private static func calculateSimilarity(_ text1: String, _ text2: String) -> Float {
        let distance = levenshteinDistance(text1, text2)
        let maxLength = max(text1.count, text2.count)

        guard maxLength > 0 else { return 1.0 }

        let similarity = 1.0 - (Float(distance) / Float(maxLength))
        return max(0.0, similarity)
    }

    /// Distance de Levenshtein (nombre de modifications nécessaires)
    /// - Parameters:
    ///   - s1: Première chaîne
    ///   - s2: Seconde chaîne
    /// - Returns: Nombre minimum d'opérations (insertion, suppression, substitution)
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let len1 = s1.count
        let len2 = s2.count

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: len2 + 1), count: len1 + 1)

        for i in 0...len1 { matrix[i][0] = i }
        for j in 0...len2 { matrix[0][j] = j }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        for i in 1...len1 {
            for j in 1...len2 {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[len1][len2]
    }
}
