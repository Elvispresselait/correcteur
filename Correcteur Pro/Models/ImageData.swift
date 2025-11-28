//
//  ImageData.swift
//  Correcteur Pro
//
//  Structure pour stocker les métadonnées et données base64 des images
//

import Foundation

struct ImageData: Codable, Equatable {
    let originalSizeMB: Double
    let compressedSizeMB: Double?
    let format: String // "jpeg", "png"
    let base64: String // Format data:image/...;base64,...
    let width: Int
    let height: Int
    
    /// Taille finale utilisée (compressedSizeMB si disponible, sinon originalSizeMB)
    var finalSizeMB: Double {
        compressedSizeMB ?? originalSizeMB
    }
    
    /// Ratio de compression (1.0 = pas de compression, < 1.0 = compressé)
    var compressionRatio: Double {
        guard let compressed = compressedSizeMB, compressed > 0, originalSizeMB > 0 else { return 1.0 }
        return compressed / originalSizeMB
    }
    
    /// Indique si l'image a été compressée
    var wasCompressed: Bool {
        guard let compressed = compressedSizeMB, originalSizeMB > 0 else { return false }
        return compressed < originalSizeMB
    }
    
    /// Valide que le format base64 est correct
    var isValidBase64: Bool {
        base64.hasPrefix("data:image/") && base64.contains(";base64,")
    }
    
    /// Extrait la taille du base64 en MB (approximative)
    var base64SizeMB: Double {
        // Compter les caractères après "base64,"
        if let base64Data = base64.components(separatedBy: ";base64,").last {
            // Approximation : chaque caractère base64 = 3/4 bytes
            let bytes = Double(base64Data.count) * 3.0 / 4.0
            return bytes / (1024 * 1024)
        }
        return 0.0
    }
}

