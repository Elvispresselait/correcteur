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
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation]
    @Published var selectedConversationID: UUID?
    @Published var promptType: SystemPromptType = .correcteur
    @Published var customPrompt: String = ""
    
    var currentSystemPrompt: String {
        switch promptType {
        case .correcteur:
            return ChatViewModel.correcteurPrompt
        case .assistant:
            return ChatViewModel.assistantPrompt
        case .traducteur:
            return ChatViewModel.traducteurPrompt
        case .personnalise:
            return customPrompt.isEmpty ? ChatViewModel.correcteurPrompt : customPrompt
        }
    }
    
    init(conversations: [Conversation]? = nil) {
        let initialConversations = conversations ?? ChatViewModel.defaultConversations
        self.conversations = initialConversations
        self.selectedConversationID = initialConversations.first?.id
    }
    
    var selectedConversation: Conversation? {
        guard let id = selectedConversationID else { return nil }
        return conversations.first(where: { $0.id == id })
    }
    
    func createNewConversation() {
        let newConversation = Conversation(titre: "Nouvelle conversation")
        conversations.insert(newConversation, at: 0)
        selectedConversationID = newConversation.id
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
    }
    
    func renameSelectedConversation(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let id = selectedConversationID,
              let index = conversations.firstIndex(where: { $0.id == id }) else {
            return
        }
        conversations[index].titre = trimmed
    }
    
    @discardableResult
    func sendMessage(_ text: String, images: [NSImage]? = nil) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!trimmed.isEmpty || images != nil),
              let id = selectedConversationID,
              let index = conversations.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        let userMessage = Message(contenu: trimmed, isUser: true, images: images)
        conversations[index].messages.append(userMessage)
        
        let assistantResponse = Message(
            contenu: "Vous avez dit : \(trimmed.isEmpty ? "[Image]" : trimmed)",
            isUser: false
        )
        conversations[index].messages.append(assistantResponse)
        return true
    }
}

// MARK: - Prompts système

extension ChatViewModel {
    static let correcteurPrompt = """
Je veux que tu ne regardes que la partie surlignée.
Tu me la re-rediges complètement en respectant les retours à la ligne.

Ensuite pour chaque faute, tu me rayes le mot entier où il y a la faute, ou les mots entiers où il y a les fautes.
Tu rajoutes un espace devant avec et tu mets en gras et soulignés les mots que tu rajoutes pour corriger.

Ensuite, devant chaque paragraphe que tu as modifié, je veux que tu rajoutes une croix rouge (❌).
Et pour les autres paragraphes qui restent, je veux que tu rajoutes une croix verte (✅) devant chaque paragraphe.
"""
    
    static let assistantPrompt = """
Tu es un assistant IA utile, respectueux et honnête. Réponds toujours de manière claire et concise.
"""
    
    static let traducteurPrompt = """
Tu es un traducteur professionnel. Traduis le texte fourni de manière précise et naturelle, en conservant le style et le ton de l'original.
"""
}

// MARK: - Prévisualisation

extension ChatViewModel {
    static let defaultConversations: [Conversation] = [
        Conversation(
            titre: "Correction de texte 1",
            messages: [
                Message(contenu: "Bonjour, peux-tu corriger ce texte ?", isUser: true),
                Message(contenu: "Bien sûr ! Envoyez-moi le texte à corriger.", isUser: false)
            ]
        ),
        Conversation(titre: "Traduction document"),
        Conversation(titre: "Révision rapport")
    ]
    
    static var preview: ChatViewModel {
        ChatViewModel(conversations: defaultConversations)
    }
}


