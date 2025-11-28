//
//  OpenAIService.swift
//  Correcteur Pro
//
//  Service pour communiquer avec l'API OpenAI Chat Completions
//

import Foundation

/// Erreurs possibles lors de l'appel à l'API OpenAI
enum OpenAIError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimitExceeded
    case serverError(Int)
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Aucune clé API configurée. Ouvrez les Préférences pour configurer."
        case .invalidAPIKey:
            return "Clé API invalide ou expirée"
        case .networkError(let error):
            return "Erreur réseau : \(error.localizedDescription)"
        case .invalidResponse:
            return "Réponse invalide de l'API"
        case .rateLimitExceeded:
            return "Limite de requêtes atteinte. Réessayez plus tard."
        case .serverError(let code):
            return "Erreur serveur OpenAI (\(code))"
        case .emptyResponse:
            return "La réponse de l'API est vide"
        }
    }
}

/// Structure pour la réponse de l'API OpenAI
private struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

/// Service pour communiquer avec l'API OpenAI
final class OpenAIService {
    private static let endpoint = "https://api.openai.com/v1/chat/completions"
    private static let timeout: TimeInterval = 30.0
    private static let model = "gpt-4o-mini"
    
    /// Envoie un message à l'API OpenAI et retourne la réponse
    /// - Parameters:
    ///   - message: Le message de l'utilisateur
    ///   - systemPrompt: Le prompt système à utiliser
    /// - Returns: La réponse de l'API sous forme de String
    /// - Throws: OpenAIError en cas d'erreur
    static func sendMessage(message: String, systemPrompt: String) async throws -> String {
        print("🔍 [OpenAIService] Début de l'envoi du message...")
        
        // 1. Récupérer la clé API depuis APIKeyManager
        guard let apiKey = APIKeyManager.loadAPIKey() else {
            print("❌ [OpenAIService] Aucune clé API trouvée")
            throw OpenAIError.noAPIKey
        }
        
        // Vérifier le format de la clé (doit commencer par "sk-")
        guard apiKey.hasPrefix("sk-") && apiKey.count > 20 else {
            print("❌ [OpenAIService] Format de clé API invalide")
            throw OpenAIError.invalidAPIKey
        }
        
        print("✅ [OpenAIService] Clé API trouvée (format valide)")
        
        // 2. Créer l'URL
        guard let url = URL(string: endpoint) else {
            print("❌ [OpenAIService] URL invalide: \(endpoint)")
            throw OpenAIError.invalidResponse
        }
        
        // 3. Créer la requête HTTP POST
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        // 4. Créer le body JSON
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": message
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ [OpenAIService] Erreur lors de la sérialisation JSON: \(error.localizedDescription)")
            throw OpenAIError.invalidResponse
        }
        
        print("📡 [OpenAIService] Envoi de la requête à \(endpoint)")
        print("📝 [OpenAIService] Modèle: \(model)")
        print("📝 [OpenAIService] Message utilisateur: \(message.prefix(50))...")
        
        // 5. Envoyer la requête avec async/await
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 6. Vérifier la réponse HTTP
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [OpenAIService] Réponse non HTTP")
                throw OpenAIError.invalidResponse
            }
            
            let statusCode = httpResponse.statusCode
            print("📊 [OpenAIService] Status code: \(statusCode)")
            
            // 7. Gérer les codes HTTP
            switch statusCode {
            case 200:
                // Succès - parser la réponse
                print("✅ [OpenAIService] Requête réussie (200)")
                
                // 8. Parser la réponse JSON
                do {
                    let decoder = JSONDecoder()
                    let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)
                    
                    // 9. Extraire le contenu de la réponse
                    guard let firstChoice = openAIResponse.choices.first else {
                        print("❌ [OpenAIService] Aucun choix dans la réponse")
                        throw OpenAIError.emptyResponse
                    }
                    
                    let content = firstChoice.message.content
                    
                    // Vérifier que le contenu n'est pas vide
                    guard !content.isEmpty else {
                        print("❌ [OpenAIService] Contenu de réponse vide")
                        throw OpenAIError.emptyResponse
                    }
                    
                    // 10. Logs des tokens utilisés (si disponibles)
                    if let usage = openAIResponse.usage {
                        let promptTokens = usage.promptTokens ?? 0
                        let completionTokens = usage.completionTokens ?? 0
                        let totalTokens = usage.totalTokens ?? 0
                        print("📊 [OpenAIService] Tokens utilisés - Prompt: \(promptTokens), Completion: \(completionTokens), Total: \(totalTokens)")
                    }
                    
                    print("✅ [OpenAIService] Réponse reçue: \(content.prefix(100))...")
                    print("✅ [OpenAIService] Taille de la réponse: \(content.count) caractères")
                    
                    // 11. Retourner le texte de la réponse
                    return content
                    
                } catch let decodingError {
                    print("❌ [OpenAIService] Erreur lors du décodage JSON: \(decodingError.localizedDescription)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📄 [OpenAIService] Réponse brute: \(responseString.prefix(500))")
                    }
                    throw OpenAIError.invalidResponse
                }
                
            case 401:
                print("❌ [OpenAIService] Erreur 401: Non autorisé. Clé API invalide.")
                throw OpenAIError.invalidAPIKey
                
            case 429:
                print("❌ [OpenAIService] Erreur 429: Limite de requêtes atteinte.")
                throw OpenAIError.rateLimitExceeded
                
            case 500...599:
                print("❌ [OpenAIService] Erreur serveur \(statusCode)")
                throw OpenAIError.serverError(statusCode)
                
            default:
                // Autres codes d'erreur
                let responseBody = String(data: data, encoding: .utf8) ?? "N/A"
                print("❌ [OpenAIService] Erreur inattendue \(statusCode). Corps: \(responseBody.prefix(200))")
                throw OpenAIError.invalidResponse
            }
            
        } catch let urlError as URLError {
            // Erreur réseau
            print("❌ [OpenAIService] Erreur réseau (URLError): \(urlError.localizedDescription)")
            print("❌ [OpenAIService] Code d'erreur: \(urlError.code.rawValue)")
            throw OpenAIError.networkError(urlError)
            
        } catch let openAIError as OpenAIError {
            // Erreur déjà typée, la relancer
            throw openAIError
            
        } catch {
            // Erreur inconnue
            print("❌ [OpenAIService] Erreur inconnue lors de l'envoi: \(error.localizedDescription)")
            throw OpenAIError.networkError(error)
        }
    }
}

