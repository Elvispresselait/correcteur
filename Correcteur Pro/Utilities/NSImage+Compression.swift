//
//  NSImage+Compression.swift
//  Correcteur Pro
//
//  Extension pour compression d'images et conversion base64
//

import AppKit
import Foundation
import ImageIO
import CoreGraphics

enum ImageFormat {
    case jpeg
    case png
    case auto // Choisit automatiquement le meilleur format
}

extension NSImage {
    /// Taille maximale recommandée pour OpenAI Vision (2MB)
    static let maxSizeMB: Double = 2.0
    
    /// Compresse l'image jusqu'à atteindre la taille maximale
    /// - Parameters:
    ///   - maxSizeMB: Taille maximale en MB (défaut: 2.0)
    ///   - targetFormat: Format cible (JPEG, PNG, ou Auto)
    /// - Returns: Image compressée ou nil si échec
    func compressToMaxSize(maxSizeMB: Double = NSImage.maxSizeMB, targetFormat: ImageFormat = .auto) -> NSImage? {
        let maxSizeBytes = Int(maxSizeMB * 1024 * 1024)
        
        print("🔍 [Compression] DEBUG: compressToMaxSize appelé avec maxSizeMB=\(maxSizeMB)")
        
        // Vérifier la taille actuelle
        guard let currentData = self.tiffRepresentation else {
            print("❌ [Compression] Impossible de lire les données de l'image")
            return nil
        }
        
        let currentSizeMB = Double(currentData.count) / (1024 * 1024)
        print("🔍 [Compression] DEBUG: Taille actuelle (TIFF): \(String(format: "%.2f", currentSizeMB)) MB (\(currentData.count) bytes)")
        print("🔍 [Compression] DEBUG: Taille max autorisée: \(String(format: "%.2f", maxSizeMB)) MB (\(maxSizeBytes) bytes)")
        
        guard currentData.count > maxSizeBytes else {
            print("✅ [Compression] Image déjà sous la limite (\(String(format: "%.2f", currentSizeMB)) MB)")
            return self
        }
        
        print("🔧 [Compression] Compression nécessaire: \(String(format: "%.2f", currentSizeMB)) MB -> \(String(format: "%.2f", maxSizeMB)) MB")
        
        // Déterminer le format
        let format: ImageFormat
        switch targetFormat {
        case .auto:
            // Choisir JPEG par défaut (meilleure compression)
            // Garder PNG seulement si l'image a de la transparence
            format = hasAlphaChannel() ? .png : .jpeg
        default:
            format = targetFormat
        }
        
        print("📄 [Compression] Format choisi: \(format == .jpeg ? "JPEG" : "PNG")")
        
        // Essayer différentes qualités pour JPEG
        if format == .jpeg {
            let qualities: [CGFloat] = [0.8, 0.6, 0.4, 0.3, 0.2]
            
            for quality in qualities {
                if let compressed = compressJPEG(quality: quality) {
                    if let data = compressed.tiffRepresentation, data.count <= maxSizeBytes {
                        print("✅ [Compression] Compression réussie avec qualité \(quality): \(String(format: "%.2f", Double(data.count) / (1024 * 1024))) MB")
                        return compressed
                    }
                }
            }
            
            // Si compression JPEG seule ne suffit pas, redimensionner
            print("⚠️ [Compression] Compression JPEG insuffisante, redimensionnement...")
            let resized = resizeIfNeeded(maxDimension: 2048)
            for quality in qualities {
                if let compressed = resized.compressJPEG(quality: quality) {
                    if let data = compressed.tiffRepresentation, data.count <= maxSizeBytes {
                        print("✅ [Compression] Compression réussie après redimensionnement: \(String(format: "%.2f", Double(data.count) / (1024 * 1024))) MB")
                        return compressed
                    }
                }
            }
        } else {
            // PNG : compression moins efficace, convertir en JPEG si trop grand
            if let pngData = compressPNG() {
                if let data = pngData.tiffRepresentation, data.count <= maxSizeBytes {
                    print("✅ [Compression] PNG compressé: \(String(format: "%.2f", Double(data.count) / (1024 * 1024))) MB")
                    return pngData
                }
            }
            
            // PNG trop grand, convertir en JPEG
            print("⚠️ [Compression] PNG trop grand, conversion en JPEG...")
            return compressToMaxSize(maxSizeMB: maxSizeMB, targetFormat: .jpeg)
        }
        
        print("❌ [Compression] Impossible de compresser sous \(String(format: "%.2f", maxSizeMB)) MB")
        return nil
    }
    
