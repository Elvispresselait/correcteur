# ÉTAPE 10 : Plan de test de lisibilité du texte dans les images

**Date** : 29 novembre 2024
**Objectif** : Implémenter un système de test interne pour valider automatiquement la lisibilité du texte après compression

---

## 📋 Vue d'ensemble

### Problématique

Lors de l'optimisation de la compression (ÉTAPE 9), nous devons **vérifier automatiquement** que le texte reste lisible après compression. Actuellement, cette validation se fait manuellement.

### Solution proposée

Utiliser **Vision Framework** d'Apple (OCR intégré macOS) pour :
1. Extraire le texte de l'image **avant** compression
2. Extraire le texte de l'image **après** compression
3. **Comparer** les deux résultats
4. **Valider** que la lisibilité est maintenue

---

## 🎯 Objectifs

### Objectif principal

Créer un système de validation automatique de la qualité de compression basé sur la reconnaissance de texte.

### Objectifs mesurables

| Métrique | Description | Seuil de validation |
|----------|-------------|---------------------|
| **Taux de reconnaissance** | % de texte reconnu après compression | ≥ 95% |
| **Précision des caractères** | % de caractères identiques | ≥ 98% |
| **Confiance OCR** | Score de confiance Vision Framework | ≥ 0.7 |
| **Performance** | Temps de validation | < 2 secondes |

### Cas d'usage

1. **Développement** : Valider les nouveaux profils de compression
2. **Tests automatisés** : CI/CD pour vérifier la qualité
3. **Debugging** : Identifier pourquoi une compression échoue
4. **Monitoring** : Logs de qualité pour amélioration continue

---

## 🔧 Architecture technique

### Vision Framework (macOS 10.15+)

Apple fournit un OCR natif ultra-performant :

```swift
import Vision
import CoreImage

class TextRecognitionService {
    /// Extrait le texte d'une image
    static func extractText(from image: NSImage) async throws -> RecognizedText {
        // 1. Convertir NSImage → CGImage
        // 2. Créer VNRecognizeTextRequest
        // 3. Exécuter la reconnaissance
        // 4. Retourner le texte + confiance
    }

    /// Compare deux résultats OCR
    static func compareTexts(_ original: RecognizedText,
                            _ compressed: RecognizedText) -> QualityScore {
        // Calculer similarité, confiance, etc.
    }
}

struct RecognizedText {
    let fullText: String
    let lines: [TextLine]
    let confidence: Float
    let characterCount: Int
}

struct TextLine {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct QualityScore {
    let recognitionRate: Float      // 0.0 - 1.0
    let characterAccuracy: Float    // 0.0 - 1.0
    let averageConfidence: Float    // 0.0 - 1.0
    let isPassing: Bool             // true si tous les seuils OK
    let details: String             // Explication
}
```

---

## 📊 Workflow complet

### Scénario 1 : Validation compression (développement)

```
1. User déclenche compression d'une capture d'écran
   ↓
2. CompressionService :
   a. Garde référence à l'image originale
   b. Applique la compression optimisée
   c. Obtient l'image compressée
   ↓
3. TextRecognitionService :
   a. Extrait texte de l'originale
   b. Extrait texte de la compressée
   c. Compare les résultats
   ↓
4. Validation :
   ✅ Si QualityScore.isPassing = true → Utiliser image compressée
   ❌ Si QualityScore.isPassing = false → Fallback compression moins agressive
   ↓
5. Logging :
   - Log le QualityScore pour analyse
   - Permet d'ajuster les profils de compression
```

### Scénario 2 : Tests automatisés

```swift
func testCompressionQuality() async throws {
    // 1. Charger image de test
    let testImage = loadTestImage("code_screenshot.png")

    // 2. Appliquer compression
    let compressed = testImage.compressOptimized(quality: .high)

    // 3. Valider qualité
    let quality = try await TextQualityValidator.validate(
        original: testImage,
        compressed: compressed
    )

    // 4. Assert
    XCTAssertTrue(quality.isPassing)
    XCTAssertGreaterThan(quality.recognitionRate, 0.95)
}
```

