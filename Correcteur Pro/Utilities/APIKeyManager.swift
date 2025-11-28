//
//  APIKeyManager.swift
//  Correcteur Pro
//
//  Gestion sécurisée du stockage de la clé API OpenAI dans Keychain
//

import Foundation
import Security

/// Gère le stockage sécurisé de la clé API OpenAI dans Keychain
final class APIKeyManager {
    // Identifiants Keychain
    private static let service = "com.correcteurpro.apiKey"
    private static let account = "openai_api_key"
    
    /// Vérifie si on doit utiliser uniquement .env (pas de Keychain)
    private static var useEnvOnly: Bool {
        // Si .env contient une clé, on l'utilise exclusivement
        return EnvLoader.get("OPENAI_API_KEY") != nil
    }
    
    /// Sauvegarde la clé API dans Keychain
    /// - Parameter key: La clé API à sauvegarder (format: sk-...)
    /// - Returns: true si succès, false sinon
    static func saveAPIKey(_ key: String) -> Bool {
        print("🔐 [APIKeyManager] Tentative de sauvegarde de la clé API...")
        
        // Supprimer l'ancienne clé si elle existe
        _ = deleteAPIKey()
        
        // Convertir la clé en Data
        guard let keyData = key.data(using: .utf8) else {
            print("❌ [APIKeyManager] Impossible de convertir la clé en Data")
            return false
        }
        
        // Créer le dictionnaire de requête Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Ajouter la clé dans Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ [APIKeyManager] Clé API sauvegardée avec succès dans Keychain")
            return true
        } else {
            let errorMessage = getKeychainErrorMessage(status)
            print("❌ [APIKeyManager] Échec de la sauvegarde: \(errorMessage) (OSStatus: \(status))")
            return false
        }
    }
    
    /// Charge la clé API depuis .env (priorité) ou Keychain
    /// - Returns: La clé API si trouvée, nil sinon
    static func loadAPIKey() -> String? {
        print("")
        print("═══════════════════════════════════════════════════════════════")
        print("🔐 [APIKeyManager] DÉBUT DU CHARGEMENT DE LA CLÉ API")
        print("═══════════════════════════════════════════════════════════════")
        
        // 1. PRIORITÉ : Chercher dans le fichier .env (développement)
        print("📋 ÉTAPE 1 : Recherche dans le fichier .env")
        print("─────────────────────────────────────────────────────────────")
        
        if let envKey = EnvLoader.get("OPENAI_API_KEY") {
            let maskedKey = String(envKey.prefix(7)) + "..." + String(envKey.suffix(4))
            print("✅ [APIKeyManager] SUCCÈS : Clé API trouvée dans .env")
            print("   Clé masquée : \(maskedKey)")
            print("   Longueur : \(envKey.count) caractères")
            print("   Format valide : \(envKey.hasPrefix("sk-") ? "✅ OUI" : "❌ NON")")
            print("ℹ️ [APIKeyManager] Keychain ignoré car .env est utilisé (pas d'accès Keychain)")
            print("═══════════════════════════════════════════════════════════════")
            return envKey
        } else {
            print("❌ [APIKeyManager] ÉCHEC : Aucune clé trouvée dans .env")
            print("   Variable recherchée : OPENAI_API_KEY")
            print("   Raison possible : Fichier .env non trouvé ou variable absente")
        }
        
        // 2. FALLBACK : Chercher dans Keychain (production) - UNIQUEMENT si .env n'existe pas
        print("")
        print("📋 ÉTAPE 2 : Recherche dans Keychain (fallback)")
        print("─────────────────────────────────────────────────────────────")
        
        // Créer le dictionnaire de requête Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            if let data = result as? Data,
               let key = String(data: data, encoding: .utf8) {
                // Masquer la clé dans les logs (afficher seulement les 7 premiers caractères)
                let maskedKey = String(key.prefix(7)) + "..." + String(key.suffix(4))
                print("✅ [APIKeyManager] SUCCÈS : Clé API trouvée dans Keychain")
                print("   Clé masquée : \(maskedKey)")
                print("   Longueur : \(key.count) caractères")
                print("   Format valide : \(key.hasPrefix("sk-") ? "✅ OUI" : "❌ NON")")
                print("═══════════════════════════════════════════════════════════════")
                return key
            } else {
                print("❌ [APIKeyManager] ERREUR : Impossible de convertir les données en String")
                print("   Type de données : \(type(of: result))")
                print("   Données disponibles : \(result != nil ? "✅ OUI" : "❌ NON")")
                print("═══════════════════════════════════════════════════════════════")
                return nil
            }
        } else if status == errSecItemNotFound {
            print("❌ [APIKeyManager] ÉCHEC : Aucune clé API trouvée dans Keychain")
            print("   Service : \(service)")
            print("   Account : \(account)")
            print("   OSStatus : \(status) (errSecItemNotFound)")
            print("═══════════════════════════════════════════════════════════════")
            return nil
        } else {
            let errorMessage = getKeychainErrorMessage(status)
            print("❌ [APIKeyManager] ERREUR : Échec du chargement depuis Keychain")
            print("   Message d'erreur : \(errorMessage)")
            print("   OSStatus : \(status)")
            print("   Service : \(service)")
            print("   Account : \(account)")
            print("═══════════════════════════════════════════════════════════════")
            return nil
        }
    }
    
    /// Supprime la clé API de Keychain
    /// - Returns: true si succès, false sinon
    static func deleteAPIKey() -> Bool {
        print("🔐 [APIKeyManager] Tentative de suppression de la clé API...")
        
        // Créer le dictionnaire de requête Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            if status == errSecItemNotFound {
                print("ℹ️ [APIKeyManager] Aucune clé API à supprimer (déjà absente)")
            } else {
                print("✅ [APIKeyManager] Clé API supprimée avec succès")
            }
            return true
        } else {
            let errorMessage = getKeychainErrorMessage(status)
            print("❌ [APIKeyManager] Échec de la suppression: \(errorMessage) (OSStatus: \(status))")
            return false
        }
    }
    
    /// Vérifie si une clé API existe dans .env ou Keychain (sans la charger)
    /// - Returns: true si une clé existe, false sinon
    static func hasAPIKey() -> Bool {
        print("🔐 [APIKeyManager] Vérification de l'existence d'une clé API...")
        
        // 1. Vérifier dans .env d'abord
        if EnvLoader.get("OPENAI_API_KEY") != nil {
            print("✅ [APIKeyManager] Une clé API existe dans .env")
            print("ℹ️ [APIKeyManager] Keychain ignoré car .env est utilisé (pas d'accès Keychain)")
            return true
        }
        
        // 2. Vérifier dans Keychain - UNIQUEMENT si .env n'existe pas
        // Créer le dictionnaire de requête Keychain (sans retourner les données)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            print("✅ [APIKeyManager] Une clé API existe dans Keychain")
            return true
        } else if status == errSecItemNotFound {
            print("ℹ️ [APIKeyManager] Aucune clé API trouvée dans Keychain")
            return false
        } else {
            let errorMessage = getKeychainErrorMessage(status)
            print("⚠️ [APIKeyManager] Erreur lors de la vérification: \(errorMessage) (OSStatus: \(status))")
            return false
        }
    }
    
    /// Convertit un code d'erreur OSStatus en message lisible
    /// - Parameter status: Le code d'erreur OSStatus
    /// - Returns: Un message d'erreur descriptif
    private static func getKeychainErrorMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Succès"
        case errSecDuplicateItem:
            return "Élément dupliqué"
        case errSecItemNotFound:
            return "Élément non trouvé"
        case errSecAuthFailed:
            return "Échec d'authentification"
        case errSecParam:
            return "Paramètre invalide"
        case errSecAllocate:
            return "Erreur d'allocation mémoire"
        case errSecNotAvailable:
            return "Keychain non disponible"
        case errSecDecode:
            return "Erreur de décodage"
        case errSecInteractionNotAllowed:
            return "Interaction non autorisée"
        case errSecReadOnly:
            return "Keychain en lecture seule"
        default:
            return "Erreur inconnue (code: \(status))"
        }
    }
}