    /// Compresse en JPEG avec qualité spécifiée
    private func compressJPEG(quality: CGFloat) -> NSImage? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            return nil
        }
        
        return NSImage(data: jpegData)
    }
    
    /// Compresse en PNG
    private func compressPNG() -> NSImage? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return NSImage(data: pngData)
    }
    
    /// Vérifie si l'image a un canal alpha (transparence)
    func hasAlphaChannel() -> Bool {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        return bitmapImage.hasAlpha
    }
    
    /// Redimensionne l'image si nécessaire
    /// - Parameter maxDimension: Dimension maximale (largeur ou hauteur)
    /// - Returns: Image redimensionnée (ou originale si pas besoin)
    func resizeIfNeeded(maxDimension: CGFloat) -> NSImage {
        let currentSize = self.size
        let maxSize = max(currentSize.width, currentSize.height)
        
        guard maxSize > maxDimension else {
            return self
        }
        
        let scale = maxDimension / maxSize
        let newSize = NSSize(width: currentSize.width * scale, height: currentSize.height * scale)
        
        print("📐 [Compression] Redimensionnement: \(Int(currentSize.width))x\(Int(currentSize.height)) -> \(Int(newSize.width))x\(Int(newSize.height))")
        
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: currentSize),
                  operation: .copy,
                  fraction: 1.0)
        resized.unlockFocus()
        
        return resized
    }
    
    /// Convertit l'image en base64 JPEG avec compression automatique
    /// - Parameters:
    ///   - quality: Qualité JPEG initiale (défaut: 0.8)
    ///   - maxSizeMB: Taille maximale en MB (défaut: 2.0)
    ///   - skipCompression: Si true, ne pas compresser (image déjà compressée)
    /// - Returns: String base64 au format data:image/jpeg;base64,...
    func toBase64JPEG(quality: CGFloat = 0.8, maxSizeMB: Double = NSImage.maxSizeMB, skipCompression: Bool = false) -> String? {
        // Compresser d'abord si nécessaire (sauf si skipCompression = true)
        let imageToConvert = skipCompression ? self : (compressToMaxSize(maxSizeMB: maxSizeMB, targetFormat: .jpeg) ?? self)
        
        guard let tiffData = imageToConvert.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            print("❌ [Base64] Erreur lors de la conversion JPEG")
            return nil
        }
        
        let base64String = jpegData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64String)"
        
        let sizeMB = Double(jpegData.count) / (1024 * 1024)
        if skipCompression {
            print("✅ [Base64] JPEG base64 créé (sans re-compression): \(String(format: "%.2f", sizeMB)) MB")
        } else {
            print("✅ [Base64] JPEG base64 créé: \(String(format: "%.2f", sizeMB)) MB")
        }
        
        return dataURL
    }
    
    /// Convertit l'image en base64 PNG avec compression
    /// Si PNG trop grand, convertit en JPEG à la place
    /// - Parameters:
    ///   - maxSizeMB: Taille maximale en MB (défaut: 2.0)
    ///   - skipCompression: Si true, ne pas compresser (image déjà compressée)
    /// - Returns: String base64 au format data:image/png;base64,... ou data:image/jpeg;base64,...
    func toBase64PNG(maxSizeMB: Double = NSImage.maxSizeMB, skipCompression: Bool = false) -> String? {
        // Essayer PNG d'abord
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("⚠️ [Base64] Erreur PNG, conversion en JPEG...")
            return toBase64JPEG(maxSizeMB: maxSizeMB, skipCompression: skipCompression)
        }
        
        let sizeMB = Double(pngData.count) / (1024 * 1024)
        
        // Si PNG trop grand et compression activée, convertir en JPEG
        if !skipCompression && sizeMB > maxSizeMB {
            print("⚠️ [Base64] PNG trop grand (\(String(format: "%.2f", sizeMB)) MB), conversion en JPEG...")
            return toBase64JPEG(maxSizeMB: maxSizeMB, skipCompression: false)
        }
        
        let base64String = pngData.base64EncodedString()
        let dataURL = "data:image/png;base64,\(base64String)"
        
        if skipCompression {
            print("✅ [Base64] PNG base64 créé (sans re-compression): \(String(format: "%.2f", sizeMB)) MB")
        } else {
            print("✅ [Base64] PNG base64 créé: \(String(format: "%.2f", sizeMB)) MB")
        }
        
        return dataURL
    }
    
    /// Convertit l'image en base64 avec format automatique
    /// - Parameters:
    ///   - maxSizeMB: Taille maximale en MB (défaut: 2.0)
    ///   - skipCompression: Si true, ne pas compresser (image déjà compressée)
    /// - Returns: String base64 avec format approprié
    func toBase64(maxSizeMB: Double = NSImage.maxSizeMB, skipCompression: Bool = false) -> String? {
        if hasAlphaChannel() {
            return toBase64PNG(maxSizeMB: maxSizeMB, skipCompression: skipCompression)
        } else {
            return toBase64JPEG(maxSizeMB: maxSizeMB, skipCompression: skipCompression)
        }
    }
    
    /// Calcule la taille approximative de l'image en MB
    func sizeInMB() -> Double? {
        guard let tiffData = self.tiffRepresentation else { return nil }
        return Double(tiffData.count) / (1024 * 1024)
    }
}

