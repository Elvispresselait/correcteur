# 📝 Plan : Mode OCR Intelligent

**Date** : 30 novembre 2024
**Objectif** : Implémenter un mode OCR économique qui extrait le texte des captures d'écran et l'envoie à l'API au lieu de l'image, avec fallback intelligent vers Vision.

---

## 🎯 Objectif Final

### Cas d'usage principal
L'utilisateur capture du texte tapé (emails, documents Word, pages web, code) et veut le faire corriger. Au lieu d'envoyer une image de 500 Ko à GPT-4 Vision (coûteux), on extrait le texte localement via OCR et on envoie uniquement le texte (économique et rapide).

### Flux utilisateur souhaité

```
Utilisateur capture une zone (⌥⇧S)
         ↓
OCR extrait le texte localement (Apple Vision)
         ↓
Confiance OCR ≥ 90% ?
    ├── OUI → Envoi du texte uniquement à l'API
    │         (mode économique)
    │
    └── NON → Fallback vers Vision
              (envoi de l'image comme avant)
         ↓
Affichage dans le chat :
- Image originale (miniature)
- Texte OCR extrait (si mode OCR)
- Indicateur du mode utilisé
         ↓
Réponse de GPT
```

---

## 📋 Spécifications Fonctionnelles

### 1. Mode de traitement

| Paramètre | Valeur | Justification |
|-----------|--------|---------------|
| **Mode par défaut** | OCR (économique) | Réduire les coûts API |
| **Seuil de confiance** | 90% | Équilibre entre économie et qualité |
| **Fallback automatique** | Oui | Si confiance < 90% OU texte vide |
| **Technologie OCR** | Apple Vision (`VNRecognizeTextRequest`) | Natif, gratuit, performant |

### 2. Préservation des retours à la ligne

**Exigence critique** : Préserver TOUS les retours à la ligne visuels de l'image originale.

**Méthode** : Utiliser les bounding boxes retournées par Apple Vision :
1. Trier les blocs de texte par position Y (de haut en bas)
2. Détecter les sauts de ligne quand l'écart Y entre deux blocs dépasse un seuil
3. Reconstruire le texte avec les `\n` aux bons endroits

```
Image originale:          Texte OCR extrait:
┌─────────────────┐
│ Bonjour,        │  →    "Bonjour,\n\n"
│                 │       "Voici le document.\n"
│ Voici le        │       "Cordialement"
│ document.       │
│                 │
│ Cordialement    │
└─────────────────┘
```

### 3. Prompt unifié

**Modification du prompt système** : Adapter le prompt pour accepter soit une image, soit du texte OCR.

**Formulation actuelle** :
```
"Analyse l'image fournie..."
```

**Nouvelle formulation** :
```
"Analyse l'image ou le texte fourni et corrige les fautes..."
```

**Impact** : Aucun changement côté backend, le prompt fonctionne pour les deux modes.

### 4. Détection automatique de la langue

