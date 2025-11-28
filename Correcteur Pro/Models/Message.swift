//
//  Message.swift
//  Correcteur Pro
//
//  Modèle de données pour les messages individuels
//

import Foundation
import AppKit

struct Message: Identifiable, Equatable, Codable {
    let id: UUID
    let contenu: String
    let isUser: Bool
    let timestamp: Date
    let images: [NSImage]? // Pour l'affichage UI (non persisté)
    let imageData: [ImageData]? // Pour l'envoi API et persistance (base64 compressé)

    init(id: UUID = UUID(), contenu: String, isUser: Bool, timestamp: Date = Date(), images: [NSImage]? = nil, imageData: [ImageData]? = nil) {
        self.id = id
        self.contenu = contenu
        self.isUser = isUser
        self.timestamp = timestamp
        self.images = images
        self.imageData = imageData
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case contenu
        case isUser
        case timestamp
        case imageData
        // Note: images (NSImage) n'est pas persisté car il peut être recréé depuis imageData
    }

    // Decoder: recréer les NSImage depuis imageData après le décodage
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        contenu = try container.decode(String.self, forKey: .contenu)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        imageData = try container.decodeIfPresent([ImageData].self, forKey: .imageData)

        // Recréer les NSImage depuis imageData (si présent)
        if let imgData = imageData, !imgData.isEmpty {
            var recreatedImages: [NSImage] = []
            for data in imgData {
                // Extraire le base64 pur (après "data:image/...;base64,")
                if let base64String = data.base64.components(separatedBy: ";base64,").last,
                   let imageDataDecoded = Data(base64Encoded: base64String),
                   let image = NSImage(data: imageDataDecoded) {
                    recreatedImages.append(image)
                }
            }
            images = recreatedImages.isEmpty ? nil : recreatedImages
        } else {
            images = nil
        }
    }

    // Encoder: sauvegarder uniquement les données sérialisables
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contenu, forKey: .contenu)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(imageData, forKey: .imageData)
    }

    // MARK: - Equatable

    static func == (lhs: Message, rhs: Message) -> Bool {
        guard lhs.id == rhs.id,
              lhs.contenu == rhs.contenu,
              lhs.isUser == rhs.isUser,
              lhs.timestamp == rhs.timestamp else {
            return false
        }

        // Comparer les images
        if let lhsImages = lhs.images, let rhsImages = rhs.images {
            guard lhsImages.count == rhsImages.count else { return false }
        } else if lhs.images != nil || rhs.images != nil {
            return false
        }

        // Comparer les imageData
        if let lhsData = lhs.imageData, let rhsData = rhs.imageData {
            guard lhsData == rhsData else { return false }
        } else if lhs.imageData != nil || rhs.imageData != nil {
            return false
        }

        return true
    }
}

