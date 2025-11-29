//
//  ChatViewModel.swift
//  Correcteur Pro
//
//  Gestion centralisée des conversations et des messages.
//

import Foundation
import Combine
import AppKit

enum SystemPromptType: String, CaseIterable, Identifiable {
    case correcteur = "Correcteur orthographique"
    case assistant = "Assistant général"
    case traducteur = "Traducteur"
    case personnalise = "Personnalisé"

    var id: String { rawValue }

    /// Icône par défaut pour chaque type de prompt
    var icon: String {
        switch self {
        case .correcteur: return "✏️"
        case .assistant: return "🤖"
        case .traducteur: return "🌍"
        case .personnalise: return "⚙️"
        }
    }

    /// Nom court pour affichage compact
    var shortName: String {
        switch self {
        case .correcteur: return "Correcteur"
        case .assistant: return "Assistant"
        case .traducteur: return "Traducteur"
        case .personnalise: return "Perso"
        }
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation]
    @Published var selectedConversationID: UUID?
    @Published var promptType: SystemPromptType = .correcteur
    @Published var customPrompt: String = ""
    @Published var isGenerating: Bool = false // État de chargement pour l'API

    // Service de persistance
    private let storage = ConversationStorage.shared

    /// Prompt temporaire en cours d'édition (non sauvegardé)
    @Published var temporaryPrompt: String? = nil

    /// ID du prompt personnalisé sélectionné (si applicable)
    @Published var selectedCustomPromptID: UUID? = nil

    var currentSystemPrompt: String {
        // Si on a un prompt temporaire, l'utiliser
        if let temp = temporaryPrompt {
            return temp
        }

        // Sinon, utiliser le prompt sauvegardé
        let prefs = PreferencesManager.shared.preferences
        switch promptType {
        case .correcteur:
            return prefs.promptCorrecteur
        case .assistant:
            return prefs.promptAssistant
        case .traducteur:
            return prefs.promptTraducteur
        case .personnalise:
            // Si un prompt personnalisé est sélectionné
            if let customID = selectedCustomPromptID,
               let custom = prefs.customPrompts.first(where: { $0.id == customID }) {
                return custom.content
            }
            return customPrompt.isEmpty ? prefs.promptCorrecteur : customPrompt
        }
    }

    /// Vérifie si on est en mode temporaire (modifications non sauvegardées)
    var isInTemporaryMode: Bool {
        temporaryPrompt != nil
    }

    /// Sauvegarde le prompt temporaire
    func saveTemporaryPrompt() {
        guard let temp = temporaryPrompt else { return }

        switch promptType {
        case .correcteur:
            PreferencesManager.shared.preferences.promptCorrecteur = temp
        case .assistant:
            PreferencesManager.shared.preferences.promptAssistant = temp
        case .traducteur:
            PreferencesManager.shared.preferences.promptTraducteur = temp
        case .personnalise:
            if let customID = selectedCustomPromptID,
               let index = PreferencesManager.shared.preferences.customPrompts.firstIndex(where: { $0.id == customID }) {
                PreferencesManager.shared.preferences.customPrompts[index].content = temp
            } else {
                customPrompt = temp
            }
        }

        PreferencesManager.shared.save()
        temporaryPrompt = nil
    }

    /// Annule les modifications temporaires
    func discardTemporaryPrompt() {
        temporaryPrompt = nil
    }

    /// Crée un nouveau prompt personnalisé
    func createCustomPrompt(name: String, icon: String, content: String) {
        let newPrompt = CustomPrompt(name: name, icon: icon, content: content)
        PreferencesManager.shared.preferences.customPrompts.append(newPrompt)
        PreferencesManager.shared.save()
        selectedCustomPromptID = newPrompt.id
        promptType = .personnalise
    }

