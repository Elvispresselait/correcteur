//
//  EnvLoader.swift
//  Correcteur Pro
//
//  Charge les variables d'environnement depuis un fichier .env
//  Utile pour le développement et le debug
//

import Foundation

/// Charge les variables d'environnement depuis un fichier .env
final class EnvLoader {
    private static var cachedEnv: [String: String]?
    
    /// Charge le fichier .env depuis le répertoire du projet
    /// - Returns: Un dictionnaire [clé: valeur] des variables d'environnement
    static func loadEnv() -> [String: String] {
        print("")
        print("═══════════════════════════════════════════════════════════════")
        print("🔄 [EnvLoader] APPEL À loadEnv()")
        print("═══════════════════════════════════════════════════════════════")
        
        // Utiliser le cache si disponible
        if let cached = cachedEnv {
            print("ℹ️ [EnvLoader] Utilisation du cache (déjà chargé)")
            print("   Nombre de variables en cache : \(cached.count)")
            print("═══════════════════════════════════════════════════════════════")
            return cached
        }
        
        print("ℹ️ [EnvLoader] Pas de cache, chargement du fichier .env...")
        print("")
        
        var env: [String: String] = [:]
        
        print("📋 ÉTAPE 1 : Construction de la liste des chemins de recherche")
        print("─────────────────────────────────────────────────────────────")
        
        // Chercher le fichier .env dans plusieurs emplacements
        var searchPaths: [String] = []

        // 0. PRIORITÉ ABSOLUE : Ressources du bundle (pour développement avec sandbox)
        print("  [1.0] PRIORITÉ 1 : Recherche dans les ressources du bundle...")
        if let bundleResourcePath = Bundle.main.resourcePath {
            // Chercher d'abord .env, puis env.txt (visible dans Xcode)
            let envPaths = [
                bundleResourcePath + "/.env",
                bundleResourcePath + "/env.txt"
            ]
            for envPath in envPaths {
                searchPaths.append(envPath)
                print("     ✅ Chemin prioritaire ajouté : \(envPath)")
                let exists = FileManager.default.fileExists(atPath: envPath)
                print("     📊 Fichier existe : \(exists ? "✅ OUI" : "❌ NON")")
            }
        } else {
            print("     ⚠️ Bundle resource path non disponible")
        }

        // 1. PRIORITÉ 2 : Chemin du projet connu (pour développement sans sandbox)
        print("  [1.1] PRIORITÉ 2 : Ajout du chemin absolu du projet...")
        let projectUserName = NSUserName()
        let projectRoot = "/Users/\(projectUserName)/Code/Correcteur Pro/.env"
        let expandedProjectRoot = (projectRoot as NSString).expandingTildeInPath
        searchPaths.append(expandedProjectRoot)
        print("     ✅ Chemin prioritaire ajouté : \(expandedProjectRoot)")
        let exists = FileManager.default.fileExists(atPath: expandedProjectRoot)
        print("     📊 Fichier existe : \(exists ? "✅ OUI" : "❌ NON")")
        
        // 1. Répertoire de travail actuel (pour les tests et Xcode)
        print("  [1.1] Ajout du répertoire de travail actuel...")
        let currentDir = FileManager.default.currentDirectoryPath
        print("     Répertoire actuel : \(currentDir)")
        searchPaths.append(currentDir + "/.env")
        print("     ✅ Chemin ajouté : \(currentDir)/.env")
        
        // 2. Remonter depuis le répertoire de travail pour trouver la racine du projet
        print("  [1.2] Remontée depuis le répertoire de travail...")
        var searchDir = URL(fileURLWithPath: currentDir)
        for i in 0..<5 {
            let path = searchDir.path + "/.env"
            searchPaths.append(path)
            print("     ✅ Chemin \(i+1) ajouté : \(path)")
            searchDir = searchDir.deletingLastPathComponent()
            if searchDir.path == "/" { break }
        }
        
        // 3. Répertoire du bundle (pour les builds)
        print("  [1.3] Ajout du répertoire du bundle...")
        let bundlePath = Bundle.main.bundlePath
        print("     Bundle path : \(bundlePath)")
        searchPaths.append(bundlePath + "/.env")
        print("     ✅ Chemin ajouté : \(bundlePath)/.env")
        
        // 4. Remonter depuis le bundle pour trouver la racine du projet
        print("  [1.4] Remontée depuis le bundle...")
        var bundleDir = URL(fileURLWithPath: bundlePath)
        for i in 0..<8 {
            let path = bundleDir.path + "/.env"
            searchPaths.append(path)
            print("     ✅ Chemin \(i+1) ajouté : \(path)")
            bundleDir = bundleDir.deletingLastPathComponent()
            if bundleDir.path == "/" { break }
        }
        
        // 5. Répertoire home
        print("  [1.5] Ajout du répertoire home...")
        let homeDir = NSHomeDirectory()
        print("     Home directory : \(homeDir)")
        searchPaths.append(homeDir + "/.env")
        print("     ✅ Chemin ajouté : \(homeDir)/.env")
        
        // 6. Répertoire du projet depuis le bundle executable (pour les builds Xcode)
        print("  [1.6] Ajout des chemins depuis l'executable...")
        if let executablePath = Bundle.main.executablePath {
            print("     Executable path : \(executablePath)")
            var execDir = URL(fileURLWithPath: executablePath)
            for i in 0..<10 {
                let path = execDir.path + "/.env"
                searchPaths.append(path)
                print("     ✅ Chemin \(i+1) ajouté : \(path)")
                execDir = execDir.deletingLastPathComponent()
                if execDir.path == "/" { break }
            }
        } else {
            print("     ⚠️ Executable path non disponible")
        }
        
        // 7. Répertoire du projet depuis le bundle resource (pour les builds)
        print("  [1.7] Ajout des chemins depuis le resource URL...")
        if let bundleURL = Bundle.main.resourceURL {
            print("     Resource URL : \(bundleURL.path)")
            var resourceDir = bundleURL
            for i in 0..<8 {
                let path = resourceDir.path + "/.env"
                searchPaths.append(path)
                print("     ✅ Chemin \(i+1) ajouté : \(path)")
                resourceDir = resourceDir.deletingLastPathComponent()
                if resourceDir.path == "/" { break }
            }
        } else {
            print("     ⚠️ Resource URL non disponible")
        }
        
        // 8. Chemin absolu du projet (si on peut le déterminer)
        print("  [1.8] Ajout des chemins absolus possibles...")
        let userName = NSUserName()
        let possibleProjectDirs = [
            homeDir + "/Code/Correcteur Pro",
            homeDir + "/Documents/Correcteur Pro",
            homeDir + "/Desktop/Correcteur Pro",
            "/Users/\(userName)/Code/Correcteur Pro",
            "/Users/\(userName)/Documents/Correcteur Pro"
        ]
        for (index, projectDir) in possibleProjectDirs.enumerated() {
            let expandedDir = (projectDir as NSString).expandingTildeInPath
            let path = expandedDir + "/.env"
            searchPaths.append(path)
            print("     ✅ Chemin \(index+1) ajouté : \(path)")
        }
        
        // 9. Chercher dans le répertoire parent du bundle (pour les builds Xcode)
        print("  [1.9] Recherche du projet depuis le bundle...")
        if let bundlePath = Bundle.main.bundlePath as String? {
            print("     Bundle path utilisé : \(bundlePath)")
            var searchPath = URL(fileURLWithPath: bundlePath)
            var foundProject = false
            print("     Début de la boucle de recherche (max 15 itérations)...")
            for i in 0..<15 {
                let pathString = searchPath.path
                print("     [Itération \(i+1)] Vérification : \(pathString)")
                if pathString.contains("Correcteur Pro") {
                    foundProject = true
                    print("     ✅ 'Correcteur Pro' trouvé dans le chemin")
                    var projectRoot = searchPath
                    var depth = 0
                    print("     Remontée pour trouver la racine du projet...")
                    while !projectRoot.lastPathComponent.isEmpty && projectRoot.lastPathComponent != "Correcteur Pro" && depth < 10 {
                        projectRoot = projectRoot.deletingLastPathComponent()
                        depth += 1
                        print("       [Profondeur \(depth)] Chemin actuel : \(projectRoot.path)")
                    }
                    if projectRoot.lastPathComponent == "Correcteur Pro" {
                        let path = projectRoot.path + "/.env"
                        searchPaths.append(path)
                        print("     ✅ Projet trouvé, chemin ajouté : \(path)")
                    } else {
                        print("     ⚠️ Impossible de trouver la racine 'Correcteur Pro' (profondeur max atteinte)")
                    }
                    break
                }
                let previousPath = searchPath.path
                searchPath = searchPath.deletingLastPathComponent()
                if searchPath.path == "/" {
                    print("     ⚠️ Arrêt : racine '/' atteinte")
                    break
                }
                if previousPath == searchPath.path {
                    print("     ⚠️ Arrêt : pas de changement de chemin")
                    break
                }
            }
            if !foundProject {
                print("     ⚠️ Projet 'Correcteur Pro' non trouvé dans le chemin du bundle")
            }
        } else {
            print("     ⚠️ Bundle path non disponible")
        }
        
        print("")
        print("✅ Construction terminée : \(searchPaths.count) chemins à vérifier")
        print("")
        print("═══════════════════════════════════════════════════════════════")
        print("🔍 [EnvLoader] DÉBUT DE LA RECHERCHE DU FICHIER .env")
        print("═══════════════════════════════════════════════════════════════")
        print("📊 Nombre total d'emplacements à vérifier : \(searchPaths.count)")
        print("")
        print("📋 ÉTAPE 2 : Recherche effective du fichier .env")
        print("─────────────────────────────────────────────────────────────")
        print("🔄 Début de la boucle de recherche sur \(searchPaths.count) chemins...")
        print("")
        
        var envFile: String?
        var checkedPaths: [String] = []
        var foundCount = 0
        
        print("🔄 Début de la boucle de recherche sur \(searchPaths.count) chemins...")
        
        for (index, path) in searchPaths.enumerated() {
            let expandedPath = (path as NSString).expandingTildeInPath
            checkedPaths.append(expandedPath)
            
            // Vérifier l'existence du fichier
            let exists = FileManager.default.fileExists(atPath: expandedPath)
            let status = exists ? "✅ TROUVÉ" : "❌"
            
            // Afficher tous les chemins vérifiés (limité à 50 pour ne pas surcharger)
            if index < 50 {
                print("  [\(index + 1)/\(searchPaths.count))] \(status) \(expandedPath)")
            } else if index == 50 {
                print("  ... (affichage limité à 50 chemins)")
            }
            
            if exists {
                envFile = expandedPath
                foundCount += 1
                print("")
                print("═══════════════════════════════════════════════════════════════")
                print("✅ [EnvLoader] FICHIER .env TROUVÉ !")
                print("═══════════════════════════════════════════════════════════════")
                print("📄 Chemin complet : \(expandedPath)")
                print("📊 Index dans la recherche : \(index + 1)/\(searchPaths.count)")
                print("═══════════════════════════════════════════════════════════════")
                break
            }
        }
        
        print("")
        print("✅ Recherche terminée : \(checkedPaths.count) chemins vérifiés, \(foundCount) fichier(s) trouvé(s)")
        print("")
        
        // Log détaillé si pas trouvé
        if envFile == nil {
            print("")
            print("═══════════════════════════════════════════════════════════════")
            print("❌ [EnvLoader] ERREUR : FICHIER .env NON TROUVÉ")
            print("═══════════════════════════════════════════════════════════════")
            print("📊 Nombre de chemins vérifiés : \(checkedPaths.count)")
            print("📊 Nombre de fichiers trouvés : \(foundCount)")
            print("")
            print("📋 LISTE COMPLÈTE DES CHEMINS VÉRIFIÉS :")
            print("─────────────────────────────────────────────────────────────")
            for (index, checkedPath) in checkedPaths.enumerated() {
                let exists = FileManager.default.fileExists(atPath: checkedPath)
                let status = exists ? "✅ EXISTE" : "❌ N'EXISTE PAS"
                print("  [\(index + 1)] \(status) : \(checkedPath)")
            }
            print("─────────────────────────────────────────────────────────────")
            print("")
            print("💡 SOLUTIONS POSSIBLES :")
            print("   1. Vérifiez que le fichier .env existe à la racine du projet")
            print("   2. Chemin attendu : /Users/hadrienrose/Code/Correcteur Pro/.env")
            print("   3. Vérifiez les permissions du fichier")
            print("   4. Vérifiez que le fichier n'est pas dans un sous-répertoire")
            print("═══════════════════════════════════════════════════════════════")
        }
        
        guard let envPath = envFile else {
            print("ℹ️ [EnvLoader] Aucun fichier .env trouvé, utilisation de Keychain uniquement")
            cachedEnv = env
            return env
        }
        
        // Lire le fichier .env
        print("")
        print("📋 ÉTAPE 2 : Lecture du fichier .env")
        print("─────────────────────────────────────────────────────────────")
        do {
            let content = try String(contentsOfFile: envPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            print("✅ Fichier .env lu avec succès")
            print("   Nombre de lignes : \(lines.count)")
            print("   Taille du fichier : \(content.count) caractères")
            print("")
            
            var parsedCount = 0
            var skippedCount = 0
            
            for (lineIndex, line) in lines.enumerated() {
                // Ignorer les lignes vides et les commentaires
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    skippedCount += 1
                    continue
                }
                
                // Parser "KEY=VALUE" ou "KEY='VALUE'" ou "KEY=\"VALUE\""
                if let equalIndex = trimmed.firstIndex(of: "=") {
                    let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                    var value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                    
                    // Supprimer les guillemets si présents
                    if (value.hasPrefix("\"") && value.hasSuffix("\"")) || 
                       (value.hasPrefix("'") && value.hasSuffix("'")) {
                        value = String(value.dropFirst().dropLast())
                    }
                    
                    if !key.isEmpty {
                        env[key] = value
                        parsedCount += 1
                        // Masquer la valeur dans les logs si c'est une clé API
                        if key.uppercased().contains("API") || key.uppercased().contains("KEY") {
                            let masked = String(value.prefix(7)) + "..." + String(value.suffix(4))
                            print("  ✅ [Ligne \(lineIndex + 1)] \(key) = \(masked)")
                        } else {
                            print("  ✅ [Ligne \(lineIndex + 1)] \(key) = \(value)")
                        }
                    }
                } else {
                    print("  ⚠️ [Ligne \(lineIndex + 1)] Format invalide (pas de '=') : \(trimmed.prefix(50))")
                    skippedCount += 1
                }
            }
            
            print("")
            print("═══════════════════════════════════════════════════════════════")
            print("✅ [EnvLoader] LECTURE DU FICHIER .env TERMINÉE")
            print("═══════════════════════════════════════════════════════════════")
            print("📊 Variables parsées : \(parsedCount)")
            print("📊 Lignes ignorées : \(skippedCount) (commentaires/vides)")
            print("📊 Total de variables chargées : \(env.count)")
            print("═══════════════════════════════════════════════════════════════")
            cachedEnv = env
            return env
            
        } catch {
            print("")
            print("═══════════════════════════════════════════════════════════════")
            print("❌ [EnvLoader] ERREUR LORS DE LA LECTURE DU FICHIER .env")
            print("═══════════════════════════════════════════════════════════════")
            print("📄 Chemin du fichier : \(envPath)")
            print("❌ Type d'erreur : \(type(of: error))")
            print("❌ Message d'erreur : \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ Code d'erreur : \(nsError.code)")
                print("❌ Domaine : \(nsError.domain)")
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] {
                    print("❌ Erreur sous-jacente : \(underlyingError)")
                }
            }
            print("")
            print("💡 SOLUTIONS POSSIBLES :")
            print("   1. Vérifiez que le fichier existe : ls -la \"\(envPath)\"")
            print("   2. Vérifiez les permissions : chmod 644 \"\(envPath)\"")
            print("   3. Vérifiez que le fichier n'est pas corrompu")
            print("═══════════════════════════════════════════════════════════════")
            cachedEnv = env
            return env
        }
    }
    
    /// Obtient une variable d'environnement depuis le .env
    /// - Parameter key: Le nom de la variable (ex: "OPENAI_API_KEY")
    /// - Returns: La valeur de la variable si trouvée, nil sinon
    static func get(_ key: String) -> String? {
        print("")
        print("═══════════════════════════════════════════════════════════════")
        print("🔍 [EnvLoader] APPEL À get(\"\(key)\")")
        print("═══════════════════════════════════════════════════════════════")
        
        let env = loadEnv()
        let value = env[key]
        
        if let value = value {
            let masked = key.uppercased().contains("API") || key.uppercased().contains("KEY") 
                ? String(value.prefix(7)) + "..." + String(value.suffix(4))
                : value
            print("✅ [EnvLoader] Variable \"\(key)\" trouvée : \(masked)")
        } else {
            print("❌ [EnvLoader] Variable \"\(key)\" NON TROUVÉE")
            print("   Variables disponibles : \(env.keys.joined(separator: ", "))")
        }
        print("═══════════════════════════════════════════════════════════════")
        
        return value
    }
    
    /// Réinitialise le cache (utile pour recharger le .env après modification)
    static func clearCache() {
        cachedEnv = nil
        print("🔄 [EnvLoader] Cache réinitialisé")
    }
}

