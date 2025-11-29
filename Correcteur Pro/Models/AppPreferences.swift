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

    // MARK: - RACCOURCIS (stockés comme String "⌥⇧S")

    var hotKeyMainDisplay: String = "⌥⇧S"
    var hotKeyAllDisplays: String = "⌥⇧A"
    var hotKeySelection: String = "⌥⇧X"

    // MARK: - INTERFACE

    var theme: AppTheme = .auto
    var fontSize: Double = 14.0
    var windowPosition: WindowPosition = .center
    var launchAtLogin: Bool = false

    // MARK: - API

    var defaultModel: OpenAIModel = .gpt4o
    var maxTokens: Int = 4096
    var showTokenUsage: Bool = true

    // MARK: - CONVERSATIONS

    var historyMessageCount: Int = 20
    var exportFolder: String?

    // MARK: - PROMPTS SYSTÈME (un pour chaque type)

    /// Prompt pour le correcteur orthographique
    var promptCorrecteur: String = """
Je veux que tu ne regardes que la partie surlignée.
Tu me la re-rediges complètement en respectant les retours à la ligne.

Ensuite pour chaque faute, tu me rayes le mot entier où il y a la faute, ou les mots entiers où il y a les fautes.
Tu rajoutes un espace devant avec et tu mets en gras et soulignés les mots que tu rajoutes pour corriger.

Ensuite, devant chaque paragraphe que tu as modifié, je veux que tu rajoutes une croix rouge (❌).
Et pour les autres paragraphes qui restent, je veux que tu rajoutes une croix verte (✅) devant chaque paragraphe.
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

    /// Nombre de jours restants avant suppression définitive (30 jours après archivage)
    var daysUntilDeletion: Int? {
        guard let archivedAt = archivedAt else { return nil }
        let deletionDate = Calendar.current.date(byAdding: .day, value: 30, to: archivedAt) ?? archivedAt
        let days = Calendar.current.dateComponents([.day], from: Date(), to: deletionDate).day ?? 0
        return max(0, days)
    }

    /// Indique si le prompt doit être supprimé définitivement (archivé depuis plus de 30 jours)
    var shouldBeDeleted: Bool {
        guard let archivedAt = archivedAt else { return false }
        let daysSinceArchive = Calendar.current.dateComponents([.day], from: archivedAt, to: Date()).day ?? 0
        return daysSinceArchive >= 30
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