    /// Supprime un prompt personnalisé
    func deleteCustomPrompt(id: UUID) {
        PreferencesManager.shared.preferences.customPrompts.removeAll { $0.id == id }
        PreferencesManager.shared.save()
        if selectedCustomPromptID == id {
            selectedCustomPromptID = nil
            promptType = .correcteur
        }
    }

    init(conversations: [Conversation]? = nil, loadFromStorage: Bool = true) {
        // Charger les conversations depuis le stockage (ou utiliser les données fournies/par défaut)
        if loadFromStorage {
            let loadedConversations = ConversationStorage.shared.loadAll()
            if loadedConversations.isEmpty {
                // Première utilisation : sauvegarder les conversations par défaut
                print("💾 [ChatViewModel] Première utilisation - sauvegarde des conversations par défaut")
                self.conversations = ChatViewModel.defaultConversations
                // Sauvegarder les conversations par défaut
                for conversation in self.conversations {
                    ConversationStorage.shared.save(conversation)
                }
            } else {
                self.conversations = loadedConversations
                print("💾 [ChatViewModel] \(loadedConversations.count) conversations chargées depuis le stockage")
            }
        } else {
            let initialConversations = conversations ?? ChatViewModel.defaultConversations
            self.conversations = initialConversations
        }

        self.selectedConversationID = self.conversations.first?.id
    }
    
    var selectedConversation: Conversation? {
        guard let id = selectedConversationID else { return nil }
        return conversations.first(where: { $0.id == id })
    }
    
    func createNewConversation() {
        let newConversation = Conversation(
            titre: "Nouvelle conversation",
            systemPrompt: currentSystemPrompt
        )
        conversations.insert(newConversation, at: 0)
        selectedConversationID = newConversation.id

        // Auto-save
        storage.save(newConversation)
    }
    
    func selectConversation(_ conversation: Conversation) {
        selectedConversationID = conversation.id
    }
    
    func deleteConversation(_ conversation: Conversation) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations.remove(at: index)
        if selectedConversationID == conversation.id {
            selectedConversationID = conversations.first?.id
        }

