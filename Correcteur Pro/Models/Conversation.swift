//
//  Conversation.swift
//  Correcteur Pro
//
//  Modèle de données pour les conversations
//

import Foundation

struct Conversation: Identifiable, Equatable {
    let id: UUID
    var titre: String
    var messages: [Message]
    let createdAt: Date
    
    init(id: UUID = UUID(), titre: String = "Nouvelle conversation", messages: [Message] = [], createdAt: Date = Date()) {
        self.id = id
        self.titre = titre
        self.messages = messages
        self.createdAt = createdAt
    }
}

