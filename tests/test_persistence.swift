#!/usr/bin/env swift
//
//  test_persistence.swift
//  Tests de persistance des conversations
//

import Foundation

// Test du répertoire de stockage
let fileManager = FileManager.default
let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDirectory = appSupport.appendingPathComponent("Correcteur Pro")
let conversationsDirectory = appDirectory.appendingPathComponent("conversations")

print("📂 Répertoire de stockage attendu :")
print("   \(conversationsDirectory.path)")
print("")

// Vérifier si le répertoire existe
if fileManager.fileExists(atPath: conversationsDirectory.path) {
    print("✅ Le répertoire existe")

    // Lister les fichiers
    do {
        let files = try fileManager.contentsOfDirectory(atPath: conversationsDirectory.path)
        print("📁 Fichiers trouvés : \(files.count)")
        for file in files {
            print("   - \(file)")
        }
    } catch {
        print("❌ Erreur lors de la lecture du répertoire : \(error.localizedDescription)")
    }
} else {
    print("❌ Le répertoire n'existe pas encore")
    print("ℹ️  Il sera créé au premier lancement de l'app")
}