        // Supprimer du stockage
        storage.delete(id: conversation.id)
    }
    
    func renameSelectedConversation(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let id = selectedConversationID,
              let index = conversations.firstIndex(where: { $0.id == id }) else {
            return
        }
        conversations[index].titre = trimmed
        conversations[index].lastModified = Date()

        // Auto-save
        storage.save(conversations[index])
    }
    
    @discardableResult
    func sendMessage(_ text: String, images: [NSImage]? = nil) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!trimmed.isEmpty || images != nil),
              let id = selectedConversationID,
              let index = conversations.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        // TEMPS 3 : Convertir les images compressées en ImageData pour l'API
        // Les images dans pendingImages sont déjà compressées (TEMPS 2)
        var imageDataArray: [ImageData]? = nil
        if let images = images, !images.isEmpty {
            print("🖼️ [ChatViewModel] TEMPS 3: Conversion de \(images.count) image(s) compressée(s) en ImageData...")
            print("ℹ️ [ChatViewModel] Les images sont déjà compressées (TEMPS 2), conversion directe en base64")
            imageDataArray = convertImagesToImageData(images, alreadyCompressed: true)
            
            if let imageData = imageDataArray {
                print("✅ [ChatViewModel] \(imageData.count) image(s) convertie(s) avec succès")
                for (index, data) in imageData.enumerated() {
                    print("  Image \(index + 1): \(String(format: "%.2f", data.originalSizeMB)) MB -> \(String(format: "%.2f", data.finalSizeMB)) MB (\(data.format))")
                    if data.wasCompressed {
                        print("    Compression: \(String(format: "%.1f", data.compressionRatio * 100))%")
                    }
                    print("    Base64 prêt pour l'API")
                }
            } else {
                print("❌ [ChatViewModel] Échec de la conversion des images - aucune image n'a pu être convertie")
                // Note: On continue quand même pour ne pas bloquer l'envoi du message texte
            }
        }
        
        let userMessage = Message(contenu: trimmed, isUser: true, images: images, imageData: imageDataArray)
        conversations[index].messages.append(userMessage)
        conversations[index].lastModified = Date()

        // Auto-save après ajout du message utilisateur
        storage.save(conversations[index])

        // ÉTAPE 4.2 : Remplacer l'echo par un appel réel à l'API OpenAI
        // Créer un message temporaire avec typing indicator
        let typingMessageID = UUID()
        let typingMessage = Message(
            id: typingMessageID,
            contenu: "⏳ Génération en cours...",
            isUser: false
        )
        conversations[index].messages.append(typingMessage)
        
        // Désactiver l'envoi pendant la génération
        isGenerating = true
        
        // Appeler l'API OpenAI en async
        Task {
            do {
                let systemPrompt = currentSystemPrompt

                // ÉTAPE 5.2 : Préparer l'historique pour l'API
                // 1. Récupérer tous les messages de la conversation
                let allMessages = conversations[index].messages

                // 2. Filtrer les messages temporaires (indicateur de chargement)
                let filteredMessages = allMessages.filter { message in
                    !message.contenu.contains("⏳ Génération en cours...")
                }

                // 3. Limiter aux 20 derniers messages pour économiser les tokens
                let recentMessages = Array(filteredMessages.suffix(20))

                print("🚀 [ChatViewModel] Appel à OpenAIService.sendMessage() avec historique...")
                print("📊 [ChatViewModel] Messages dans la conversation : \(allMessages.count)")
                print("📊 [ChatViewModel] Messages après filtrage : \(filteredMessages.count)")
                print("📊 [ChatViewModel] Messages envoyés à l'API : \(recentMessages.count) (max 20)")

                // 4. Appeler la nouvelle méthode avec historique
                let response = try await OpenAIService.sendMessage(
                    messages: recentMessages,
                    systemPrompt: systemPrompt
                )
                
                // Remplacer le message temporaire par la vraie réponse
                await MainActor.run {
                    if let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == typingMessageID }) {
                        conversations[index].messages[messageIndex] = Message(
                            id: typingMessageID,
                            contenu: response,
                            isUser: false
                        )
                        conversations[index].lastModified = Date()

                        // Auto-save après réception de la réponse
                        storage.save(conversations[index])
                    }
                    isGenerating = false
                    print("✅ [ChatViewModel] Réponse reçue et affichée")
                }
                
            } catch let error as OpenAIError {
                // Gérer les erreurs de l'API
                await MainActor.run {
                    let errorMessage: String
                    switch error {
                    case .noAPIKey:
                        errorMessage = "❌ Aucune clé API configurée.\n\nVérifiez votre fichier .env ou Keychain."
                    case .invalidAPIKey:
                        errorMessage = "❌ Clé API invalide ou expirée.\n\nVérifiez votre clé API dans le fichier .env."
                    case .networkError(let underlyingError):
                        errorMessage = "❌ Erreur réseau : \(underlyingError.localizedDescription)\n\nVérifiez votre connexion internet."
                    case .rateLimitExceeded:
                        errorMessage = "❌ Limite de requêtes atteinte.\n\nRéessayez dans quelques instants."
                    case .serverError(let code):
                        errorMessage = "❌ Erreur serveur OpenAI (\(code)).\n\nRéessayez plus tard."
                    case .invalidResponse, .emptyResponse:
                        errorMessage = "❌ Réponse invalide de l'API.\n\nRéessayez ou contactez le support."
                    }
                    
                    // Remplacer le message temporaire par le message d'erreur
                    if let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == typingMessageID }) {
                        conversations[index].messages[messageIndex] = Message(
                            id: typingMessageID,
                            contenu: errorMessage,
                            isUser: false
                        )
                    }
                    isGenerating = false
                    print("❌ [ChatViewModel] Erreur API: \(error.localizedDescription)")
                }
                
            } catch {
                // Erreur inconnue
                await MainActor.run {
                    let errorMessage = "❌ Erreur inattendue : \(error.localizedDescription)"
                    if let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == typingMessageID }) {
                        conversations[index].messages[messageIndex] = Message(
                            id: typingMessageID,
                            contenu: errorMessage,
                            isUser: false
                        )
                    }
                    isGenerating = false
                    print("❌ [ChatViewModel] Erreur inconnue: \(error.localizedDescription)")
                }
            }
        }
        
        return true
    }
    
    /// Convertit un tableau de NSImage en ImageData
    /// - Parameter alreadyCompressed: Si true, les images sont déjà compressées (TEMPS 2), pas besoin de re-compresser
    private func convertImagesToImageData(_ images: [NSImage], alreadyCompressed: Bool = false) -> [ImageData]? {
        var imageDataArray: [ImageData] = []
        
        for (index, image) in images.enumerated() {
            guard let imageData = convertImageToImageData(image, alreadyCompressed: alreadyCompressed, index: index + 1) else {
                print("❌ [ChatViewModel] Échec de conversion pour l'image \(index + 1)")
                continue
            }
            imageDataArray.append(imageData)
        }
        
        return imageDataArray.isEmpty ? nil : imageDataArray
    }
    
    /// Convertit une NSImage en ImageData
    /// - Parameters:
    ///   - image: Image à convertir (déjà compressée si alreadyCompressed = true)
    ///   - alreadyCompressed: Si true, l'image est déjà compressée (TEMPS 2), pas besoin de re-compresser
    ///   - index: Index de l'image (pour les logs)
    /// - Returns: ImageData ou nil si échec
    private func convertImageToImageData(_ image: NSImage, alreadyCompressed: Bool = false, index: Int = 1) -> ImageData? {
        let currentSizeMB = image.sizeInMB() ?? 0.0
        let size = image.size
        
        print("🖼️ [ChatViewModel] TEMPS 3: Conversion image \(index): \(Int(size.width))x\(Int(size.height)), \(String(format: "%.2f", currentSizeMB)) MB")
        
        // TEMPS 3 : Les images sont déjà compressées (TEMPS 2), pas besoin de re-compresser
        let finalImage: NSImage
        let compressedSizeMB: Double?
        let originalSizeMB: Double
        
        if alreadyCompressed {
            // Image déjà compressée (TEMPS 2), utiliser directement
            print("✅ [ChatViewModel] Image \(index) déjà compressée (TEMPS 2), conversion directe en base64")
            finalImage = image
            // Pour les images déjà compressées, on stocke la taille actuelle comme compressedSizeMB
            // et originalSizeMB = compressedSizeMB (car on ne connaît pas la taille originale)
            compressedSizeMB = currentSizeMB
            originalSizeMB = currentSizeMB
        } else {
            // Compression si nécessaire (fallback pour compatibilité)
            print("⚠️ [ChatViewModel] Image \(index) non compressée, compression maintenant...")
            let compressedImage = image.compressToMaxSize(maxSizeMB: NSImage.maxSizeMB)
            finalImage = compressedImage ?? image
            compressedSizeMB = compressedImage?.sizeInMB()
            originalSizeMB = currentSizeMB
        }
        
        // Vérifier la taille finale
        if let finalSizeMB = finalImage.sizeInMB(), finalSizeMB > NSImage.maxSizeMB {
            print("⚠️ [ChatViewModel] Image \(index) toujours > \(NSImage.maxSizeMB) MB après traitement: \(String(format: "%.2f", finalSizeMB)) MB")
            // On continue quand même, mais on log l'avertissement
        }
        
        // Déterminer le format
        let format: String
        if finalImage.hasAlphaChannel() {
            format = "png"
        } else {
            format = "jpeg"
        }
        
        // Convertir en base64 (skipCompression = true si déjà compressée pour éviter double compression)
        guard let base64 = finalImage.toBase64(maxSizeMB: NSImage.maxSizeMB, skipCompression: alreadyCompressed) else {
            print("❌ [ChatViewModel] Échec de la conversion base64 pour l'image \(index)")
            return nil
        }
        
        // Validation du format base64
        guard base64.hasPrefix("data:image/") && base64.contains(";base64,") else {
            print("❌ [ChatViewModel] Format base64 invalide pour l'image \(index): \(base64.prefix(50))...")
            return nil
        }
        
        let imageData = ImageData(
            originalSizeMB: originalSizeMB,
            compressedSizeMB: compressedSizeMB, // Toujours stocker compressedSizeMB si disponible
            format: format,
            base64: base64,
            width: Int(size.width),
            height: Int(size.height)
        )
        
        // Validation finale
        guard imageData.isValidBase64 else {
            print("❌ [ChatViewModel] ImageData invalide pour l'image \(index)")
            return nil
        }
        
        // Logs détaillés
        if alreadyCompressed {
            let base64Size = imageData.base64SizeMB
            print("✅ [ChatViewModel] Image \(index) convertie en base64 (déjà compressée à \(String(format: "%.2f", currentSizeMB)) MB)")
            print("  📦 Base64: \(String(format: "%.2f", base64Size)) MB, format: \(format)")
        } else if let compressed = compressedSizeMB {
            let ratio = (compressed / originalSizeMB) * 100
            let originalStr = String(format: "%.2f", originalSizeMB)
            let compressedStr = String(format: "%.2f", compressed)
            let ratioStr = String(format: "%.1f", ratio)
            let base64Size = imageData.base64SizeMB
            print("✅ [ChatViewModel] Image \(index) compressée: \(ratioStr)% (\(originalStr) MB -> \(compressedStr) MB)")
            print("  📦 Base64: \(String(format: "%.2f", base64Size)) MB, format: \(format)")
        } else {
            let base64Size = imageData.base64SizeMB
            print("ℹ️ [ChatViewModel] Image \(index) pas de compression nécessaire")
            print("  📦 Base64: \(String(format: "%.2f", base64Size)) MB, format: \(format)")
        }
        
        return imageData
    }
}

