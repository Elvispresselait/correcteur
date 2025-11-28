//
//  OpenAIConnectionTester.swift
//  Correcteur Pro
//
//  Test de connexion à l'API OpenAI pour valider une clé API
//

import Foundation

/// Erreurs possibles lors du test de connexion
enum ConnectionTestError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case rateLimitExceeded
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Clé API invalide"
        case .networkError(let error):
            return "Erreur réseau : \(error.localizedDescription)"
        case .invalidResponse:
            return "Réponse invalide de l'API"
        case .unauthorized:
            return "Clé API non autorisée (401)"
        case .serverError(let code):
            return "Erreur serveur (\(code))"
        case .rateLimitExceeded:
            return "Limite de requêtes atteinte (429)"
        case .unknownError(let message):
            return "Erreur inconnue : \(message)"
        }
    }
}

/// Teste la connexion à l'API OpenAI avec une clé API
final class OpenAIConnectionTester {
    private static let endpoint = "https://api.openai.com/v1/models"
    private static let timeout: TimeInterval = 10.0
    
    /// Teste la connexion à l'API OpenAI
    /// - Parameter apiKey: La clé API à tester (format: sk-...)
    /// - Returns: true si la connexion est réussie, false sinon
    /// - Throws: ConnectionTestError en cas d'erreur
    static func testConnection(apiKey: String) async throws -> Bool {
        print("🔍 [ConnectionTester] Début du test de connexion...")
        
        // Validation basique du format
        guard apiKey.hasPrefix("sk-") && apiKey.count > 20 else {
            print("❌ [ConnectionTester] Format de clé API invalide")
            throw ConnectionTestError.invalidAPIKey
        }
        
        // Masquer la clé dans les logs (afficher seulement les 7 premiers caractères)
        let maskedKey = String(apiKey.prefix(7)) + "..."
        print("🔍 [ConnectionTester] Test avec clé API: \(maskedKey)")
        
        // Créer l'URL
        guard let url = URL(string: endpoint) else {
            print("❌ [ConnectionTester] URL invalide: \(endpoint)")
            throw ConnectionTestError.invalidResponse
        }
        
        // Créer la requête
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        print("📡 [ConnectionTester] Envoi de la requête à \(endpoint)...")
        
        do {
            // Effectuer la requête
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Vérifier le type de réponse
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [ConnectionTester] Réponse HTTP invalide")
                throw ConnectionTestError.invalidResponse
            }
            
            let statusCode = httpResponse.statusCode
            print("📊 [ConnectionTester] Status code: \(statusCode)")
            
            // Gérer les différents codes de statut
            switch statusCode {
            case 200:
                // Succès - vérifier que la réponse contient bien une liste de modèles
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]],
                   !dataArray.isEmpty {
                    print("✅ [ConnectionTester] Connexion réussie ! \(dataArray.count) modèle(s) disponible(s)")
                    return true
                } else {
                    print("⚠️ [ConnectionTester] Réponse 200 mais format JSON invalide")
                    // On considère quand même que c'est un succès (l'API répond)
                    return true
                }
                
            case 401:
                print("❌ [ConnectionTester] Erreur 401 - Clé API non autorisée")
                throw ConnectionTestError.unauthorized
                
            case 429:
                print("⚠️ [ConnectionTester] Erreur 429 - Rate limit atteint")
                throw ConnectionTestError.rateLimitExceeded
                
            case 500...599:
                print("❌ [ConnectionTester] Erreur serveur \(statusCode)")
                throw ConnectionTestError.serverError(statusCode)
                
            default:
                // Autres codes d'erreur
                let errorMessage = String(data: data, encoding: .utf8) ?? "Erreur inconnue"
                print("❌ [ConnectionTester] Erreur \(statusCode): \(errorMessage)")
                throw ConnectionTestError.unknownError("Code \(statusCode): \(errorMessage)")
            }
            
        } catch let error as ConnectionTestError {
            // Erreur déjà typée, la relancer
            throw error
        } catch {
            // Erreur réseau ou autre
            print("❌ [ConnectionTester] Erreur réseau: \(error.localizedDescription)")
            throw ConnectionTestError.networkError(error)
        }
    }
    
    /// Teste la connexion de manière synchrone (pour compatibilité)
    /// - Parameter apiKey: La clé API à tester
    /// - Returns: Résultat du test (succès/échec) avec message d'erreur optionnel
    static func testConnectionSync(apiKey: String) -> (success: Bool, error: String?) {
        var result: (success: Bool, error: String?) = (false, nil)
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            do {
                let success = try await testConnection(apiKey: apiKey)
                result = (success, nil)
            } catch let error as ConnectionTestError {
                result = (false, error.localizedDescription)
            } catch {
                result = (false, error.localizedDescription)
            }
            semaphore.signal()
        }
        
        // Attendre la réponse (avec timeout)
        let timeout = semaphore.wait(timeout: .now() + timeout + 2.0)
        if timeout == .timedOut {
            result = (false, "Timeout - La requête a pris trop de temps")
        }
        
        return result
    }
}

