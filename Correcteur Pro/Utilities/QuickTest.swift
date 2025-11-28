//
//  QuickTest.swift
//  Correcteur Pro
//
//  Script de test rapide pour l'API OpenAI
//  ⚠️ Ce fichier est temporaire et ne doit pas être commité
//

import Foundation

/// Script de test rapide - À exécuter depuis Xcode ou via un playground
@available(macOS 12.0, *)
func quickAPITest() async {
    print("\n🧪 ===== TEST RAPIDE API OPENAI =====\n")
    
    // 1. Sauvegarder la clé API
    // ⚠️ REMPLACER PAR VOTRE CLÉ API
    let apiKey = "sk-your-api-key-here"
    
    print("🔐 Sauvegarde de la clé API dans Keychain...")
    if APIKeyManager.saveAPIKey(apiKey) {
        print("✅ Clé API sauvegardée avec succès\n")
    } else {
        print("❌ Échec de la sauvegarde de la clé API\n")
        return
    }
    
    // 2. Vérifier que la clé est bien sauvegardée
    if let loadedKey = APIKeyManager.loadAPIKey() {
        let masked = String(loadedKey.prefix(20)) + "..." + String(loadedKey.suffix(10))
        print("✅ Clé API chargée: \(masked)\n")
    } else {
        print("❌ Impossible de charger la clé API\n")
        return
    }
    
    // 3. Test de connexion
    print("🔍 Test de connexion à l'API OpenAI...")
    do {
        let isConnected = try await OpenAIConnectionTester.testConnection(apiKey: apiKey)
        if isConnected {
            print("✅ Connexion réussie !\n")
        } else {
            print("❌ Connexion échouée\n")
            return
        }
    } catch {
        print("❌ Erreur de connexion: \(error.localizedDescription)\n")
        return
    }
    
    // 4. Test 1 : Message simple
    print("📝 TEST 1 : Message simple")
    print("─────────────────────────────")
    do {
        let response = try await OpenAIService.sendMessage(
            message: "Dis bonjour en français",
            systemPrompt: "Tu es un assistant utile et respectueux."
        )
        print("✅ Réponse reçue:\n\(response)\n")
    } catch {
        print("❌ Erreur: \(error.localizedDescription)\n")
    }
    
    // Attendre un peu
    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
    
    // 5. Test 2 : Question de contexte
    print("📝 TEST 2 : Question avec contexte")
    print("─────────────────────────────")
    do {
        let response = try await OpenAIService.sendMessage(
            message: "Quelle est la capitale de la France ?",
            systemPrompt: "Tu es un assistant géographique."
        )
        print("✅ Réponse reçue:\n\(response)\n")
    } catch {
        print("❌ Erreur: \(error.localizedDescription)\n")
    }
    
    // Attendre un peu
    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
    
    // 6. Test 3 : Test du correcteur orthographique
    print("📝 TEST 3 : Correcteur orthographique")
    print("─────────────────────────────")
    let correcteurPrompt = """
    Je veux que tu ne regardes que la partie surlignée.
    Tu me la re-rediges complètement en respectant les retours à la ligne.

    Ensuite pour chaque faute, tu me rayes le mot entier où il y a la faute, ou les mots entiers où il y a les fautes.
    Tu rajoutes un espace devant avec et tu mets en gras et soulignés les mots que tu rajoutes pour corriger.

    Ensuite, devant chaque paragraphe que tu as modifié, je veux que tu rajoutes une croix rouge (❌).
    Et pour les autres paragraphes qui restent, je veux que tu rajoutes une croix verte (✅) devant chaque paragraphe.
    """
    
    do {
        let response = try await OpenAIService.sendMessage(
            message: "Il y a beaucoup de faute dans ce document. Il faut les corriger.",
            systemPrompt: correcteurPrompt
        )
        print("✅ Réponse reçue:\n\(response)\n")
    } catch {
        print("❌ Erreur: \(error.localizedDescription)\n")
    }
    
    // 7. Afficher les infos sur les logs
    print("📁 Informations sur les logs:")
    print("─────────────────────────────")
    TestAPIService.showLogInfo()
    
    print("\n✅ ===== TOUS LES TESTS TERMINÉS =====\n")
}

