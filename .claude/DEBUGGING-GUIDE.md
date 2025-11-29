# 🐛 Guide de Debugging - Correcteur Pro

## Architecture du système de logging

### Niveaux de logs (Debug LogLevel)

```swift
enum DebugLogLevel {
    case debug     // 🔍 Informations de débogage détaillées
    case info      // ℹ️ Informations générales
    case warning   // ⚠️ Avertissements
    case error     // ❌ Erreurs
    case critical  // 🚨 Erreurs critiques
}
```

### DebugLogger (Console UI intégrée)

**Singleton thread-safe** pour capturer les logs dans l'interface utilisateur.

#### Utilisation

```swift
// Logs simples
DebugLogger.shared.log("Message", category: "API", level: .info)

// Méthodes de commodité
DebugLogger.shared.logDebug("Debug info")
DebugLogger.shared.logInfo("General info")
DebugLogger.shared.logWarning("Warning!")
DebugLogger.shared.logError("Error occurred")
DebugLogger.shared.logCritical("Critical failure!")

// Catégories spécifiques
DebugLogger.shared.logAPI("API call completed")
DebugLogger.shared.logCapture("Screen captured")
DebugLogger.shared.logCompression("Image compressed")
```

#### Métadonnées automatiques

Chaque log capture automatiquement :
- Timestamp (HH:mm:ss.SSS)
- Fichier source
- Fonction appelante
- Numéro de ligne
- Niveau de sévérité
- Catégorie

#### Statistiques

```swift
let stats = DebugLogger.shared.stats
print("Erreurs: \(stats.error), Warnings: \(stats.warning)")
print("Total: \(stats.total)")
```

## Bonnes pratiques

### 1. Utiliser le bon niveau de log

```swift
// ✅ BON
DebugLogger.shared.logDebug("User clicked button")  // Détails de débogage
DebugLogger.shared.logInfo("API call started")      // Info générale
DebugLogger.shared.logWarning("Cache miss")         // Avertissement
DebugLogger.shared.logError("Failed to parse JSON") // Erreur récupérable
DebugLogger.shared.logCritical("Database corrupted") // Erreur critique

// ❌ MAUVAIS
DebugLogger.shared.logCritical("Button clicked")    // Niveau trop élevé
DebugLogger.shared.logDebug("Database failed")      // Niveau trop bas
```

### 2. Catégoriser les logs

```swift
// Catégories recommandées
- "API"          // Appels API
- "Capture"      // Captures d'écran
- "Compression"  // Compression d'images
- "System"       // Événements système
- "UI"           // Interactions utilisateur
- "Error"        // Erreurs
- "Performance"  // Métriques de performance
```

### 3. Messages clairs et informatifs

```swift
// ✅ BON
DebugLogger.shared.logAPI("POST /chat/completions - Status: 200, Duration: 1.2s")
DebugLogger.shared.logError("Failed to compress image: size \(sizeMB) MB exceeds limit")

// ❌ MAUVAIS
DebugLogger.shared.logAPI("API call")
DebugLogger.shared.logError("Error")
```

### 4. Éviter les logs sensibles

```swift
// ❌ DANGEREUX
DebugLogger.shared.log("API Key: \(apiKey)")
DebugLogger.shared.log("User password: \(password)")

// ✅ BON
DebugLogger.shared.log("API Key configured: \(apiKey.isEmpty ? "NO" : "YES")")
DebugLogger.shared.log("Authentication successful for user")
```

## Console de Debug UI

### Activation

1. Cliquer sur l'icône **terminal** (🖥️) dans le header
2. La console apparaît en bas de l'application
3. État persisté dans `UserDefaults`

### Fonctionnalités

- **Filtrage** : Recherche par mot-clé ou catégorie
- **Auto-scroll** : Suit automatiquement les nouveaux logs
- **Export** : Copie tous les logs dans le presse-papiers
- **Clear** : Efface tous les logs
- **Compteur** : Affiche le nombre de messages chargés

### Couleurs par catégorie

- 🟦 **Bleu** : Compression
- 🟩 **Vert** : API
- 🟧 **Orange** : Capture
- 🟥 **Rouge** : Error
- 🟪 **Violet** : System