// MARK: - Prompts système (valeurs par défaut / fallback)

extension ChatViewModel {
    /// Récupère le prompt sauvegardé pour un type donné
    static func getSavedPrompt(for type: SystemPromptType) -> String {
        let prefs = PreferencesManager.shared.preferences
        switch type {
        case .correcteur:
            return prefs.promptCorrecteur
        case .assistant:
            return prefs.promptAssistant
        case .traducteur:
            return prefs.promptTraducteur
        case .personnalise:
            return ""
        }
    }

    /// Sauvegarde un prompt pour un type donné
    static func savePrompt(_ content: String, for type: SystemPromptType) {
        switch type {
        case .correcteur:
            PreferencesManager.shared.preferences.promptCorrecteur = content
        case .assistant:
            PreferencesManager.shared.preferences.promptAssistant = content
        case .traducteur:
            PreferencesManager.shared.preferences.promptTraducteur = content
        case .personnalise:
            break // Les prompts personnalisés sont gérés autrement
        }
        PreferencesManager.shared.save()
    }

    // Constantes pour rétrocompatibilité et valeurs par défaut
    static let assistantPrompt = """
Tu es un assistant IA utile, respectueux et honnête. Réponds toujours de manière claire et concise.
"""

    static let traducteurPrompt = """
Tu es un traducteur professionnel. Traduis le texte fourni de manière précise et naturelle, en conservant le style et le ton de l'original.
"""
}

// MARK: - Prévisualisation

extension ChatViewModel {
    static let defaultConversations: [Conversation] = []

    static var preview: ChatViewModel {
        ChatViewModel(conversations: defaultConversations, loadFromStorage: false)
    }
}


