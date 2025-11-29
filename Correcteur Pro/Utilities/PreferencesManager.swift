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
}
