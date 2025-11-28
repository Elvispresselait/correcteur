//
//  ClipboardHelper.swift
//  Correcteur Pro
//
//  Utilitaire pour diagnostiquer et gérer le clipboard
//

import AppKit
import Foundation

struct ClipboardHelper {
    /// Vérifie si le clipboard contient une image
    /// Retourne l'image si trouvée, nil sinon
    /// Affiche des logs de diagnostic dans la console
    static func checkClipboardForImage() -> NSImage? {
        let pasteboard = NSPasteboard.general
        
        print("🔍 [Clipboard] Vérification du clipboard...")
        print("🔍 [Clipboard] Types disponibles: \(pasteboard.types)")
        
        // Vérifier les types d'images possibles
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .tiff,
            .png,
            .pdf,
            .init("public.jpeg"),
            .init("public.image")
        ]
        
        // Méthode 1 : Lire directement NSImage
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            print("✅ [Clipboard] Image détectée via readObjects (NSImage)")
            print("✅ [Clipboard] Taille: \(image.size.width)x\(image.size.height)")
            return image
        }
        
        // Méthode 2 : Vérifier les types disponibles
        for type in imageTypes {
            if pasteboard.availableType(from: [type]) != nil {
                print("✅ [Clipboard] Type image détecté: \(type.rawValue)")
                
                if let data = pasteboard.data(forType: type) {
                    if let image = NSImage(data: data) {
                        print("✅ [Clipboard] Image créée depuis data, taille: \(image.size.width)x\(image.size.height)")
                        return image
                    } else {
                        print("⚠️ [Clipboard] Data trouvée mais impossible de créer NSImage")
                    }
                }
            }
        }
        
        // Méthode 3 : Vérifier les fichiers (drag & drop)
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for file in files {
                print("🔍 [Clipboard] Fichier trouvé: \(file.path)")
                if let image = NSImage(contentsOf: file) {
                    print("✅ [Clipboard] Image chargée depuis fichier: \(file.lastPathComponent)")
                    return image
                }
            }
        }
        
        print("❌ [Clipboard] Aucune image trouvée dans le clipboard")
        return nil
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
        
        print("Types disponibles: \(pasteboard.types.map { String(describing: $0) })")
        
        if let image = checkClipboardForImage() {
            print("✅ Image trouvée: \(image.size.width)x\(image.size.height)")
        } else {
            print("❌ Aucune image")
        }
        
        if let text = checkClipboardForText() {
            print("✅ Texte trouvé: \(text.prefix(50))...")
        } else {
            print("❌ Aucun texte")
        }
        
        print("📋 === FIN DIAGNOSTIC ===\n")
    }
}