---

## 🛠️ Implémentation

### Phase 1 : Service de reconnaissance texte (3-4h)

**Fichier** : `Correcteur Pro/Utilities/TextRecognitionService.swift`

```swift
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
        let recognitionRate: Float      // % texte reconnu
        let characterAccuracy: Float    // % caractères identiques
        let averageConfidence: Float    // Confiance moyenne OCR
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

    /// Calcule la similarité entre deux textes (distance de Levenshtein normalisée)
    private static func calculateSimilarity(_ text1: String, _ text2: String) -> Float {
        let distance = levenshteinDistance(text1, text2)
        let maxLength = max(text1.count, text2.count)

        guard maxLength > 0 else { return 1.0 }

        let similarity = 1.0 - (Float(distance) / Float(maxLength))
        return max(0.0, similarity)
    }

    /// Distance de Levenshtein (nombre de modifications nécessaires)
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
```

---

### Phase 2 : Intégration dans compression (2-3h)

**Fichier** : `Correcteur Pro/Utilities/TextQualityValidator.swift`

```swift
import AppKit

/// Validateur de qualité pour compression d'images avec texte
class TextQualityValidator {

    /// Valide la qualité d'une compression en comparant l'OCR
    static func validate(original: NSImage, compressed: NSImage?) async throws -> TextRecognitionService.QualityScore {
        guard let compressed = compressed else {
            return .failing(reason: "Compressed image is nil")
        }

        print("📝 [Quality] Extracting text from original image...")
        let originalText = try await TextRecognitionService.extractText(from: original)
        print("✅ [Quality] Original: \(originalText.characterCount) chars, confidence: \(String(format: "%.2f", originalText.confidence))")

        print("📝 [Quality] Extracting text from compressed image...")
        let compressedText = try await TextRecognitionService.extractText(from: compressed)
        print("✅ [Quality] Compressed: \(compressedText.characterCount) chars, confidence: \(String(format: "%.2f", compressedText.confidence))")

        let score = TextRecognitionService.compareTexts(originalText, compressedText)

        if score.isPassing {
            print("✅ [Quality] PASSED: \(score.details)")
        } else {
            print("❌ [Quality] FAILED: \(score.details)")
        }

        return score
    }

    /// Compresse avec validation automatique et fallback
    static func compressWithValidation(
        image: NSImage,
        quality: CompressionQuality,
        maxAttempts: Int = 3
    ) async throws -> NSImage {
        var currentQuality = quality

        for attempt in 1...maxAttempts {
            print("🔧 [Quality] Compression attempt \(attempt)/\(maxAttempts) with quality: \(currentQuality)")

            // Appliquer compression
            guard let compressed = image.compressOptimized(userQuality: currentQuality) else {
                throw NSError(domain: "Compression", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Compression failed"
                ])
            }

            // Valider qualité
            let score = try await validate(original: image, compressed: compressed)

            if score.isPassing {
                print("✅ [Quality] Compression successful!")
                return compressed
            }

            // Si échec et pas dernier essai, réduire la compression
            if attempt < maxAttempts {
                currentQuality = currentQuality.lesserCompression()
                print("⚠️ [Quality] Quality check failed, retrying with less compression...")
            }
        }

        print("❌ [Quality] All attempts failed, using original")
        return image
    }
}

// Extension pour réduire niveau de compression
extension CompressionQuality {
    func lesserCompression() -> CompressionQuality {
        switch self {
        case .high: return .medium
        case .medium: return .low
        case .low: return .none
        case .none: return .none
        }
    }
}
```

---

### Phase 3 : Tests automatisés (2-3h)

**Fichier** : `Correcteur Pro Tests/TextRecognitionTests.swift`

