//
//  TestAPIService.swift
//  Correcteur Pro
//
//  Service de test pour l'API OpenAI (sans UI, pour tests directs)
//

import Foundation

/// Service de test pour l'API OpenAI
/// Permet de tester l'API directement sans passer par l'interface
final class TestAPIService {
    
    /// Test simple : Envoyer un message et afficher la réponse
    /// - Parameters:
    ///   - message: Message à envoyer
    ///   - systemPrompt: Prompt système (optionnel)
    ///   - apiKey: Clé API (optionnel, utilise Keychain si nil)
    static func testSimpleMessage(
        message: String,
        systemPrompt: String? = nil,
        apiKey: String? = nil
    ) async {
        print("\n🧪 ===== TEST API OPENAI =====\n")
        print("📝 Message: \(message)")
        
        let startTime = Date()
        
        do {
            // Utiliser la clé API fournie ou celle de Keychain
            let keyToUse: String?
            if let providedKey = apiKey {
                keyToUse = providedKey
                print("🔑 Utilisation de la clé API fournie")
            } else {
                keyToUse = APIKeyManager.loadAPIKey()
                print("🔑 Utilisation de la clé API depuis Keychain")
            }
            
            guard let apiKey = keyToUse else {
                print("❌ Aucune clé API disponible")
                print("   Utilisez APIKeyManager.saveAPIKey() ou fournissez une clé dans les paramètres")
                return
            }
            
            // Sauvegarder temporairement dans Keychain si fournie
            if let providedKey = apiKey, providedKey != APIKeyManager.loadAPIKey() {
                _ = APIKeyManager.saveAPIKey(providedKey)
                print("💾 Clé API sauvegardée temporairement dans Keychain")
            }
            
            let prompt = systemPrompt ?? "Tu es un assistant IA utile et respectueux."
            
            print("📡 Envoi de la requête...")
            APILogger.log(level: .info, message: "Début du test API", service: "TestAPIService")
            
            let response = try await OpenAIService.sendMessage(
                message: message,
                systemPrompt: prompt
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            print("\n✅ ===== RÉPONSE REÇUE =====\n")
            print("⏱️  Temps de réponse: \(String(format: "%.2f", duration))s")
            print("📄 Réponse:\n\(response)\n")
            print("================================\n")
            
            APILogger.log(level: .info, message: "Test réussi en \(String(format: "%.2f", duration))s", service: "TestAPIService")
            
        } catch let error as OpenAIError {
            let duration = Date().timeIntervalSince(startTime)
            print("\n❌ ===== ERREUR =====\n")
            print("⏱️  Temps avant erreur: \(String(format: "%.2f", duration))s")
            print("❌ Erreur: \(error.localizedDescription)\n")
            print("================================\n")
            
            APILogger.logError(error, context: "Test API")
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("\n❌ ===== ERREUR INCONNUE =====\n")
            print("⏱️  Temps avant erreur: \(String(format: "%.2f", duration))s")
            print("❌ Erreur: \(error.localizedDescription)\n")
            print("================================\n")
            
            APILogger.logError(error, context: "Test API")
        }
    }
    
    /// Test avec historique : Envoyer plusieurs messages pour tester le contexte
    static func testWithHistory() async {
        print("\n🧪 ===== TEST API AVEC HISTORIQUE =====\n")
        
        // Simuler une conversation
        let messages = [
            ("Bonjour, mon nom est Alice.", "Tu es un assistant IA utile et respectueux."),
            ("Quel est mon nom ?", "Tu es un assistant IA utile et respectueux.")
        ]
        
        for (index, (message, prompt)) in messages.enumerated() {
            print("\n--- Message \(index + 1)/\(messages.count) ---")
            await testSimpleMessage(message: message, systemPrompt: prompt)
            
            // Attendre un peu entre les messages
            if index < messages.count - 1 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde
            }
        }
    }
    
    /// Afficher les informations sur les logs
    static func showLogInfo() {
        print("\n📁 ===== INFORMATIONS SUR LES LOGS =====\n")
        
        if let logDir = APILogger.getLogDirectoryPath() {
            print("📂 Dossier de logs: \(logDir)\n")
        } else {
            print("❌ Impossible de trouver le dossier de logs\n")
            return
        }
        
        let logFiles = APILogger.listLogFiles()
        print("📄 Fichiers de logs disponibles: \(logFiles.count)\n")
        
        for file in logFiles.prefix(5) {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attributes[.size] as? Int64 {
                let sizeMB = Double(size) / 1_000_000.0
                print("   • \(file.lastPathComponent) (\(String(format: "%.2f", sizeMB)) MB)")
            } else {
                print("   • \(file.lastPathComponent)")
            }
        }
        
        if logFiles.count > 5 {
            print("   ... et \(logFiles.count - 5) autre(s) fichier(s)")
        }
        
        print("\n💡 Pour voir les logs en temps réel:")
        print("   tail -f \"\(APILogger.getLogDirectoryPath() ?? "")/api_$(date +%Y-%m-%d).log\"")
        print("\n================================\n")
    }
}

