//
//  ClipboardHelper.swift
//  Correcteur Pro
//
//  Utilitaire pour diagnostiquer et gérer le clipboard
//

import AppKit
import Foundation

enum ClipboardError: LocalizedError {
    case empty
    case unsupportedFormat
    case imageTooLarge(sizeMB: Double, maxMB: Double)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .empty:
            return "Le presse-papiers est vide"
        case .unsupportedFormat:
            return "Format d'image non supporté"
        case .imageTooLarge(let size, let max):
            return String(format: "Image trop grande (%.1f MB, max: %.1f MB)", size, max)
        case .invalidData:
            return "Impossible de lire les données de l'image"
        }
    }
}

struct ClipboardResult {
    let image: NSImage?
    let error: ClipboardError?
    let mimeType: String?
    let sizeMB: Double?
}

struct ClipboardHelper {
    // Taille max recommandée pour OpenAI (4MB pour validation initiale)
    static let maxImageSizeMB: Double = 4.0
    // Taille cible après compression (2MB)
    static let targetSizeMB: Double = 2.0
    
    /// Vérifie si le clipboard contient une image avec validation
    /// - Parameter autoCompress: Si true, compresse automatiquement les images > 2MB
    /// Retourne un ClipboardResult avec l'image, l'erreur éventuelle, et les métadonnées
    static func checkClipboardForImage(autoCompress: Bool = true) -> ClipboardResult {
        let pasteboard = NSPasteboard.general

        let msg1 = "🔍 [Clipboard] Vérification du clipboard..."
        print(msg1)
        DebugLogger.shared.log(msg1, category: "Capture")

        guard let types = pasteboard.types, !types.isEmpty else {
            let msg = "❌ [Clipboard] Clipboard vide"
            print(msg)
            DebugLogger.shared.logError(msg)
            return ClipboardResult(image: nil, error: .empty, mimeType: nil, sizeMB: nil)
        }
        let typesDescription = types.map { String(describing: $0) }
        let msg2 = "🔍 [Clipboard] Types disponibles: \(typesDescription.joined(separator: ", "))"
        print(msg2)
        DebugLogger.shared.log(msg2, category: "Capture")
        
        // Formats supportés avec leurs types MIME
        let supportedTypes: [(NSPasteboard.PasteboardType, String)] = [
            (.tiff, "image/tiff"),
            (.png, "image/png"),
            (.init("public.jpeg"), "image/jpeg"),
            (.init("public.image"), "image/*"),
            (.pdf, "application/pdf")
        ]
        
        // Méthode 1 : Lire directement NSImage
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            let msg3 = "✅ [Clipboard] Image détectée: \(Int(image.size.width))x\(Int(image.size.height))"
            print(msg3)
            DebugLogger.shared.log(msg3, category: "Capture")

            let originalSizeMB = getImageSizeMB(image: image)

            if let sizeMB = originalSizeMB {
                let msg4 = "📊 [Clipboard] Taille: \(String(format: "%.2f", sizeMB)) MB"
                print(msg4)
                DebugLogger.shared.log(msg4, category: "Capture")
            }

            // TEMPS 1 : Accepter toutes les images sans validation de taille
            // La compression se fera après l'upload (TEMPS 2)
            let msg5 = "✅ [Clipboard] Image acceptée"
            print(msg5)
            DebugLogger.shared.log(msg5, category: "Capture")
            return ClipboardResult(image: image, error: nil, mimeType: "image/unknown", sizeMB: originalSizeMB)
        }
        
        // Méthode 2 : Vérifier les types disponibles avec détection MIME
        for (type, mimeType) in supportedTypes {
            if pasteboard.availableType(from: [type]) != nil {
                print("✅ [Clipboard] Type image détecté: \(type.rawValue) (MIME: \(mimeType))")
                
                if let data = pasteboard.data(forType: type) {
                    let sizeMB = Double(data.count) / (1024 * 1024)
                    print("📊 [Clipboard] Taille des données: \(String(format: "%.2f", sizeMB)) MB")
                    
                    if let image = NSImage(data: data) {
                        print("✅ [Clipboard] Image créée depuis data, taille: \(image.size.width)x\(image.size.height)")
                        
                        // TEMPS 1 : Accepter toutes les images sans validation de taille
                        // La compression se fera après l'upload (TEMPS 2)
                        print("✅ [Clipboard] Image acceptée (validation taille supprimée - compression après upload)")
                        return ClipboardResult(image: image, error: nil, mimeType: mimeType, sizeMB: sizeMB)
                    } else {
                        print("⚠️ [Clipboard] Data trouvée mais impossible de créer NSImage")
                        return ClipboardResult(image: nil, error: .invalidData, mimeType: mimeType, sizeMB: sizeMB)
                    }
                }
            }
        }
        