| Option | Valeur |
|--------|--------|
| Langue de reconnaissance | Auto-détection |
| Langues supportées | Français, Anglais, Espagnol, Allemand, Italien |
| Priorité | Français (langue UI de l'app) |

**Code** :
```swift
request.recognitionLanguages = ["fr-FR", "en-US", "es-ES", "de-DE", "it-IT"]
request.usesLanguageCorrection = true // Améliore la précision
```

### 5. Affichage dans le chat

**Bulle utilisateur en mode OCR** :

```
┌──────────────────────────────────────────────┐
│  [🖼️ Miniature image] [📝 OCR]              │
│                                              │
│  Texte extrait :                             │
│  ────────────────                            │
│  Bonjour,                                    │
│                                              │
│  Voici le document demandé.                  │
│                                              │
│  Cordialement                                │
│                                              │
│  ⚡ Mode économique (confiance: 94%)         │
└──────────────────────────────────────────────┘
```

**Bulle utilisateur en mode Vision (fallback)** :

```
┌──────────────────────────────────────────────┐
│  [🖼️ Image complète]                         │
│                                              │
│  🔍 Mode Vision (confiance OCR insuffisante) │
└──────────────────────────────────────────────┘
```

### 6. Préférences utilisateur

**Nouvel élément dans l'onglet "Capture"** :

```
┌─ Capture d'écran ────────────────────────────┐
│                                              │
│  ☑️ Jouer un son après capture               │
│  ☑️ Envoyer automatiquement après capture    │
│                                              │
│  ── Mode d'analyse ──────────────────────    │
│  ◉ Mode économique (OCR)                     │
│      Extrait le texte et l'envoie à l'API.   │
│      ⚡ Plus rapide et moins cher.           │
│                                              │
│  ○ Mode Vision                               │
│      Envoie l'image complète à l'API.        │
│      🎨 Nécessaire pour images/graphiques.   │
│                                              │
│  ☑️ Fallback automatique si OCR incertain    │
│      (confiance < 90%)                       │
│                                              │
└──────────────────────────────────────────────┘
```

### 7. Gestion des erreurs

| Situation | Comportement |
|-----------|--------------|
| Texte vide (aucun texte détecté) | Fallback vers Vision + message info |
| Confiance < 90% | Fallback vers Vision automatique |
| OCR échoue (erreur système) | Fallback vers Vision + log warning |
| Mode OCR désactivé | Envoi image directement (comme avant) |

**Message d'erreur si OCR vide ET Vision impossible** :
```
"Aucun texte détecté dans l'image. Vérifiez que la capture contient du texte lisible."
```

---

## 🏗️ Architecture Technique

### Nouveau Service : `OCRService.swift`

```
Utilities/
├── ScreenCaptureService.swift    (existant)
├── SelectionOverlay/             (existant)
└── OCRService.swift              (NOUVEAU)
```

### Modèle de données : `OCRResult`

```swift
struct OCRResult {
    /// Texte extrait avec retours à la ligne préservés
    let text: String

    /// Confiance moyenne (0.0 - 1.0)
    let confidence: Float

    /// Nombre de lignes détectées
    let lineCount: Int

    /// Langue détectée (code ISO)
    let detectedLanguage: String?

    /// Durée de l'extraction (ms)
    let processingTimeMs: Int

    /// Indique si le fallback vers Vision est recommandé
    var shouldFallbackToVision: Bool {
        return text.isEmpty || confidence < 0.9
    }
}
```

### Extension du modèle `Message`

```swift
struct Message: Identifiable, Codable {
    // ... propriétés existantes ...

    /// Mode de traitement utilisé pour cette image (optionnel)
    var processingMode: ImageProcessingMode?

    /// Résultat OCR si mode OCR utilisé
    var ocrResult: OCRResult?
}

enum ImageProcessingMode: String, Codable {
    case vision    // Image envoyée à GPT-4 Vision
    case ocr       // Texte extrait localement et envoyé
    case ocrFallback // OCR tenté mais fallback vers Vision
}
```

### Modification de `AppPreferences`

```swift
struct AppPreferences: Codable {
    // ... existant ...

    // MARK: - Mode OCR

    /// Mode de traitement par défaut pour les captures
    var imageProcessingMode: ImageProcessingMode = .ocr

    /// Seuil de confiance OCR (0.0 - 1.0)
    var ocrConfidenceThreshold: Float = 0.9

    /// Activer le fallback automatique vers Vision
    var autoFallbackToVision: Bool = true
}
```

---

## 📋 Plan d'Implémentation Détaillé

> **Principe** : Chaque étape = 1 modification testable. On valide avant de passer à la suite.

---

## PHASE 1 : Service OCR (fondations)

### ÉTAPE 1.1 : Créer le fichier `OCRService.swift` avec structure de base

**Fichier** : `Utilities/OCRService.swift`

**Objectif** : Créer le squelette du service (compile, mais ne fait rien encore)

**Code** :

```swift
//
//  OCRService.swift
//  Correcteur Pro
//
//  Service d'extraction de texte (OCR) via Apple Vision
//

import Vision
import AppKit

// MARK: - OCR Service

/// Service d'extraction de texte via Apple Vision Framework
class OCRService {
    /// Singleton
    static let shared = OCRService()
    private init() {}
}
```

**Validation** :
- [ ] Le fichier est créé dans `Utilities/`
- [ ] Le projet compile sans erreur
- [ ] `OCRService.shared` est accessible

---

### ÉTAPE 1.2 : Ajouter la structure `OCRResult`

**Fichier** : `Utilities/OCRService.swift`

**Objectif** : Définir le modèle de données pour les résultats OCR

**Code à ajouter** (avant `class OCRService`) :

```swift
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
```

**Validation** :
- [ ] `OCRResult` est Codable
- [ ] `shouldFallbackToVision()` retourne `true` si confiance < 0.9

---

### ÉTAPE 1.3 : Ajouter l'enum `OCRError`

**Fichier** : `Utilities/OCRService.swift`

**Objectif** : Définir les erreurs possibles

**Code à ajouter** (après `OCRResult`) :

```swift
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
```

**Validation** :
- [ ] `OCRError` est LocalizedError
- [ ] Chaque cas a un message clair

---

### ÉTAPE 1.4 : Implémenter `extractText()` (version basique)

**Fichier** : `Utilities/OCRService.swift`

**Objectif** : Extraction de texte simple (SANS préservation des retours à la ligne)

**Code à ajouter** dans `class OCRService` :

```swift
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

    // 5. Assembler le texte (version simple : juste concaténer)
    var texts: [String] = []
    var confidences: [Float] = []

    for observation in observations {
        guard let candidate = observation.topCandidates(1).first else { continue }
        texts.append(candidate.string)
        confidences.append(candidate.confidence)
    }

    let text = texts.joined(separator: "\n")
    let avgConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)

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
```

**Validation** :
- [ ] Compile sans erreur
- [ ] Test manuel : créer un bouton temporaire qui appelle `OCRService.shared.extractText(from: image)` et print le résultat

**Test manuel suggéré** (dans ChatView ou ailleurs, temporairement) :
```swift
Button("Test OCR") {
    Task {
        if let image = NSImage(named: "test_image") { // ou une capture
            do {
                let result = try await OCRService.shared.extractText(from: image)
                print("OCR: \(result.text)")
                print("Confiance: \(result.confidence)")
            } catch {
                print("Erreur OCR: \(error)")
            }
        }
    }
}
```

---

### ÉTAPE 1.5 : Améliorer avec préservation des retours à la ligne

**Fichier** : `Utilities/OCRService.swift`

**Objectif** : Trier les blocs par position Y pour préserver la structure du texte

**Modification** : Remplacer la section "5. Assembler le texte" par :

```swift
// 5. Reconstruire le texte avec préservation des retours à la ligne
let (text, avgConfidence) = reconstructTextWithLineBreaks(
    observations: observations,
    imageHeight: CGFloat(cgImage.height)
)
```

**Ajouter cette méthode privée** dans `class OCRService` :

```swift
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
```

**Validation** :
- [ ] Compile sans erreur
- [ ] Test avec une image contenant plusieurs paragraphes → les sauts de ligne sont préservés

---

### ÉTAPE 1.6 : Test complet du service OCR en isolation

**Objectif** : Valider que le service fonctionne avant de l'intégrer

**Tests à effectuer** :

| Test | Image | Résultat attendu |
|------|-------|------------------|
| Texte simple | Email avec 1 paragraphe | Texte extrait, confiance > 90% |
| Multi-paragraphes | Document avec espaces | Retours à la ligne préservés |
| Texte flou | Screenshot basse qualité | Confiance < 90%, `shouldFallbackToVision() = true` |
| Image sans texte | Photo de paysage | Exception `OCRError.noTextFound` |
| Image vide | Rectangle blanc | Exception `OCRError.noTextFound` |

**Validation finale étape 1** :
- [ ] Tous les tests passent
- [ ] Le service est prêt pour l'intégration

---

## PHASE 2 : Modèles de données

### ÉTAPE 2.1 : Ajouter `ImageProcessingMode` dans AppPreferences

**Fichier** : `Models/AppPreferences.swift`

**Objectif** : Créer l'enum pour le mode de traitement

**Code à ajouter** (en haut du fichier, avant `struct AppPreferences`) :

```swift
// MARK: - Image Processing Mode

/// Mode de traitement pour les captures d'écran
enum ImageProcessingMode: String, Codable, CaseIterable {
    case ocr = "ocr"           // Extraction texte puis envoi
    case vision = "vision"     // Envoi image directement

    var displayName: String {
        switch self {
        case .ocr: return "Mode économique (OCR)"
        case .vision: return "Mode Vision"
        }
    }

    var description: String {
        switch self {
        case .ocr: return "Extrait le texte et l'envoie à l'API. Plus rapide et moins cher."
        case .vision: return "Envoie l'image complète à l'API. Nécessaire pour images/graphiques."
        }
    }

    var icon: String {
        switch self {
        case .ocr: return "bolt.fill"
        case .vision: return "eye.fill"
        }
    }
}
```

**Validation** :
- [ ] Compile sans erreur
- [ ] `ImageProcessingMode.allCases` retourne [.ocr, .vision]

---

### ÉTAPE 2.2 : Ajouter les préférences OCR dans AppPreferences

**Fichier** : `Models/AppPreferences.swift`

**Objectif** : Ajouter les propriétés de configuration OCR

**Code à ajouter** dans `struct AppPreferences` :

```swift
// MARK: - Mode OCR

/// Mode de traitement par défaut pour les captures
var imageProcessingMode: ImageProcessingMode = .ocr

/// Seuil de confiance OCR (0.0 - 1.0) - fallback vers Vision si inférieur
var ocrConfidenceThreshold: Float = 0.9

/// Activer le fallback automatique vers Vision si OCR incertain
var autoFallbackToVision: Bool = true
```

**Validation** :
- [ ] Compile sans erreur
- [ ] `PreferencesManager.shared.preferences.imageProcessingMode` retourne `.ocr` par défaut

---

### ÉTAPE 2.3 : Ajouter les métadonnées OCR dans Message

**Fichier** : `Models/Message.swift`

**Objectif** : Stocker les infos OCR dans chaque message

**Code à ajouter** dans `struct Message` :

```swift
// MARK: - OCR Metadata

/// Mode de traitement utilisé pour les images de ce message
var imageProcessingMode: ImageProcessingMode?

/// Texte OCR extrait (si mode OCR)
var ocrText: String?

/// Confiance OCR (si mode OCR)
var ocrConfidence: Float?

/// Indique si un fallback vers Vision a été effectué
var didFallbackToVision: Bool = false
```

**Validation** :
- [ ] Compile sans erreur
- [ ] Les anciens messages chargent toujours (propriétés optionnelles)
- [ ] Créer un nouveau message → les propriétés OCR sont nil par défaut

---

## PHASE 3 : Intégration dans le ViewModel

### ÉTAPE 3.1 : Ajouter la méthode de traitement OCR (sans l'utiliser)

**Fichier** : `ViewModels/ChatViewModel.swift`

**Objectif** : Créer la logique OCR sans modifier le flux existant

**Code à ajouter** (nouvelle section MARK) :

```swift
// MARK: - OCR Processing

/// Résultat du traitement d'une image
struct ImageProcessingResult {
    let ocrText: String?        // Texte extrait (nil si Vision)
    let sendImage: Bool         // true = envoyer l'image
    let ocrResult: OCRResult?   // Résultat OCR complet
    let fallbackReason: String? // Raison du fallback (nil si pas de fallback)
    let mode: ImageProcessingMode
}

/// Traite une image selon le mode configuré
/// - Parameter image: Image à traiter
/// - Returns: Résultat avec décision OCR/Vision
private func processImageForSending(_ image: NSImage) async -> ImageProcessingResult {
    let preferences = PreferencesManager.shared.preferences

    // Si mode Vision forcé, envoyer directement l'image
    guard preferences.imageProcessingMode == .ocr else {
        DebugLogger.shared.log("🎨 Mode Vision: envoi image directement", category: "OCR")
        return ImageProcessingResult(
            ocrText: nil,
            sendImage: true,
            ocrResult: nil,
            fallbackReason: nil,
            mode: .vision
        )
    }

    // Tenter l'OCR
    do {
        let ocrResult = try await OCRService.shared.extractText(from: image)

        DebugLogger.shared.logCapture(
            "📝 OCR: \(ocrResult.blockCount) blocs, confiance \(Int(ocrResult.confidence * 100))%"
        )

        // Vérifier si fallback nécessaire
        if ocrResult.shouldFallbackToVision(threshold: preferences.ocrConfidenceThreshold) {
            if preferences.autoFallbackToVision {
                let reason = ocrResult.isEmpty
                    ? "Aucun texte détecté"
                    : "Confiance insuffisante (\(Int(ocrResult.confidence * 100))%)"

                DebugLogger.shared.logWarning("⚠️ Fallback Vision: \(reason)")
                return ImageProcessingResult(
                    ocrText: nil,
                    sendImage: true,
                    ocrResult: ocrResult,
                    fallbackReason: reason,
                    mode: .vision
                )
            }
        }

        // OCR réussi
        return ImageProcessingResult(
            ocrText: ocrResult.text,
            sendImage: false,
            ocrResult: ocrResult,
            fallbackReason: nil,
            mode: .ocr
        )

    } catch {
        // Erreur OCR → fallback vers Vision
        DebugLogger.shared.logError("❌ OCR échoué: \(error.localizedDescription)")

        return ImageProcessingResult(
            ocrText: nil,
            sendImage: true,
            ocrResult: nil,
            fallbackReason: "Erreur: \(error.localizedDescription)",
            mode: .vision
        )
    }
}
```

**Validation** :
- [ ] Compile sans erreur
- [ ] La méthode existe mais n'est pas encore appelée
- [ ] Le flux existant fonctionne toujours

---

### ÉTAPE 3.2 : Créer une méthode `sendMessageWithOCR` (parallèle à l'existante)

**Fichier** : `ViewModels/ChatViewModel.swift`

**Objectif** : Nouvelle méthode qui intègre l'OCR, sans casser l'existante

**Code à ajouter** :

```swift
/// Envoie un message avec traitement OCR des images
/// - Parameters:
///   - text: Texte du message
///   - images: Images à traiter
/// - Returns: true si envoi réussi
@MainActor
func sendMessageWithOCR(_ text: String, images: [NSImage]) async -> Bool {
    guard !images.isEmpty else {
        // Pas d'images, utiliser sendMessage classique
        return sendMessage(text, images: [])
    }

    // Traiter chaque image
    var processedText = text
    var imagesToSend: [NSImage] = []
    var ocrTexts: [String] = []
    var finalMode: ImageProcessingMode = .ocr
    var finalConfidence: Float = 0
    var didFallback = false

    for image in images {
        let result = await processImageForSending(image)

        if let ocrText = result.ocrText {
            ocrTexts.append(ocrText)
            finalConfidence = result.ocrResult?.confidence ?? 0
        }

        if result.sendImage {
            imagesToSend.append(image)
            finalMode = .vision
            if result.fallbackReason != nil {
                didFallback = true
            }
        }
    }

    // Construire le message final
    if !ocrTexts.isEmpty {
        let ocrContent = ocrTexts.joined(separator: "\n\n---\n\n")
        if processedText.isEmpty {
            processedText = ocrContent
        } else {
            processedText = "\(processedText)\n\n---\n\nTexte extrait :\n\(ocrContent)"
        }
    }

    // Envoyer avec ou sans images selon le mode
    let success = sendMessage(processedText, images: imagesToSend)

    // TODO: Stocker les métadonnées OCR dans le message (étape suivante)

    return success
}
```

**Validation** :
- [ ] Compile sans erreur
- [ ] Test manuel avec une image : vérifier les logs OCR
- [ ] Le message est envoyé correctement

---

### ÉTAPE 3.3 : Connecter `sendMessageWithOCR` aux captures d'écran

**Fichier** : `Views/ContentView.swift`

**Objectif** : Utiliser la nouvelle méthode pour les captures

**Modification** dans `handleCapturedImage()` :

```swift
/// Traite une image capturée reçue via notification
private func handleCapturedImage(_ image: NSImage) {
    // Auto-envoi si activé ET conversation sélectionnée
    if PreferencesManager.shared.preferences.autoSendOnCapture,
       viewModel.selectedConversationID != nil {

        // Utiliser sendMessageWithOCR pour le traitement intelligent
        Task {
            _ = await viewModel.sendMessageWithOCR("", images: [image])
            DebugLogger.shared.logCapture("✅ Capture envoyée (mode OCR)")

            // Forcer le scroll vers le bas
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .forceScrollToBottom, object: nil)
                }
            }
        }
    } else {
        viewModel.capturedImage = image
        DebugLogger.shared.logCapture("✅ Capture ajoutée en attente")
    }
}
```

**Validation** :
- [ ] Capture ⌥⇧S → l'OCR est appelé (vérifier les logs)
- [ ] Si confiance > 90% → texte envoyé (pas d'image)
- [ ] Si confiance < 90% → image envoyée (fallback)

---

### ÉTAPE 3.4 : Stocker les métadonnées OCR dans le Message

**Fichier** : `ViewModels/ChatViewModel.swift`

**Objectif** : Sauvegarder le mode utilisé dans le message

**Modification** : Cette étape nécessite de modifier `sendMessage()` pour accepter les métadonnées OCR, OU de modifier le message après envoi.

**Option simple** : Ajouter une propriété `@Published` temporaire et la lire après envoi :

```swift
// Dans ChatViewModel, ajouter :
@Published var lastOCRResult: (mode: ImageProcessingMode, confidence: Float, didFallback: Bool)?

// Dans sendMessageWithOCR, avant return :
lastOCRResult = (finalMode, finalConfidence, didFallback)

// Puis modifier le dernier message ajouté pour y stocker les infos
if success, let lastMessage = conversations[safe: currentIndex]?.messages.last {
    // Mettre à jour le message avec les infos OCR
    // (nécessite de rendre Message mutable ou d'utiliser un index)
}
```

**Note** : Cette étape est plus complexe et peut être simplifiée. On peut la reporter à la Phase 4.

**Validation** :
- [ ] Le mode utilisé est visible dans les logs
- [ ] (Optionnel) Le message contient les métadonnées

---

## PHASE 4 : Interface utilisateur

### ÉTAPE 4.1 : Ajouter le toggle OCR/Vision dans les préférences

**Fichier** : `Views/Preferences/CapturePreferencesView.swift`

**Objectif** : UI pour choisir le mode

**Code à ajouter** (nouvelle Section) :

```swift
// MARK: - Mode d'analyse

Section {
    VStack(alignment: .leading, spacing: 12) {
        Text("Mode d'analyse des captures")
            .font(.headline)

        // Picker pour le mode
        Picker("Mode", selection: $prefsManager.preferences.imageProcessingMode) {
            ForEach(ImageProcessingMode.allCases, id: \.self) { mode in
                HStack {
                    Image(systemName: mode.icon)
                    Text(mode.displayName)
                }
                .tag(mode)
            }
        }
        .pickerStyle(.radioGroup)
        .onChange(of: prefsManager.preferences.imageProcessingMode) { _, _ in
            prefsManager.save()
        }

        Text(prefsManager.preferences.imageProcessingMode.description)
            .font(.caption)
            .foregroundColor(.secondary)
    }
} header: {
    Text("Traitement des images")
}
```

**Validation** :
- [ ] Le toggle est visible dans Préférences > Capture
- [ ] Changer le mode sauvegarde la préférence
- [ ] Au redémarrage, le mode est restauré

---

### ÉTAPE 4.2 : Ajouter l'option de fallback automatique

**Fichier** : `Views/Preferences/CapturePreferencesView.swift`

**Objectif** : Toggle pour activer/désactiver le fallback

**Code à ajouter** (dans la même Section) :

```swift
// Visible seulement si mode OCR
if prefsManager.preferences.imageProcessingMode == .ocr {
    Divider()

    Toggle("Fallback automatique vers Vision", isOn: $prefsManager.preferences.autoFallbackToVision)
        .onChange(of: prefsManager.preferences.autoFallbackToVision) { _, _ in
            prefsManager.save()
        }

    Text("Si la confiance OCR est inférieure à 90%, l'image sera envoyée à la place du texte.")
        .font(.caption)
        .foregroundColor(.secondary)
}
```

**Validation** :
- [ ] L'option apparaît seulement en mode OCR
- [ ] Le toggle fonctionne et sauvegarde

---

### ÉTAPE 4.3 : Afficher l'indicateur de mode dans les messages

**Fichier** : `Views/ChatView.swift` (dans MessageBubble)

**Objectif** : Montrer quel mode a été utilisé

**Code à ajouter** (en bas de la bulle utilisateur, si message a des images) :

```swift
// Indicateur de mode (si applicable)
if let mode = message.imageProcessingMode {
    HStack(spacing: 4) {
        Image(systemName: mode.icon)
            .font(.caption2)

        Text(mode == .ocr ? "Mode économique" : "Mode Vision")
            .font(.caption2)

        if message.didFallbackToVision {
            Text("(fallback)")
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }
    .foregroundColor(mode == .ocr ? .green : .blue)
    .padding(.top, 4)
}
```

**Validation** :
- [ ] L'indicateur s'affiche sur les nouveaux messages avec images
- [ ] Vert pour OCR, bleu pour Vision
- [ ] "fallback" en orange si applicable

---

### ÉTAPE 4.4 : Afficher le texte OCR extrait dans la bulle

**Fichier** : `Views/ChatView.swift` (dans MessageBubble)

**Objectif** : Montrer le texte extrait à l'utilisateur

**Code à ajouter** (après l'image, si ocrText présent) :

```swift
// Texte OCR extrait
if let ocrText = message.ocrText, !ocrText.isEmpty {
    VStack(alignment: .leading, spacing: 6) {
        Divider()
            .background(Color.white.opacity(0.2))

        Text("Texte extrait :")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white.opacity(0.6))

        Text(ocrText)
            .font(.body)
            .foregroundColor(.white.opacity(0.9))
            .textSelection(.enabled)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.05))
            )
    }
}
```

**Validation** :
- [ ] Le texte OCR s'affiche sous l'image
- [ ] Le texte est sélectionnable
- [ ] Le style est cohérent avec le reste de l'UI

---

## PHASE 5 : Finalisation

### ÉTAPE 5.1 : Adapter le prompt système

**Fichier** : `Models/AppPreferences.swift`

**Objectif** : Rendre le prompt compatible avec texte OU image

**Modification** : Dans `defaultPromptCorrecteur`, remplacer :
- "l'image" → "l'image ou le texte"
- "Analyse l'image" → "Analyse le contenu"

**Exemple** :
```swift
// Avant :
"Analyse l'image fournie et corrige les fautes d'orthographe..."

// Après :
"Analyse l'image ou le texte fourni et corrige les fautes d'orthographe..."
```

**Validation** :
- [ ] Le prompt fonctionne avec une image (comme avant)
- [ ] Le prompt fonctionne avec du texte OCR

---

### ÉTAPE 5.2 : Tests complets

**Objectif** : Valider tous les scénarios

| # | Test | Mode | Attendu |
|---|------|------|---------|
| 1 | Capture texte clair | OCR | Texte extrait, envoyé, indicateur vert |
| 2 | Capture texte flou | OCR→Vision | Fallback, image envoyée, indicateur "fallback" |
| 3 | Capture graphique | OCR→Vision | Fallback (pas de texte) |
| 4 | Mode Vision forcé | Vision | Image envoyée, indicateur bleu |
| 5 | Fallback désactivé + OCR incertain | OCR | Texte envoyé quand même |
| 6 | Préférences persistées | - | Mode et options sauvegardés au redémarrage |
| 7 | Anciens messages | - | Pas de crash, pas d'indicateur OCR |

**Validation finale** :
- [ ] Tous les tests passent
- [ ] Pas de régression sur l'existant
- [ ] Performance acceptable (< 500ms pour OCR)

---

### ÉTAPE 5.3 : Documentation et commit

**Objectif** : Finaliser et documenter

1. Mettre à jour `CLAUDE.md` avec les nouvelles infos OCR
2. Commit avec message descriptif
3. Tester une dernière fois en production

---

## 📊 Résumé des étapes

| Phase | Étape | Description | Complexité |
|-------|-------|-------------|------------|
| 1 | 1.1 | Créer OCRService (squelette) | 🟢 Simple |
| 1 | 1.2 | Ajouter OCRResult | 🟢 Simple |
| 1 | 1.3 | Ajouter OCRError | 🟢 Simple |
| 1 | 1.4 | Implémenter extractText (basique) | 🟡 Moyen |
| 1 | 1.5 | Préservation retours à la ligne | 🟡 Moyen |
| 1 | 1.6 | Tests service OCR | 🟢 Simple |
| 2 | 2.1 | Ajouter ImageProcessingMode | 🟢 Simple |
| 2 | 2.2 | Ajouter préférences OCR | 🟢 Simple |
| 2 | 2.3 | Ajouter métadonnées Message | 🟢 Simple |
| 3 | 3.1 | Méthode processImageForSending | 🟡 Moyen |
| 3 | 3.2 | Méthode sendMessageWithOCR | 🟡 Moyen |
| 3 | 3.3 | Connecter aux captures | 🟢 Simple |
| 3 | 3.4 | Stocker métadonnées | 🟠 Complexe |
| 4 | 4.1 | Toggle mode dans préférences | 🟢 Simple |
| 4 | 4.2 | Option fallback | 🟢 Simple |
| 4 | 4.3 | Indicateur mode dans bulle | 🟢 Simple |
| 4 | 4.4 | Afficher texte OCR | 🟢 Simple |
| 5 | 5.1 | Adapter prompt | 🟢 Simple |
| 5 | 5.2 | Tests complets | 🟡 Moyen |
| 5 | 5.3 | Documentation | 🟢 Simple |

**Total : 20 micro-étapes**

---

## ⚠️ Points de validation critiques

Après chaque phase, s'assurer que :

- **Fin Phase 1** : OCRService fonctionne en isolation (test manuel)
- **Fin Phase 2** : Les modèles compilent et sont rétrocompatibles
- **Fin Phase 3** : Les captures utilisent l'OCR (vérifier logs)
- **Fin Phase 4** : L'UI reflète le mode utilisé
- **Fin Phase 5** : Tout fonctionne de bout en bout

---

**Ancienne version du code complet** (pour référence) :

```swift
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

    /// Langues détectées
    let detectedLanguages: [String]

    /// Durée de l'extraction (millisecondes)
    let processingTimeMs: Int

    /// Indique si le texte est vide
    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
    case cancelled

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Impossible de convertir l'image pour l'OCR"
        case .noTextFound:
            return "Aucun texte détecté dans l'image"
        case .recognitionFailed(let error):
            return "Erreur de reconnaissance : \(error.localizedDescription)"
        case .cancelled:
            return "Reconnaissance annulée"
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
    /// - Parameters:
    ///   - image: Image source (capture d'écran)
    ///   - languages: Langues de reconnaissance (défaut: fr, en)
    /// - Returns: OCRResult avec le texte extrait et la confiance
    func extractText(from image: NSImage, languages: [String]? = nil) async throws -> OCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. Convertir NSImage en CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }

        // 2. Créer la requête de reconnaissance
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate // Précision maximale
        request.usesLanguageCorrection = true // Correction linguistique

        // Langues de reconnaissance (priorité : français, anglais, puis autres)
        let recognitionLanguages = languages ?? ["fr-FR", "en-US", "es-ES", "de-DE", "it-IT"]
        request.recognitionLanguages = recognitionLanguages

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

        // 6. Détecter les langues présentes
        let detectedLanguages = detectLanguages(in: text)

        // 7. Calculer le temps de traitement
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTimeMs = Int((endTime - startTime) * 1000)

        // 8. Logger le résultat
        DebugLogger.shared.log(
            "📝 OCR terminé: \(observations.count) blocs, confiance \(Int(avgConfidence * 100))%, \(processingTimeMs)ms",
            category: "OCR"
        )

        return OCRResult(
            text: text,
            confidence: avgConfidence,
            blockCount: observations.count,
            detectedLanguages: detectedLanguages,
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
        // Note: Les coordonnées Vision sont normalisées (0-1) avec Y inversé
        let sortedObservations = observations.sorted { obs1, obs2 in
            // Y plus grand = plus haut dans l'image (Vision inverse Y)
            obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
        }

        var lines: [String] = []
        var confidences: [Float] = []
        var lastY: CGFloat = 1.0 // Commence en haut

        // Seuil pour détecter un saut de ligne (en proportion de la hauteur)
        // Une ligne de texte standard fait environ 2-3% de la hauteur de l'image
        let lineHeightThreshold: CGFloat = 0.025

        for observation in sortedObservations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let currentY = observation.boundingBox.origin.y + observation.boundingBox.height
            let yDifference = lastY - currentY

            // Détecter si on doit ajouter un retour à la ligne
            if yDifference > lineHeightThreshold * 2 {
                // Grand écart = paragraphe (ajouter ligne vide)
                if !lines.isEmpty {
                    lines.append("")
                }
            }

            lines.append(candidate.string)
            confidences.append(candidate.confidence)
            lastY = observation.boundingBox.origin.y
        }

        let text = lines.joined(separator: "\n")
        let avgConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)

        return (text, avgConfidence)
    }

    /// Détecte les langues présentes dans le texte
    private func detectLanguages(in text: String) -> [String] {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        var languages: [String] = []

        if let dominantLanguage = recognizer.dominantLanguage {
            languages.append(dominantLanguage.rawValue)
        }

        // Ajouter les autres langues détectées avec probabilité > 20%
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        for (language, probability) in hypotheses where probability > 0.2 {
            if !languages.contains(language.rawValue) {
                languages.append(language.rawValue)
            }
        }

        return languages
    }
}
```

**Vérification** :
- [ ] Le fichier compile sans erreur
- [ ] Les imports Vision et NaturalLanguage sont présents
- [ ] La structure OCRResult est bien Codable

**Risques** :
- Performance avec très grandes images → Tester avec captures 4K
- Ordre des blocs incorrect → Ajuster `lineHeightThreshold`

---

### ÉTAPE 2 : Modifier `AppPreferences.swift`

**Fichier** : `Models/AppPreferences.swift`

**Objectif** : Ajouter les préférences pour le mode OCR

**Modifications** :

```swift
// Ajouter après les préférences de capture existantes

// MARK: - Mode OCR

/// Mode de traitement pour les captures d'écran
enum ImageProcessingMode: String, Codable, CaseIterable {
    case ocr = "ocr"           // Extraction texte puis envoi
    case vision = "vision"     // Envoi image directement

    var displayName: String {
        switch self {
        case .ocr: return "Mode économique (OCR)"
        case .vision: return "Mode Vision"
        }
    }

    var description: String {
        switch self {
        case .ocr: return "Extrait le texte et l'envoie à l'API. Plus rapide et moins cher."
        case .vision: return "Envoie l'image complète à l'API. Nécessaire pour images/graphiques."
        }
    }

    var icon: String {
        switch self {
        case .ocr: return "⚡"
        case .vision: return "🎨"
        }
    }
}

// Dans struct AppPreferences, ajouter :

/// Mode de traitement par défaut pour les captures
var imageProcessingMode: ImageProcessingMode = .ocr

/// Seuil de confiance OCR (0.0 - 1.0) - fallback vers Vision si inférieur
var ocrConfidenceThreshold: Float = 0.9

/// Activer le fallback automatique vers Vision si OCR incertain
var autoFallbackToVision: Bool = true
```

**Vérification** :
- [ ] `ImageProcessingMode` est Codable et CaseIterable
- [ ] Valeurs par défaut correctes (OCR par défaut, seuil 0.9)

---

### ÉTAPE 3 : Modifier `Message.swift`

**Fichier** : `Models/Message.swift`

**Objectif** : Stocker le mode de traitement et les infos OCR dans chaque message

**Modifications** :

```swift
// Ajouter dans struct Message :

/// Mode de traitement utilisé pour les images de ce message
var imageProcessingMode: ImageProcessingMode?

/// Texte OCR extrait (si mode OCR)
var ocrText: String?

/// Confiance OCR (si mode OCR)
var ocrConfidence: Float?

/// Indique si un fallback vers Vision a été effectué
var didFallbackToVision: Bool = false
```

**Note** : Ces propriétés sont optionnelles pour rester compatible avec les messages existants.

**Vérification** :
- [ ] Les nouvelles propriétés sont optionnelles
- [ ] La rétrocompatibilité avec les anciens messages est préservée

---

### ÉTAPE 4 : Modifier `ChatViewModel.swift`

**Fichier** : `ViewModels/ChatViewModel.swift`

**Objectif** : Intégrer la logique OCR dans le flux d'envoi de message

**Modifications principales** :

```swift
// MARK: - OCR Processing

/// Traite une image selon le mode configuré
/// - Returns: (messageText, shouldSendImage, ocrResult)
private func processImageForSending(_ image: NSImage) async -> (
    text: String?,
    sendImage: Bool,
    ocrResult: OCRResult?,
    fallbackReason: String?
) {
    let preferences = PreferencesManager.shared.preferences

    // Si mode Vision, envoyer directement l'image
    guard preferences.imageProcessingMode == .ocr else {
        DebugLogger.shared.log("🎨 Mode Vision: envoi image directement", category: "OCR")
        return (nil, true, nil, nil)
    }

    // Tenter l'OCR
    do {
        let ocrResult = try await OCRService.shared.extractText(from: image)

        DebugLogger.shared.logCapture(
            "📝 OCR: \(ocrResult.blockCount) blocs, confiance \(Int(ocrResult.confidence * 100))%"
        )

        // Vérifier si fallback nécessaire
        if ocrResult.shouldFallbackToVision(threshold: preferences.ocrConfidenceThreshold) {
            if preferences.autoFallbackToVision {
                let reason = ocrResult.isEmpty
                    ? "Aucun texte détecté"
                    : "Confiance insuffisante (\(Int(ocrResult.confidence * 100))%)"

                DebugLogger.shared.logWarning("⚠️ Fallback Vision: \(reason)")
                return (nil, true, ocrResult, reason)
            } else {
                // Pas de fallback auto, envoyer le texte OCR quand même
                DebugLogger.shared.logWarning("⚠️ OCR incertain mais fallback désactivé")
                return (ocrResult.text, false, ocrResult, nil)
            }
        }

        // OCR réussi avec bonne confiance
        return (ocrResult.text, false, ocrResult, nil)

    } catch {
        // Erreur OCR → fallback vers Vision
        DebugLogger.shared.logError("❌ OCR échoué: \(error.localizedDescription)")

        if preferences.autoFallbackToVision {
            return (nil, true, nil, "Erreur OCR: \(error.localizedDescription)")
        } else {
            // Pas de fallback, annuler l'envoi
            return (nil, false, nil, "Erreur OCR: \(error.localizedDescription)")
        }
    }
}

// Modifier sendMessage() pour intégrer l'OCR :

func sendMessage(_ text: String, images: [NSImage] = []) -> Bool {
    // ... code existant pour validation ...

    // Traitement OCR si images présentes
    var processedImages: [NSImage] = []
    var ocrTexts: [String] = []
    var ocrResults: [OCRResult] = []
    var fallbackReasons: [String] = []

    if !images.isEmpty {
        Task {
            for image in images {
                let result = await processImageForSending(image)

                if let ocrText = result.text {
                    ocrTexts.append(ocrText)
                }
                if result.sendImage {
                    processedImages.append(image)
                }
                if let ocrResult = result.ocrResult {
                    ocrResults.append(ocrResult)
                }
                if let reason = result.fallbackReason {
                    fallbackReasons.append(reason)
                }
            }

            // Continuer l'envoi avec les données traitées
            await MainActor.run {
                self.sendProcessedMessage(
                    text: text,
                    ocrTexts: ocrTexts,
                    images: processedImages,
                    ocrResults: ocrResults,
                    fallbackReasons: fallbackReasons
                )
            }
        }
        return true
    }

    // Pas d'images, envoi normal
    // ... code existant ...
}
```

**Vérification** :
- [ ] La logique OCR est correctement intégrée
- [ ] Le fallback vers Vision fonctionne
- [ ] Les métadonnées OCR sont sauvegardées dans le Message

---

### ÉTAPE 5 : Modifier la vue de préférences

**Fichier** : `Views/Preferences/CapturePreferencesView.swift`

**Objectif** : Ajouter les options OCR dans l'interface de préférences

**Code** :

```swift
// MARK: - Mode d'analyse

Section {
    VStack(alignment: .leading, spacing: 12) {
        Text("Mode d'analyse")
            .font(.headline)
            .foregroundColor(.white)

        // Radio buttons pour le mode
        ForEach(ImageProcessingMode.allCases, id: \.self) { mode in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: preferences.imageProcessingMode == mode
                    ? "circle.inset.filled"
                    : "circle")
                    .foregroundColor(preferences.imageProcessingMode == mode
                        ? .blue
                        : .gray)
                    .onTapGesture {
                        preferences.imageProcessingMode = mode
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(mode.icon) \(mode.displayName)")
                        .font(.body)
                        .foregroundColor(.white)

                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
        }

        // Option fallback (visible seulement si mode OCR)
        if preferences.imageProcessingMode == .ocr {
            Divider()
                .background(Color.white.opacity(0.1))

            Toggle(isOn: $preferences.autoFallbackToVision) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fallback automatique si OCR incertain")
                        .font(.body)
                        .foregroundColor(.white)

                    Text("Envoie l'image si la confiance OCR < \(Int(preferences.ocrConfidenceThreshold * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
} header: {
    Text("Traitement des captures")
}
```

**Vérification** :
- [ ] Les radio buttons fonctionnent
- [ ] L'option fallback est visible seulement en mode OCR
- [ ] Les préférences sont sauvegardées correctement

---

### ÉTAPE 6 : Modifier l'affichage des messages

**Fichier** : `Views/ChatView.swift` (MessageBubble)

**Objectif** : Afficher le texte OCR et l'indicateur de mode dans la bulle utilisateur

**Modifications** :

```swift
// Dans MessageBubble, ajouter après l'affichage de l'image :

// Affichage du texte OCR extrait
if let ocrText = message.ocrText, !ocrText.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        // Séparateur
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)

        // Label "Texte extrait"
        Text("Texte extrait :")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white.opacity(0.6))

        // Texte OCR
        Text(ocrText)
            .font(.body)
            .foregroundColor(.white.opacity(0.9))
            .textSelection(.enabled)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
    }
}

// Indicateur de mode (en bas de la bulle)
if message.imageProcessingMode != nil {
    HStack(spacing: 6) {
        if message.imageProcessingMode == .ocr {
            Image(systemName: "bolt.fill")
                .font(.caption2)
                .foregroundColor(.green)

            if let confidence = message.ocrConfidence {
                Text("Mode économique (\(Int(confidence * 100))%)")
                    .font(.caption2)
                    .foregroundColor(.green.opacity(0.8))
            }
        } else if message.didFallbackToVision {
            Image(systemName: "eye.fill")
                .font(.caption2)
                .foregroundColor(.orange)

            Text("Vision (fallback)")
                .font(.caption2)
                .foregroundColor(.orange.opacity(0.8))
        } else {
            Image(systemName: "eye.fill")
                .font(.caption2)
                .foregroundColor(.blue)

            Text("Mode Vision")
                .font(.caption2)
                .foregroundColor(.blue.opacity(0.8))
        }
    }
    .padding(.top, 6)
}
```

**Vérification** :
- [ ] Le texte OCR s'affiche correctement
- [ ] L'indicateur de mode est visible
- [ ] Les couleurs sont cohérentes (vert = OCR, orange = fallback, bleu = Vision)

---

### ÉTAPE 7 : Modifier le prompt système

**Fichier** : `Models/AppPreferences.swift` (defaultPromptCorrecteur)

**Objectif** : Adapter le prompt pour accepter image OU texte

**Modification** :

Remplacer toute référence à "l'image" par "l'image ou le texte".

**Exemple** :

```swift
// Avant :
"Analyse l'image fournie et corrige les fautes..."

// Après :
"Analyse l'image ou le texte fourni et corrige les fautes..."
```

**Note** : Cette modification est rétrocompatible car le prompt fonctionne déjà pour du texte pur.

---

### ÉTAPE 8 : Tests et validation

**Tests manuels à effectuer** :

| Test | Mode | Résultat attendu |
|------|------|------------------|
| Capture texte clair (email) | OCR | Texte extrait, envoyé comme texte |
| Capture texte flou | OCR | Fallback vers Vision (confiance < 90%) |
| Capture image/graphique | OCR | Fallback vers Vision (pas de texte) |
| Capture texte avec mode Vision forcé | Vision | Image envoyée directement |
| Fallback désactivé + OCR incertain | OCR | Texte OCR envoyé (même si incertain) |
| Capture texte multilingue | OCR | Détection langue correcte |
| Très longue capture (document) | OCR | Performance acceptable (< 2s) |

**Tests de régression** :

| Test | Résultat attendu |
|------|------------------|
| Envoi message texte seul | Fonctionne comme avant |
| Envoi image sans OCR configuré | Fonctionne comme avant |
| Changement de conversation | Pas de crash |
| Rechargement app | Préférences OCR persistées |

---

## 🔧 Points d'attention techniques

### 1. Performance OCR

**Problème potentiel** : L'OCR peut être lent sur des images très grandes.

**Solutions** :
- Exécuter l'OCR en arrière-plan (async/await)
- Afficher un indicateur de progression "Extraction du texte..."
- Redimensionner l'image si trop grande (> 4K)

### 2. Préservation des retours à la ligne

**Problème potentiel** : Apple Vision retourne les blocs dans un ordre imprévisible.

**Solution implémentée** :
- Tri par coordonnée Y (boundingBox)
- Détection d'écart Y pour insérer des `\n`
- Seuil configurable (`lineHeightThreshold`)

### 3. Rétrocompatibilité

**Exigence** : Les anciens messages (sans metadata OCR) doivent continuer à fonctionner.

**Solution** :
- Toutes les nouvelles propriétés sont optionnelles
- Codable avec decoder configuré pour valeurs manquantes
- UI s'adapte (n'affiche pas l'indicateur OCR si nil)

### 4. Coût API

**Estimation des économies** :

| Mode | Coût par requête (approx.) |
|------|----------------------------|
| Vision (image 500 Ko) | ~0.01$ (selon taille) |
| OCR (texte 2000 chars) | ~0.0002$ |
| **Économie** | **~98%** |

---

## 📊 Métriques de succès

### Fonctionnel
- [ ] OCR extrait correctement le texte de captures d'écran standard
- [ ] Les retours à la ligne sont préservés fidèlement
- [ ] Le fallback vers Vision fonctionne automatiquement
- [ ] L'indicateur de mode est visible et correct

### Performance
- [ ] OCR < 500ms pour image standard (1080p)
- [ ] OCR < 2s pour très grande image (4K)
- [ ] Pas de freeze de l'UI pendant l'OCR

### UX
- [ ] Le toggle OCR/Vision est clair et accessible
- [ ] L'utilisateur comprend quel mode est utilisé
- [ ] Pas de régression sur le workflow existant

---

## 📁 Fichiers à créer/modifier

| Fichier | Action | Priorité |
|---------|--------|----------|
| `Utilities/OCRService.swift` | CRÉER | P0 |
| `Models/AppPreferences.swift` | MODIFIER | P0 |
| `Models/Message.swift` | MODIFIER | P0 |
| `ViewModels/ChatViewModel.swift` | MODIFIER | P0 |
| `Views/Preferences/CapturePreferencesView.swift` | MODIFIER | P1 |
| `Views/ChatView.swift` (MessageBubble) | MODIFIER | P1 |

---

## 🚀 Ordre d'implémentation recommandé

1. **Phase 1 - Core (P0)**
   - Étape 1 : Créer `OCRService.swift`
   - Étape 2 : Modifier `AppPreferences.swift`
   - Étape 3 : Modifier `Message.swift`
   - Test : Vérifier que l'OCR fonctionne en isolation

2. **Phase 2 - Intégration (P0)**
   - Étape 4 : Modifier `ChatViewModel.swift`
   - Test : Vérifier le flux complet (capture → OCR → envoi)

3. **Phase 3 - UI (P1)**
   - Étape 5 : Modifier les préférences
   - Étape 6 : Modifier l'affichage des messages
   - Étape 7 : Adapter le prompt
   - Test : Vérifier l'UX complète

4. **Phase 4 - Polish**
   - Étape 8 : Tests complets
   - Ajustements selon retours
   - Documentation mise à jour

---

## ⚠️ Risques et mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| OCR imprécis sur certaines polices | Moyenne | Moyen | Fallback automatique vers Vision |
| Performance dégradée sur 4K | Faible | Faible | Redimensionnement préalable |
| Retours à la ligne mal détectés | Moyenne | Moyen | Ajuster `lineHeightThreshold` |
| Anciens messages cassés | Faible | Élevé | Propriétés optionnelles + tests |
| Préférences non sauvegardées | Faible | Moyen | Vérifier `PreferencesManager` |

---

## 📝 Notes finales

Ce plan détaille une implémentation progressive du mode OCR intelligent. Les phases P0 doivent être complétées en premier car elles constituent le cœur de la fonctionnalité. Les phases P1 améliorent l'UX mais ne sont pas bloquantes pour les tests initiaux.

**Points clés à retenir** :
1. **OCR par défaut** = économie de coûts significative
2. **Fallback automatique** = pas de perte de qualité
3. **Préservation des retours à la ligne** = fidélité au document original
4. **Indicateur visible** = transparence pour l'utilisateur

La prochaine étape après validation de ce plan est de commencer l'implémentation par `OCRService.swift`.
