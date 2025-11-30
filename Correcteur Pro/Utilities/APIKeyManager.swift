//
//  APIKeyManager.swift
//  Correcteur Pro
//
//  Gestion du stockage de la clé API OpenAI
//  Utilise UserDefaults (pas de demande de mot de passe)
//

import Foundation

/// Gère le stockage de la clé API OpenAI
/// Utilise UserDefaults pour éviter les demandes de mot de passe Keychain
final class APIKeyManager {
    // Clé UserDefaults pour stocker l'API key (encodée en Base64)
    private static let userDefaultsKey = "com.correcteurpro.apiKey.encoded"

    /// Cache en mémoire de la clé API
    private static var cachedAPIKey: String?
    private static var cacheLoaded = false

    /// Invalide le cache (à appeler après modification de la clé)
    static func invalidateCache() {
        cachedAPIKey = nil
        cacheLoaded = false
        print("🔐 [APIKeyManager] Cache invalidé")
    }

    /// Sauvegarde la clé API dans UserDefaults
    /// - Parameter key: La clé API à sauvegarder (format: sk-...)
    /// - Returns: true si succès, false sinon
    static func saveAPIKey(_ key: String) -> Bool {
        print("🔐 [APIKeyManager] Sauvegarde de la clé API...")

        // Invalider le cache car la clé va changer
        invalidateCache()

        // Encoder en Base64 (obfuscation simple, pas de sécurité forte)
        guard let data = key.data(using: .utf8) else {
            print("❌ [APIKeyManager] Impossible de convertir la clé en Data")
            return false
        }
        let encoded = data.base64EncodedString()

        // Sauvegarder dans UserDefaults
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()

        // Mettre à jour le cache
        cachedAPIKey = key
        cacheLoaded = true

        print("✅ [APIKeyManager] Clé API sauvegardée avec succès")
        return true
    }

    /// Charge la clé API depuis .env (priorité) ou UserDefaults
    /// - Returns: La clé API si trouvée, nil sinon
    static func loadAPIKey() -> String? {
        // Vérifier le cache d'abord
        if cacheLoaded {
            if cachedAPIKey != nil {
                print("🔐 [APIKeyManager] Clé API chargée depuis le cache")
            }
            return cachedAPIKey
        }

        print("🔐 [APIKeyManager] Chargement de la clé API...")

        // 1. PRIORITÉ : Chercher dans le fichier .env (développement)
        if let envKey = EnvLoader.get("OPENAI_API_KEY") {
            let maskedKey = String(envKey.prefix(7)) + "..." + String(envKey.suffix(4))
            print("✅ [APIKeyManager] Clé API trouvée dans .env (\(maskedKey))")
            cachedAPIKey = envKey
            cacheLoaded = true
            return envKey
        }

        // 2. Chercher dans UserDefaults
        if let encoded = UserDefaults.standard.string(forKey: userDefaultsKey),
           let data = Data(base64Encoded: encoded),
           let key = String(data: data, encoding: .utf8) {
            let maskedKey = String(key.prefix(7)) + "..." + String(key.suffix(4))
            print("✅ [APIKeyManager] Clé API trouvée dans UserDefaults (\(maskedKey))")
            cachedAPIKey = key
            cacheLoaded = true
            return key
        }

        print("ℹ️ [APIKeyManager] Aucune clé API trouvée")
        cacheLoaded = true
        return nil
    }

    /// Supprime la clé API
    /// - Returns: true si succès, false sinon
    static func deleteAPIKey() -> Bool {
        print("🔐 [APIKeyManager] Suppression de la clé API...")
        invalidateCache()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()
        print("✅ [APIKeyManager] Clé API supprimée")
        return true
    }

    /// Vérifie si une clé API existe
    /// - Returns: true si une clé existe, false sinon
    static func hasAPIKey() -> Bool {
        return loadAPIKey() != nil
    }
}
