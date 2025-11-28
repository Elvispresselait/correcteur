//
//  Message.swift
//  Correcteur Pro
//
//  Modèle de données pour les messages individuels
//

import Foundation
import AppKit

struct Message: Identifiable, Equatable {
    let id: UUID
    let contenu: String
    let isUser: Bool
    let timestamp: Date
    let images: [NSImage]?
    
    init(id: UUID = UUID(), contenu: String, isUser: Bool, timestamp: Date = Date(), images: [NSImage]? = nil) {
        self.id = id
        self.contenu = contenu
        self.isUser = isUser
        self.timestamp = timestamp
        self.images = images
    }
    
    // Equatable: comparer les images par leurs données
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
            // Pour simplifier, on compare juste le nombre d'images
            // Une comparaison complète nécessiterait de comparer les données pixel par pixel
            return true
        }
        return lhs.images == nil && rhs.images == nil
    }
}

