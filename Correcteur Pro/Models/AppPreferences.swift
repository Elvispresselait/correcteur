//
//  AppPreferences.swift
//  Correcteur Pro
//
//  Modèle de préférences de l'application avec sauvegarde dans UserDefaults
//

import Foundation
import CoreGraphics

struct AppPreferences: Codable {
    // MARK: - CAPTURE

    var selectedDisplayID: CGDirectDisplayID?
    var captureMode: CaptureMode = .mainDisplay
    var compressionQuality: CompressionQuality = .high
    var playsSoundAfterCapture: Bool = true
    var showsCursorInCapture: Bool = false
    var outputFormat: CaptureImageFormat = .png
    var autoSendOnCapture: Bool = true

    // MARK: - RACCOURCIS (stockés comme String "⌥⇧S")

    var hotKeyMainDisplay: String = "⌥⇧X"
    var hotKeyAllDisplays: String = "⌥⇧A"
    var hotKeySelection: String = "⌥⇧S"

    // MARK: - INTERFACE

    var theme: AppTheme = .auto
    var fontSize: Double = 14.0
    var windowPosition: WindowPosition = .center
    var launchAtLogin: Bool = false
    var showInDock: Bool = true  // Visible par défaut, option pour masquer

    // MARK: - API

    var defaultModel: OpenAIModel = .gpt4o
    var maxTokens: Int = 4096
    var showTokenUsage: Bool = true

    // MARK: - CONVERSATIONS

    var historyMessageCount: Int = 20
    var exportFolder: String?

    // MARK: - PROMPTS SYSTÈME (un pour chaque type)

    /// Prompt pour le correcteur orthographique
    var promptCorrecteur: String = AppPreferences.defaultPromptCorrecteur

    /// Prompt par défaut pour le correcteur (avec exemples intégrés)
    static let defaultPromptCorrecteur: String = """
Tu es un correcteur orthographique expert et CONSERVATEUR. Tu ne corriges QUE les vraies fautes.

## ⚠️ RÈGLE FONDAMENTALE : NE PAS INVENTER DE FAUTES

AVANT de corriger un mot, vérifie qu'il contient VRAIMENT une erreur :
- "un récapitulatif" est CORRECT (récapitulatif = masculin) → NE PAS corriger
- "une récapitulation" est CORRECT (récapitulation = féminin) → NE PAS corriger
- "prêter" après "à" est CORRECT (infinitif) → NE PAS corriger
- Si tu n'es pas SÛR à 100% qu'il y a une faute → NE PAS corriger

## RÈGLES DE FORMATAGE

1. **Lettre(s) à supprimer** : **mot_corrigé**~~lettres_supprimées~~
2. **Mot remplacé** : ~~ancien~~ **nouveau**
3. **Mot ajouté** : **mot_ajouté**
4. **Mot en trop** : ~~mot_supprimé~~

## INDICATEURS

- ❌ = paragraphe avec correction(s)
- ✅ = paragraphe SANS correction (texte correct)

## EXEMPLES DE VRAIES FAUTES À CORRIGER

### "utiles" → "utile" (accord avec COD singulier "le")
Entrée : "Si les Parties le jugent utiles"
Sortie : "❌ Si les Parties le jugent **utile**~~s~~"

### "un récapitulation" → "une récapitulation" (féminin)
Entrée : "un récapitulation des travaux"
Sortie : "❌ ~~un~~ **une** récapitulation des travaux"

### "prêté" → "prêter" (infinitif après "à")
Entrée : "s'engage à prêté son concours"
Sortie : "❌ s'engage à ~~prêté~~ **prêter** son concours"

## EXEMPLES DE TEXTES CORRECTS (NE PAS MODIFIER)

### Texte 1 - Aucune faute
Entrée : "un récapitulatif des Créations pourra être établi"
Sortie : "✅ un récapitulatif des Créations pourra être établi"
Explication : "un récapitulatif" est correct (masculin), NE PAS changer en "une"

### Texte 2 - Aucune faute
Entrée : "Chacune des Parties s'engage à prêter son concours"
Sortie : "✅ Chacune des Parties s'engage à prêter son concours"
Explication : "prêter" est déjà à l'infinitif, NE PAS le barrer

### Texte 3 - Aucune faute
Entrée : "Le présent contrat est conclu pour une durée indéterminée."
Sortie : "✅ Le présent contrat est conclu pour une durée indéterminée."

## EXEMPLE COMPLET AVEC SEULEMENT 2 VRAIES FAUTES

Entrée :
"Si les Parties le jugent utiles, un récapitulatif des Créations pourra être établi. Chacune des Parties s'engage à prêter son concours."

Sortie :
"❌ Si les Parties le jugent **utile**~~s~~, un récapitulatif des Créations pourra être établi. ✅ Chacune des Parties s'engage à prêter son concours."

Note : "un récapitulatif" et "prêter" sont CORRECTS → pas de modification

## INSTRUCTIONS FINALES

1. Reproduis le texte ENTIER avec corrections inline
2. Respecte les retours à la ligne
3. NE corrige QUE les VRAIES fautes (orthographe, grammaire, accords)
4. En cas de DOUTE → ne corrige PAS
5. Format Markdown : ~~barré~~, **gras**
"""

