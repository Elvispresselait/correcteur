//
//  ConversationStorage.swift
//  Correcteur Pro
//
//  Service de persistance pour sauvegarder et charger les conversations
//

import Foundation

/// Service pour gérer la persistance locale des conversations
final class ConversationStorage {

    // MARK: - Singleton

    static let shared = ConversationStorage()
    private init() {
        setupStorageDirectory()
    }

    // MARK: - Propriétés

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Répertoire de stockage : ~/Library/Application Support/Correcteur Pro/conversations/
    private lazy var storageDirectory: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("Correcteur Pro")
        let conversationsDirectory = appDirectory.appendingPathComponent("conversations")
        return conversationsDirectory
    }()

    /// Fichier d'index : liste des IDs de conversations
    private lazy var indexFileURL: URL = {
        storageDirectory.appendingPathComponent("index.json")
    }()

    // MARK: - Setup

    /// Crée le répertoire de stockage s'il n'existe pas
    private func setupStorageDirectory() {
        do {
            if !fileManager.fileExists(atPath: storageDirectory.path) {
                try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
                print("📁 [ConversationStorage] Répertoire créé : \(storageDirectory.path)")
            }
        } catch {
            print("❌ [ConversationStorage] Erreur lors de la création du répertoire : \(error.localizedDescription)")
        }
    }

    // MARK: - Sauvegarder

    /// Sauvegarde une conversation (crée ou met à jour le fichier)
    /// - Parameter conversation: La conversation à sauvegarder
    func save(_ conversation: Conversation) {
        let fileURL = conversationFileURL(for: conversation.id)

        do {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(conversation)
            try data.write(to: fileURL, options: .atomic)

            // Mettre à jour l'index
            updateIndex(with: conversation.id)

            print("✅ [ConversationStorage] Conversation sauvegardée : \(conversation.titre)")
        } catch {
            print("❌ [ConversationStorage] Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }

    /// Sauvegarde plusieurs conversations
    /// - Parameter conversations: Les conversations à sauvegarder
    func saveAll(_ conversations: [Conversation]) {
        for conversation in conversations {
            save(conversation)
        }
    }

    // MARK: - Charger

    /// Charge une conversation spécifique
    /// - Parameter id: L'UUID de la conversation
    /// - Returns: La conversation chargée, ou nil si introuvable
    func load(id: UUID) -> Conversation? {
        let fileURL = conversationFileURL(for: id)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("⚠️ [ConversationStorage] Fichier introuvable : \(fileURL.lastPathComponent)")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let conversation = try decoder.decode(Conversation.self, from: data)
            print("✅ [ConversationStorage] Conversation chargée : \(conversation.titre)")
            return conversation
        } catch {
            print("❌ [ConversationStorage] Erreur lors du chargement : \(error.localizedDescription)")
            return nil
        }
    }

    /// Charge toutes les conversations (limitées aux N dernières)
    /// - Parameter limit: Nombre maximum de conversations à charger (par défaut 50)
    /// - Returns: Liste des conversations chargées, triées par date (plus récentes d'abord)
    func loadAll(limit: Int = 50) -> [Conversation] {
        print("📂 [ConversationStorage] Chargement de toutes les conversations (max \(limit))...")

        let conversationIDs = loadIndex()
        var loadedConversations: [Conversation] = []

        for id in conversationIDs.prefix(limit) {
            if let conversation = load(id: id) {
                loadedConversations.append(conversation)
            }
        }

        // Trier par date de dernière modification (plus récentes en premier)
        let sorted = loadedConversations.sorted { $0.lastModified > $1.lastModified }
        print("✅ [ConversationStorage] \(sorted.count) conversations chargées")

        return sorted
    }

    // MARK: - Supprimer

    /// Supprime une conversation
    /// - Parameter id: L'UUID de la conversation à supprimer
    func delete(id: UUID) {
        let fileURL = conversationFileURL(for: id)

        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                print("✅ [ConversationStorage] Conversation supprimée : \(id)")

                // Mettre à jour l'index
                removeFromIndex(id: id)
            }
        } catch {
            print("❌ [ConversationStorage] Erreur lors de la suppression : \(error.localizedDescription)")
        }
    }

    /// Supprime toutes les conversations
    func deleteAll() {
        let conversationIDs = loadIndex()

        for id in conversationIDs {
            delete(id: id)
        }

        // Réinitialiser l'index
        saveIndex([])

        print("✅ [ConversationStorage] Toutes les conversations supprimées")
    }

    // MARK: - Index

    /// Charge l'index des conversations (liste des IDs)
    /// - Returns: Liste des UUIDs des conversations
    private func loadIndex() -> [UUID] {
        guard fileManager.fileExists(atPath: indexFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: indexFileURL)
            let uuidStrings = try decoder.decode([String].self, from: data)
            return uuidStrings.compactMap { UUID(uuidString: $0) }
        } catch {
            print("⚠️ [ConversationStorage] Erreur lors du chargement de l'index : \(error.localizedDescription)")
            return []
        }
    }

    /// Sauvegarde l'index des conversations
    /// - Parameter ids: Liste des UUIDs à sauvegarder
    private func saveIndex(_ ids: [UUID]) {
        do {
            let uuidStrings = ids.map { $0.uuidString }
            let data = try encoder.encode(uuidStrings)
            try data.write(to: indexFileURL, options: .atomic)
        } catch {
            print("❌ [ConversationStorage] Erreur lors de la sauvegarde de l'index : \(error.localizedDescription)")
        }
    }

    /// Ajoute un UUID à l'index (si absent)
    /// - Parameter id: L'UUID à ajouter
    private func updateIndex(with id: UUID) {
        var ids = loadIndex()
        if !ids.contains(id) {
            ids.append(id)
            saveIndex(ids)
        }
    }

    /// Retire un UUID de l'index
    /// - Parameter id: L'UUID à retirer
    private func removeFromIndex(id: UUID) {
        var ids = loadIndex()
        ids.removeAll { $0 == id }
        saveIndex(ids)
    }

    // MARK: - Helpers

    /// Génère l'URL du fichier pour une conversation donnée
    /// - Parameter id: L'UUID de la conversation
    /// - Returns: L'URL du fichier JSON
    private func conversationFileURL(for id: UUID) -> URL {
        storageDirectory.appendingPathComponent("conversation_\(id.uuidString).json")
    }

    // MARK: - Export

    /// Exporte une conversation au format Markdown
    /// - Parameter conversation: La conversation à exporter
    /// - Returns: Le contenu Markdown
    func exportToMarkdown(_ conversation: Conversation) -> String {
        var markdown = "# \(conversation.titre)\n\n"
        markdown += "**Date de création** : \(formatDate(conversation.createdAt))\n"
        markdown += "**System Prompt** : \(conversation.systemPrompt)\n\n"
        markdown += "---\n\n"

        for message in conversation.messages {
            let role = message.isUser ? "👤 **Vous**" : "🤖 **Assistant**"
            markdown += "\(role) • \(formatDate(message.timestamp))\n\n"
            markdown += "\(message.contenu)\n\n"

            if let imageData = message.imageData, !imageData.isEmpty {
                markdown += "*[\(imageData.count) image(s) attachée(s)]*\n\n"
            }

            markdown += "---\n\n"
        }

        return markdown
    }

    /// Formate une date au format lisible
    /// - Parameter date: La date à formater
    /// - Returns: La date formatée
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
}