```swift
import XCTest
@testable import Correcteur_Pro

class TextRecognitionTests: XCTestCase {

    func testExtractTextFromCodeScreenshot() async throws {
        // Charger image de test
        let testImage = loadTestImage("code_screenshot")

        // Extraire texte
        let result = try await TextRecognitionService.extractText(from: testImage)

        // Vérifications
        XCTAssertFalse(result.isEmpty)
        XCTAssertGreaterThan(result.characterCount, 100)
        XCTAssertGreaterThan(result.confidence, 0.7)
    }

    func testCompressionQualityHigh() async throws {
        let original = loadTestImage("document_text")
        let compressed = original.compressOptimized(quality: .high)

        let score = try await TextQualityValidator.validate(
            original: original,
            compressed: compressed
        )

        XCTAssertTrue(score.isPassing)
        XCTAssertGreaterThan(score.recognitionRate, 0.95)
        XCTAssertGreaterThan(score.characterAccuracy, 0.98)
    }

    func testCompressionWithValidation() async throws {
        let testImage = loadTestImage("mixed_content")

        let result = try await TextQualityValidator.compressWithValidation(
            image: testImage,
            quality: .high
        )

        XCTAssertNotNil(result)
    }
}
```

---

### Phase 4 : Interface de debug (optionnel, 1-2h)

Ajouter dans le panneau Préférences un onglet "Debug" :

```swift
struct DebugPreferencesView: View {
    @State private var testResult: String = ""
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test de qualité OCR")
                .font(.headline)

            Button("Tester dernière capture") {
                testLastCapture()
            }

            if isLoading {
                ProgressView()
            }

            Text(testResult)
                .font(.system(.body, design: .monospaced))
        }
        .padding()
    }

    func testLastCapture() {
        // Implémenter test
    }
}
```

---

## 📊 Planning

### Estimation totale : 7-12 heures

| Phase | Description | Durée | Priorité |
|-------|-------------|-------|----------|
| 1 | TextRecognitionService | 3-4h | 🔴 Haute |
| 2 | TextQualityValidator | 2-3h | 🔴 Haute |
| 3 | Tests automatisés | 2-3h | 🟡 Moyenne |
| 4 | Interface debug | 1-2h | 🟢 Basse |

---

## 🎯 Résultats attendus

### Avant (sans validation)

- ❌ Compression manuelle
- ❌ Validation visuelle uniquement
- ❌ Risque de perte de lisibilité
- ❌ Pas de mesure objective

### Après (avec validation)

- ✅ Compression automatique validée
- ✅ Score objectif de qualité
- ✅ Fallback automatique si échec
- ✅ Logs pour optimisation continue
- ✅ Tests automatisés

---

## 🔗 Intégration avec ÉTAPE 9

Cette étape complète l'ÉTAPE 9 (Optimisation compression) :

```
ÉTAPE 9: Optimisation compression
    ↓
    Crée profils agressifs
    ↓
ÉTAPE 10: Test lisibilité ← (CE PLAN)
    ↓
    Valide que texte reste lisible
    ↓
    Ajuste automatiquement si besoin
```

---

## 📝 Notes importantes

1. **Vision Framework requis** : macOS 10.15+ (déjà supporté)
2. **Performance** : OCR prend ~0.5-1s par image
3. **Langues** : Configure fr-FR et en-US par défaut
4. **Précision** : Vision Framework très performant (~95%+ sur texte clair)

---

## 🚀 Prochaines étapes

Après implémentation :

1. **Collecter données** : Logger scores sur 100+ compressions
2. **Ajuster seuils** : Affiner les 95%/98%/70% selon résultats réels
3. **Optimiser profils** : Utiliser les scores pour améliorer ÉTAPE 9
4. **Machine Learning** (futur) : Prédire meilleur profil selon image

---

**Statut** : ⏳ EN ATTENTE DE VALIDATION
**Dépend de** : ÉTAPE 9 (Optimisation compression)
**Créé le** : 29 novembre 2024