    /// Prompt pour l'assistant général
    var promptAssistant: String = """
Tu es un assistant IA utile, respectueux et honnête. Réponds toujours de manière claire et concise.
"""

    /// Prompt pour le traducteur
    var promptTraducteur: String = """
Tu es un traducteur professionnel. Traduis le texte fourni de manière précise et naturelle, en conservant le style et le ton de l'original.
"""

    /// Prompts personnalisés créés par l'utilisateur (id -> CustomPrompt)
    var customPrompts: [CustomPrompt] = []

    // Rétrocompatibilité avec l'ancien systemPrompt
    var systemPrompt: String {
        get { promptCorrecteur }
        set { promptCorrecteur = newValue }
    }
}

/// Un prompt personnalisé créé par l'utilisateur
struct CustomPrompt: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var content: String
    var createdAt: Date = Date()
    var archivedAt: Date? = nil // Date d'archivage (nil = actif)

    /// Indique si le prompt est archivé
    var isArchived: Bool {
        archivedAt != nil
    }

    /// Nombre de jours restants avant suppression définitive (90 jours après archivage)
    var daysUntilDeletion: Int? {
        guard let archivedAt = archivedAt else { return nil }
        let deletionDate = Calendar.current.date(byAdding: .day, value: 90, to: archivedAt) ?? archivedAt
        let days = Calendar.current.dateComponents([.day], from: Date(), to: deletionDate).day ?? 0
        return max(0, days)
    }

    /// Indique si le prompt doit être supprimé définitivement (archivé depuis plus de 90 jours)
    var shouldBeDeleted: Bool {
        guard let archivedAt = archivedAt else { return false }
        let daysSinceArchive = Calendar.current.dateComponents([.day], from: archivedAt, to: Date()).day ?? 0
        return daysSinceArchive >= 90
    }
}

// MARK: - Enums

enum CaptureMode: String, Codable, CaseIterable {
    case mainDisplay = "Écran principal"
    case allDisplays = "Tous les écrans"
    case specificDisplay = "Écran sélectionné"
}

enum CompressionQuality: String, Codable, CaseIterable {
    case none = "Aucune"
    case low = "Basse"
    case medium = "Moyenne"
    case high = "Haute"

    var compressionRatio: Double {
        switch self {
        case .none: return 1.0
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.7
        }
    }
}

enum CaptureImageFormat: String, Codable, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "Clair"
    case dark = "Sombre"
    case auto = "Auto"
}

enum WindowPosition: String, Codable, CaseIterable {
    case center = "Centre"
    case lastPosition = "Dernière position"
}

enum OpenAIModel: String, Codable, CaseIterable {
    case gpt4o = "GPT-4o"
    case gpt4Turbo = "GPT-4 Turbo"
    case gpt35Turbo = "GPT-3.5 Turbo"

    var displayName: String { rawValue }

    var costPer1kInputTokens: Double {
        switch self {
        case .gpt4o: return 0.005
        case .gpt4Turbo: return 0.01
        case .gpt35Turbo: return 0.0005
        }
    }

    var costPer1kOutputTokens: Double {
        switch self {
        case .gpt4o: return 0.015
        case .gpt4Turbo: return 0.03
        case .gpt35Turbo: return 0.0015
        }
    }

    var apiModelName: String {
        switch self {
        case .gpt4o: return "gpt-4o"
        case .gpt4Turbo: return "gpt-4-turbo"
        case .gpt35Turbo: return "gpt-3.5-turbo"
        }
    }
}
