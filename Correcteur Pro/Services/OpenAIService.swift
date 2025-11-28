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
            return "Aucune clé API configurée. Vérifiez votre fichier .env ou Keychain."
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

    // MARK: - Nouvelle méthode avec historique (ÉTAPE 5.1)

    /// Envoie un historique de messages à l'API OpenAI et retourne la réponse
    /// - Parameters:
    ///   - messages: L'historique complet de la conversation
    ///   - systemPrompt: Le prompt système à utiliser
    /// - Returns: La réponse de l'API sous forme de String
    /// - Throws: OpenAIError en cas d'erreur
    static func sendMessage(messages: [Message], systemPrompt: String) async throws -> String {
        print("")
        print("═══════════════════════════════════════════════════════════════")
        print("🔍 [OpenAIService] DÉBUT DE L'ENVOI DU MESSAGE (AVEC HISTORIQUE)")
        print("═══════════════════════════════════════════════════════════════")
        print("📝 Nombre de messages dans l'historique : \(messages.count)")
        print("📝 System prompt : \(systemPrompt.prefix(50))\(systemPrompt.count > 50 ? "..." : "")")
        print("")

        // 1. Récupérer la clé API depuis APIKeyManager
        print("📋 ÉTAPE 1 : Récupération de la clé API")
        print("─────────────────────────────────────────────────────────────")
        guard let apiKey = APIKeyManager.loadAPIKey() else {
            print("")
            print("═══════════════════════════════════════════════════════════════")
            print("❌ [OpenAIService] ERREUR CRITIQUE : AUCUNE CLÉ API TROUVÉE")
            print("═══════════════════════════════════════════════════════════════")
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

        // 4. Convertir les messages au format OpenAI
        let openAIMessages = convertMessagesToOpenAIFormat(messages, systemPrompt: systemPrompt)

        // 5. Créer le body JSON
        let requestBody: [String: Any] = [
            "model": model,
            "messages": openAIMessages,
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
        print("📝 [OpenAIService] Nombre de messages OpenAI : \(openAIMessages.count) (system + historique)")

        // Logger la requête dans un fichier
        let requestHeaders = [
            "Authorization": "Bearer \(String(apiKey.prefix(20)))...", // Masqué
            "Content-Type": "application/json"
        ]
        APILogger.logRequest(endpoint: endpoint, method: "POST", headers: requestHeaders, body: requestBody)

        // 6. Envoyer la requête avec async/await
        let requestStartTime = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // 7. Vérifier la réponse HTTP
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [OpenAIService] Réponse non HTTP")
                throw OpenAIError.invalidResponse
            }

            let statusCode = httpResponse.statusCode
            print("📊 [OpenAIService] Status code: \(statusCode)")

            // 8. Gérer les codes HTTP
            switch statusCode {
            case 200:
                // Succès - parser la réponse
                print("✅ [OpenAIService] Requête réussie (200)")

                // 9. Parser la réponse JSON
                do {
                    let decoder = JSONDecoder()
                    let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)

                    // 10. Extraire le contenu de la réponse
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

                    // 11. Logs des tokens utilisés (si disponibles)
                    let responseTime = Date().timeIntervalSince(requestStartTime)
                    if let usage = openAIResponse.usage {
                        let promptTokens = usage.promptTokens ?? 0
                        let completionTokens = usage.completionTokens ?? 0
                        let totalTokens = usage.totalTokens ?? 0
                        print("📊 [OpenAIService] Tokens utilisés - Prompt: \(promptTokens), Completion: \(completionTokens), Total: \(totalTokens)")

                        // Logger la réponse dans un fichier
                        APILogger.logResponse(
                            statusCode: statusCode,
                            responseTime: responseTime,
                            tokens: (promptTokens, completionTokens, totalTokens),
                            responsePreview: content
                        )
                    } else {
                        // Logger sans tokens
                        APILogger.logResponse(
                            statusCode: statusCode,
                            responseTime: responseTime,
                            tokens: nil,
                            responsePreview: content
                        )
                    }

                    print("✅ [OpenAIService] Réponse reçue: \(content.prefix(100))...")
                    print("✅ [OpenAIService] Taille de la réponse: \(content.count) caractères")

                    // 12. Retourner le texte de la réponse
                    return content

                } catch let decodingError {
                    print("❌ [OpenAIService] Erreur lors du décodage JSON: \(decodingError.localizedDescription)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📄 [OpenAIService] Réponse brute: \(responseString.prefix(500))")
                    }
                    throw OpenAIError.invalidResponse
                }

            case 401:
                let responseTime = Date().timeIntervalSince(requestStartTime)
                print("❌ [OpenAIService] Erreur 401: Non autorisé. Clé API invalide.")
                APILogger.logResponse(statusCode: statusCode, responseTime: responseTime, tokens: nil, responsePreview: "Erreur 401: Clé API invalide")
                throw OpenAIError.invalidAPIKey

            case 429:
                let responseTime = Date().timeIntervalSince(requestStartTime)
                print("❌ [OpenAIService] Erreur 429: Limite de requêtes atteinte.")
                APILogger.logResponse(statusCode: statusCode, responseTime: responseTime, tokens: nil, responsePreview: "Erreur 429: Rate limit")
                throw OpenAIError.rateLimitExceeded

            case 500...599:
                let responseTime = Date().timeIntervalSince(requestStartTime)
                print("❌ [OpenAIService] Erreur serveur \(statusCode)")
                APILogger.logResponse(statusCode: statusCode, responseTime: responseTime, tokens: nil, responsePreview: "Erreur serveur \(statusCode)")
                throw OpenAIError.serverError(statusCode)

            default:
                // Autres codes d'erreur
                let responseTime = Date().timeIntervalSince(requestStartTime)
                let responseBody = String(data: data, encoding: .utf8) ?? "N/A"
                print("❌ [OpenAIService] Erreur inattendue \(statusCode). Corps: \(responseBody.prefix(200))")
                APILogger.logResponse(statusCode: statusCode, responseTime: responseTime, tokens: nil, responsePreview: "Erreur \(statusCode)")
                throw OpenAIError.invalidResponse
            }

        } catch let urlError as URLError {
            // Erreur réseau
            print("❌ [OpenAIService] Erreur réseau (URLError): \(urlError.localizedDescription)")
            print("❌ [OpenAIService] Code d'erreur: \(urlError.code.rawValue)")
            APILogger.logError(urlError, context: "Erreur réseau")
            throw OpenAIError.networkError(urlError)

        } catch let openAIError as OpenAIError {
            // Erreur déjà typée, la relancer
            APILogger.logError(openAIError, context: "Erreur OpenAI")
            throw openAIError

        } catch {
            // Erreur inconnue
            print("❌ [OpenAIService] Erreur inconnue lors de l'envoi: \(error.localizedDescription)")
            APILogger.logError(error, context: "Erreur inconnue")
            throw OpenAIError.networkError(error)
        }
    }

    // MARK: - Méthode de conversion

    /// Convertit les messages de notre modèle au format OpenAI
    /// - Parameters:
    ///   - messages: Les messages à convertir
    ///   - systemPrompt: Le prompt système
    /// - Returns: Un tableau de dictionnaires au format OpenAI
    private static func convertMessagesToOpenAIFormat(
        _ messages: [Message],
        systemPrompt: String
    ) -> [[String: Any]] {
        var openAIMessages: [[String: Any]] = []

        // 1. Ajouter le systemPrompt en premier
        openAIMessages.append([
            "role": "system",
            "content": systemPrompt
        ])

        // 2. Convertir les messages utilisateur et assistant
        for message in messages {
            let role = message.isUser ? "user" : "assistant"
            openAIMessages.append([
                "role": role,
                "content": message.contenu
            ])
        }

        print("📊 [OpenAIService] Conversion : \(messages.count) messages → \(openAIMessages.count) messages OpenAI")

        return openAIMessages
    }

    // MARK: - Ancienne méthode (pour compatibilité)

    /// Envoie un message à l'API OpenAI et retourne la réponse (ancienne méthode)
    /// - Parameters:
    ///   - message: Le message de l'utilisateur
    ///   - systemPrompt: Le prompt système à utiliser
    /// - Returns: La réponse de l'API sous forme de String
    /// - Throws: OpenAIError en cas d'erreur
    static func sendMessage(message: String, systemPrompt: String) async throws -> String {
        print("")
        print("═══════════════════════════════════════════════════════════════")
        print("🔍 [OpenAIService] DÉBUT DE L'ENVOI DU MESSAGE")
        print("═══════════════════════════════════════════════════════════════")
        print("📝 Message utilisateur : \(message.prefix(100))\(message.count > 100 ? "..." : "")")
        print("📝 System prompt : \(systemPrompt.prefix(50))\(systemPrompt.count > 50 ? "..." : "")")
        print("")
        
        // 1. Récupérer la clé API depuis APIKeyManager
        print("📋 ÉTAPE 1 : Récupération de la clé API")
        print("─────────────────────────────────────────────────────────────")
        guard let apiKey = APIKeyManager.loadAPIKey() else {
            print("")
            print("═══════════════════════════════════════════════════════════════")
            print("❌ [OpenAIService] ERREUR CRITIQUE : AUCUNE CLÉ API TROUVÉE")
            print("═══════════════════════════════════════════════════════════════")
            print("🔍 DIAGNOSTIC :")
            print("   1. Vérification du fichier .env :")
            print("      → Fichier .env existe ? (voir logs EnvLoader ci-dessus)")
            print("      → Variable OPENAI_API_KEY présente ?")
            print("   2. Vérification du Keychain :")
            print("      → Entrée Keychain existe ? (voir logs APIKeyManager ci-dessus)")
            print("")
            print("💡 SOLUTION :")
            print("   → Créez un fichier .env à la racine du projet")
            print("   → Ajoutez : OPENAI_API_KEY=votre_clé_ici")
            print("   → Ou configurez la clé dans Keychain")
            print("═══════════════════════════════════════════════════════════════")
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
        
        // Logger la requête dans un fichier
        let requestHeaders = [
            "Authorization": "Bearer \(String(apiKey.prefix(20)))...", // Masqué
            "Content-Type": "application/json"
        ]
        APILogger.logRequest(endpoint: endpoint, method: "POST", headers: requestHeaders, body: requestBody)
        
        // 5. Envoyer la requête avec async/await
        let requestStartTime = Date()
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
                    let responseTime = Date().timeIntervalSince(requestStartTime)
                    if let usage = openAIResponse.usage {
                        let promptTokens = usage.promptTokens ?? 0
                        let completionTokens = usage.completionTokens ?? 0
                        let totalTokens = usage.totalTokens ?? 0
                        print("📊 [OpenAIService] Tokens utilisés - Prompt: \(promptTokens), Completion: \(completionTokens), Total: \(totalTokens)")
                        
                        // Logger la réponse dans un fichier
                        APILogger.logResponse(
                            statusCode: statusCode,
                            responseTime: responseTime,
                            tokens: (promptTokens, completionTokens, totalTokens),
                            responsePreview: content
                        )
                    } else {
                        // Logger sans tokens
                        APILogger.logResponse(
                            statusCode: statusCode,
                            responseTime: responseTime,
                            tokens: nil,
                            responsePreview: content
                        )
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
                let responseTime = Date().timeIntervalSince(requestStartTime)
                print("❌ [OpenAIService] Erreur 401: Non autorisé. Clé API invalide.")
                APILogger.logResponse(statusCode: statusCode, responseTime: responseTime, tokens: nil, responsePreview: "Erreur 401: Clé API invalide")
                throw OpenAIError.invalidAPIKey
                
            case 429:
                let responseTime = Date().timeIntervalSince(requestStartTime)
                print("❌ [OpenAIService] Erreur 429: Limite de requêtes atteinte.")
                APILogger.logResponse(statusCode: statusCode, responseTime: responseTime, tokens: nil, responsePreview: "Erreur 429: Rate limit")
                throw OpenAIError.rateLimitExceeded
                
            case 500...599:
                let responseTime = Date().timeIntervalSince(requestStartTime)
                print("❌ [OpenAIService] Erreur serveur \(statusCode)")
                APILogger.logResponse(statusCode: statusCode, responseTime: responseTime, tokens: nil, responsePreview: "Erreur serveur \(statusCode)")
                throw OpenAIError.serverError(statusCode)
                
            default:
                // Autres codes d'erreur
                let responseTime = Date().timeIntervalSince(requestStartTime)
                let responseBody = String(data: data, encoding: .utf8) ?? "N/A"
                print("❌ [OpenAIService] Erreur inattendue \(statusCode). Corps: \(responseBody.prefix(200))")
                APILogger.logResponse(statusCode: statusCode, responseTime: responseTime, tokens: nil, responsePreview: "Erreur \(statusCode)")
                throw OpenAIError.invalidResponse
            }
            
        } catch let urlError as URLError {
            // Erreur réseau
            print("❌ [OpenAIService] Erreur réseau (URLError): \(urlError.localizedDescription)")
            print("❌ [OpenAIService] Code d'erreur: \(urlError.code.rawValue)")
            APILogger.logError(urlError, context: "Erreur réseau")
            throw OpenAIError.networkError(urlError)
            
        } catch let openAIError as OpenAIError {
            // Erreur déjà typée, la relancer
            APILogger.logError(openAIError, context: "Erreur OpenAI")
            throw openAIError
            
        } catch {
            // Erreur inconnue
            print("❌ [OpenAIService] Erreur inconnue lors de l'envoi: \(error.localizedDescription)")
            APILogger.logError(error, context: "Erreur inconnue")
            throw OpenAIError.networkError(error)
        }
    }
}

