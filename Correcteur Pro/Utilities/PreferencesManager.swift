//
//  PreferencesManager.swift
//  Correcteur Pro
//
//  Gestionnaire singleton des préférences de l'application
//

import Foundation
import Combine

class PreferencesManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PreferencesManager()

    // MARK: - Published Properties

    @Published var preferences: AppPreferences

    // MARK: - Private Properties

    private let userDefaultsKey = "AppPreferences"

    // MARK: - Initialization

    private init() {
        // Charger depuis UserDefaults ou créer avec valeurs par défaut
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            self.preferences = decoded
            print("✅ Préférences chargées depuis UserDefaults")
        } else {
            self.preferences = AppPreferences()
            print("ℹ️ Préférences initialisées avec valeurs par défaut")
        }
    }

    // MARK: - Public Methods

    /// Sauvegarder les préférences dans UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("✅ Préférences sauvegardées")
        } else {
            print("❌ Échec de la sauvegarde des préférences")
        }
    }

    /// Réinitialiser toutes les préférences aux valeurs par défaut
    func reset() {
        preferences = AppPreferences()
        save()
        print("🔄 Préférences réinitialisées")
    }

    /// Récupérer une préférence spécifique
    func get<T>(_ keyPath: KeyPath<AppPreferences, T>) -> T {
        return preferences[keyPath: keyPath]
    }

    /// Modifier une préférence et sauvegarder automatiquement
    func set<T>(_ keyPath: WritableKeyPath<AppPreferences, T>, value: T) {
        preferences[keyPath: keyPath] = value
        save()
    }

    // MARK: - Gestion des Prompts Personnalisés

    /// Ajouter un nouveau prompt personnalisé
    func addCustomPrompt(_ prompt: CustomPrompt) {
        preferences.customPrompts.append(prompt)
        save()
        print("✅ Prompt ajouté : \(prompt.name)")
    }

    /// Archiver un prompt (sera supprimé après 90 jours)
    func archivePrompt(id: UUID) {
        if let index = preferences.customPrompts.firstIndex(where: { $0.id == id }) {
            preferences.customPrompts[index].archivedAt = Date()
            save()
            print("📦 Prompt archivé : \(preferences.customPrompts[index].name)")
        }
    }

    /// Restaurer un prompt archivé
    func restorePrompt(id: UUID) {
        if let index = preferences.customPrompts.firstIndex(where: { $0.id == id }) {
            preferences.customPrompts[index].archivedAt = nil
            save()
            print("♻️ Prompt restauré : \(preferences.customPrompts[index].name)")
        }
    }

    /// Supprimer définitivement un prompt
    func deletePromptPermanently(id: UUID) {
        if let index = preferences.customPrompts.firstIndex(where: { $0.id == id }) {
            let name = preferences.customPrompts[index].name
            preferences.customPrompts.remove(at: index)
            save()
            print("🗑️ Prompt supprimé définitivement : \(name)")
        }
    }

    /// Nettoyer les prompts expirés (archivés depuis plus de 90 jours)
    func cleanupExpiredPrompts() {
        let expiredPrompts = preferences.customPrompts.filter { $0.shouldBeDeleted }
        for prompt in expiredPrompts {
            print("🗑️ Suppression automatique du prompt expiré : \(prompt.name)")
        }
        preferences.customPrompts.removeAll { $0.shouldBeDeleted }
        if !expiredPrompts.isEmpty {
            save()
        }
    }

    /// Récupérer les prompts actifs (non archivés)
    var activePrompts: [CustomPrompt] {
        preferences.customPrompts.filter { !$0.isArchived }
    }

    /// Récupérer les prompts archivés
    var archivedPrompts: [CustomPrompt] {
        preferences.customPrompts.filter { $0.isArchived }
    }
}