        // Méthode 3 : Vérifier les fichiers (drag & drop)
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for file in files {
                print("🔍 [Clipboard] Fichier trouvé: \(file.path)")
                
                // Vérifier la taille du fichier (pour info seulement, pas de rejet)
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let fileSize = attributes[.size] as? Int64 {
                    let sizeMB = Double(fileSize) / (1024 * 1024)
                    print("📊 [Clipboard] Taille du fichier: \(String(format: "%.2f", sizeMB)) MB")
                }
                
                if let image = NSImage(contentsOf: file) {
                    let mimeType = getMimeTypeFromExtension(file.pathExtension)
                    let originalSizeMB = getImageSizeMB(image: image)
                    print("✅ [Clipboard] Image chargée depuis fichier: \(file.lastPathComponent) (MIME: \(mimeType ?? "unknown"))")
                    
                    // TEMPS 1 : Accepter toutes les images sans validation de taille
                    // La compression se fera après l'upload (TEMPS 2)
                    print("✅ [Clipboard] Image acceptée (validation taille supprimée - compression après upload)")
                    return ClipboardResult(image: image, error: nil, mimeType: mimeType, sizeMB: originalSizeMB)
                }
            }
        }
        
        print("❌ [Clipboard] Aucune image trouvée dans le clipboard")
        return ClipboardResult(image: nil, error: .unsupportedFormat, mimeType: nil, sizeMB: nil)
    }
    
    /// Version simplifiée pour compatibilité (retourne juste l'image)
    static func checkClipboardForImageSimple() -> NSImage? {
        return checkClipboardForImage().image
    }
    
    /// Calcule la taille approximative d'une image en MB
    private static func getImageSizeMB(image: NSImage) -> Double? {
        guard let tiffData = image.tiffRepresentation else { return nil }
        return Double(tiffData.count) / (1024 * 1024)
    }
    
    /// Détermine le type MIME à partir de l'extension de fichier
    private static func getMimeTypeFromExtension(_ ext: String) -> String? {
        let mimeTypes: [String: String] = [
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "tiff": "image/tiff",
            "tif": "image/tiff",
            "webp": "image/webp",
            "pdf": "application/pdf"
        ]
        return mimeTypes[ext.lowercased()]
    }
    
    /// Vérifie si le clipboard contient du texte
    static func checkClipboardForText() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }
    
    /// Affiche un diagnostic complet du clipboard
    static func diagnostic() {
        print("\n📋 === DIAGNOSTIC CLIPBOARD ===")
        let pasteboard = NSPasteboard.general
        
        print("Types disponibles: \(pasteboard.types?.map { String(describing: $0) } ?? [])")
        
        let result = checkClipboardForImage(autoCompress: false)
        if let image = result.image {
            print("✅ Image trouvée: \(image.size.width)x\(image.size.height)")
            if let mimeType = result.mimeType {
                print("📄 Type MIME: \(mimeType)")
            }
            if let sizeMB = result.sizeMB {
                print("📊 Taille: \(String(format: "%.2f", sizeMB)) MB")
            }
            if let error = result.error {
                print("⚠️ Avertissement: \(error.localizedDescription)")
            }
        } else {
            print("❌ Aucune image")
            if let error = result.error {
                print("❌ Erreur: \(error.localizedDescription)")
            }
        }
        
        if let text = checkClipboardForText() {
            print("✅ Texte trouvé: \(text.prefix(50))...")
        } else {
            print("❌ Aucun texte")
        }
        
        print("📋 === FIN DIAGNOSTIC ===\n")
    }
}

