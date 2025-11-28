//
//  FrontendTester.swift
//  Correcteur Pro
//
//  Test du flux frontend pour diagnostiquer les problèmes de communication
//

import Foundation

/// Teste le flux frontend sans appeler l'API réelle
final class FrontendTester {
    
    /// Test complet du flux frontend : de l'interface jusqu'à l'appel API
    static func testFrontendFlow() async {
        print("\n🧪 ===== TEST FLUX FRONTEND =====\n")
        
        // 1. Test du chargement de la clé API
        print("📋 ÉTAPE 1 : Vérification du chargement de la clé API")
        print("─────────────────────────────────────────────────────")
        
        if let apiKey = APIKeyManager.loadAPIKey() {
            let masked = String(apiKey.prefix(20)) + "..." + String(apiKey.suffix(10))
            print("✅ Clé API chargée : \(masked)")
            print("   Longueur : \(apiKey.count) caractères")
            print("   Format valide : \(apiKey.hasPrefix("sk-"))")
        } else {
            print("❌ Aucune clé API trouvée")
            print("   → Vérifiez le fichier .env ou Keychain")
            return
        }
        
        // 2. Test de la création du message
        print("\n📋 ÉTAPE 2 : Création du message")
        print("─────────────────────────────────────────────────────")
        let testMessage = "Bonjour, peux-tu corriger ce texte ?"
        let systemPrompt = "Tu es un assistant utile."
        print("✅ Message créé : \"\(testMessage)\"")
        print("✅ System prompt : \"\(systemPrompt)\"")
        
        // 3. Test de la préparation de la requête
        print("\n📋 ÉTAPE 3 : Préparation de la requête API")
        print("─────────────────────────────────────────────────────")
        
        guard let apiKey = APIKeyManager.loadAPIKey() else {
            print("❌ Impossible de charger la clé API")
            return
        }
        
        // Vérifier le format de la clé
        guard apiKey.hasPrefix("sk-") && apiKey.count > 20 else {
            print("❌ Format de clé API invalide")
            return
        }
        print("✅ Format de clé API valide")
        
        // Créer l'URL
        let endpoint = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: endpoint) else {
            print("❌ URL invalide : \(endpoint)")
            return
        }
        print("✅ URL créée : \(endpoint)")
        
        // Créer la requête HTTP
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        print("✅ Requête HTTP préparée")
        print("   Headers : Authorization, Content-Type")
        
        // Créer le body JSON
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": testMessage
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let bodySize = request.httpBody?.count ?? 0
            print("✅ Body JSON créé : \(bodySize) octets")
            
            // Afficher un aperçu du body
            if let bodyData = request.httpBody,
               let bodyString = String(data: bodyData, encoding: .utf8) {
                let preview = String(bodyString.prefix(200))
                print("   Aperçu : \(preview)...")
            }
        } catch {
            print("❌ Erreur lors de la sérialisation JSON : \(error.localizedDescription)")
            return
        }
        
        // 4. Test de l'envoi (simulation)
        print("\n📋 ÉTAPE 4 : Simulation de l'envoi")
        print("─────────────────────────────────────────────────────")
        print("ℹ️  Mode simulation : pas d'envoi réel à l'API")
        print("✅ Tous les composants sont prêts pour l'envoi")
        print("   - Clé API : ✅")
        print("   - URL : ✅")
        print("   - Requête HTTP : ✅")
        print("   - Body JSON : ✅")
        
        // 5. Test réel (optionnel)
        print("\n📋 ÉTAPE 5 : Test réel de l'API (optionnel)")
        print("─────────────────────────────────────────────────────")
        print("❓ Voulez-vous tester l'envoi réel ? (décommentez le code ci-dessous)")
        
        /*
        do {
            print("📡 Envoi de la requête...")
            let startTime = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Réponse reçue : Status \(httpResponse.statusCode)")
                print("⏱️  Temps de réponse : \(String(format: "%.2f", duration))s")
                
                if httpResponse.statusCode == 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        let preview = String(responseString.prefix(300))
                        print("📄 Aperçu de la réponse : \(preview)...")
                    }
                } else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Erreur API : \(errorString)")
                    }
                }
            }
        } catch {
            print("❌ Erreur réseau : \(error.localizedDescription)")
        }
        */
        
        print("\n✅ ===== TEST FRONTEND TERMINÉ =====\n")
    }
    
    /// Test rapide : vérifie juste si la clé API est accessible
    static func quickTest() {
        print("\n⚡ TEST RAPIDE : Clé API\n")
        
        if let key = APIKeyManager.loadAPIKey() {
            let masked = String(key.prefix(20)) + "..." + String(key.suffix(10))
            print("✅ Clé API trouvée : \(masked)")
            print("   Longueur : \(key.count) caractères")
        } else {
            print("❌ Aucune clé API trouvée")
            print("   → Vérifiez le fichier .env")
        }
    }
}