## Debugging dans Xcode

### Console système (os_log)

Tous les logs sont également envoyés à `os_log` :

```bash
# Voir les logs en temps réel
log stream --predicate 'subsystem == "com.correcteurpro"' --level debug

# Logs des 5 dernières minutes
log show --predicate 'subsystem == "com.correcteurpro"' --last 5m

# Filtrer par niveau
log show --predicate 'subsystem == "com.correcteurpro" AND messageType >= 3' --last 1m
```

### Console.app

1. Ouvrir **Console.app**
2. Filtrer par processus : `Correcteur Pro`
3. Rechercher les catégories : `[API]`, `[Capture]`, etc.

## Architecture Thread-Safe

### Pourquoi `@MainActor` ?

```swift
@MainActor
class DebugLogger: ObservableObject {
    @Published private(set) var messages: [LogMessage] = []

    nonisolated func log(...) {
        // Thread-safe: Task s'exécute sur MainActor
        Task { @MainActor in
            messages.append(logMessage)
        }
    }
}
```

**Avantages** :
- Pas de race conditions
- SwiftUI réactivité garantie
- Logs toujours affichés dans l'ordre

### Éviter les deadlocks

```swift
// ✅ BON - Appel asynchrone
Task {
    DebugLogger.shared.log("Processing...")
    await processData()
}

// ⚠️ ATTENTION - Appel synchrone depuis MainActor
@MainActor
func someFunction() {
    DebugLogger.shared.log("Test") // OK, déjà sur MainActor
}
```

## Performance

### Limites

- **Max messages** : 500 (FIFO - premiers supprimés)
- **Filtrage niveau** : `minLogLevel` pour ignorer debug en production
- **Lazy rendering** : `LazyVStack` dans SwiftUI

### Optimisations

```swift
// Activer uniquement en debug
#if DEBUG
DebugLogger.shared.isEnabled = true
#else
DebugLogger.shared.minLogLevel = .warning  // Ignorer debug/info
#endif
```

## Troubleshooting

### Les logs ne s'affichent pas ?

1. **Vérifier que la console est activée** : Icône terminal dans le header
2. **Vérifier le niveau minimum** : `DebugLogger.shared.minLogLevel`
3. **Vérifier les filtres** : Champ de recherche vide ?
4. **Regarder le compteur** : "X messages chargés" dans le header

### Logs manquants après rebuild ?

- Les logs sont volatiles (RAM uniquement)
- Relancer l'action pour regénérer les logs
- Utiliser "Export" pour sauvegarder avant rebuild

### Performance dégradée ?

```swift
// Limiter la verbosité
DebugLogger.shared.minLogLevel = .info  // Ignorer .debug

// Vider régulièrement
DebugLogger.shared.clear()
```

## Tests et validation

### Vérifier le logging

```swift
// Dans les tests
func testLogging() {
    let logger = DebugLogger.shared
    let initialCount = logger.messages.count

    logger.logInfo("Test message")

    XCTAssertEqual(logger.messages.count, initialCount + 1)
    XCTAssertEqual(logger.messages.last?.message, "Test message")
}
```

## Bonnes pratiques globales

### 1. Logger aux points stratégiques

- **Entrée de fonction** : Paramètres importants
- **Décisions critiques** : Conditions, switch cases
- **Appels externes** : API, fichiers, réseau
- **Erreurs** : Toutes les erreurs avec contexte
- **Performance** : Début/fin d'opérations longues

### 2. Éviter la sur-logging

```swift
// ❌ MAUVAIS - Trop verbeux
for item in items {
    DebugLogger.shared.logDebug("Processing item \(item.id)")
}

// ✅ BON - Résumé
DebugLogger.shared.logDebug("Processing \(items.count) items")
```

### 3. Logs structurés

```swift
// ✅ BON - Format consistant
DebugLogger.shared.logAPI("POST /api/endpoint - Status: \(status) - Duration: \(duration)s")
DebugLogger.shared.logError("Failed to \(action): \(error.localizedDescription)")
```

---

**Créé le** : 2025-11-29
**Dernière mise à jour** : 2025-11-29
**Version** : 1.0
