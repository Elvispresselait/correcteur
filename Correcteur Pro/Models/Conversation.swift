//
//  Conversation.swift
//  Correcteur Pro
//
//  Modèle de données pour les conversations
//

import Foundation

struct Conversation: Identifiable, Equatable, Codable {
    let id: UUID
    var titre: String
    var messages: [Message]
    let createdAt: Date
    var systemPrompt: String // Stocker le prompt système utilisé
    var lastModified: Date // Date de dernière modification

    init(id: UUID = UUID(), titre: String = "Nouvelle conversation", messages: [Message] = [], createdAt: Date = Date(), systemPrompt: String = "Tu es un correcteur orthographique expert.", lastModified: Date = Date()) {
        self.id = id
        self.titre = titre
        self.messages = messages
        self.createdAt = createdAt
        self.systemPrompt = systemPrompt
        self.lastModified = lastModified
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case titre
        case messages
        case createdAt
        case systemPrompt
        case lastModified
    }

    // Decoder personnalisé pour rétrocompatibilité (si systemPrompt manque)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        titre = try container.decode(String.self, forKey: .titre)
        messages = try container.decode([Message].self, forKey: .messages)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? "Tu es un correcteur orthographique expert."
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? createdAt
    }
}

