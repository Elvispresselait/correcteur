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
    let images: [NSImage]? // Pour l'affichage UI
    let imageData: [ImageData]? // Pour l'envoi API (base64 compressé)
    
    init(id: UUID = UUID(), contenu: String, isUser: Bool, timestamp: Date = Date(), images: [NSImage]? = nil, imageData: [ImageData]? = nil) {
        self.id = id
        self.contenu = contenu
        self.isUser = isUser
        self.timestamp = timestamp
        self.images = images
        self.imageData = imageData
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

