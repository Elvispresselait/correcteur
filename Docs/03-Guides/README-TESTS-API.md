# 🧪 Guide de test de l'API OpenAI

Ce guide explique comment tester l'API OpenAI directement sans passer par l'interface utilisateur, et comment consulter les logs.

---

## 📁 Fichiers créés

### 1. `.env.example`
Template pour la configuration (à copier en `.env` si besoin).

**Note** : Sur macOS, l'application utilise **Keychain** pour stocker la clé API (plus sécurisé). Le fichier `.env` est optionnel et peut être utilisé pour des tests directs.

### 2. `APILogger.swift`
Système de logging qui enregistre tous les appels API dans des fichiers.

**Emplacement des logs** :
```
~/Library/Application Support/Correcteur Pro/api_logs/
```

**Format des fichiers** : `api_YYYY-MM-DD.log`

### 3. `TestAPIService.swift`
Service de test pour l'API sans passer par l'UI.

---

## 🚀 Utilisation

### Option 1 : Utiliser Keychain (recommandé)

1. **Configurer la clé API via l'interface** :
   - Ouvrir les Préférences (⌘,)
   - Coller votre clé API
   - Cliquer sur "Enregistrer"

2. **Tester directement dans le code** :
   ```swift
   // Dans votre code de test
   Task {
       await TestAPIService.testSimpleMessage(
           message: "Dis bonjour",
           systemPrompt: "Tu es un assistant utile."
       )
   }
   ```

### Option 2 : Utiliser un fichier .env (pour tests)

1. **Créer le fichier `.env`** (copier depuis `.env.example`) :
   ```bash
   cp .env.example .env
   ```

2. **Remplir votre clé API** dans `.env` :
   ```
   OPENAI_API_KEY=sk-votre-vraie-clé-ici
   ```

3. **⚠️ IMPORTANT** : Le fichier `.env` est dans `.gitignore` et ne sera **jamais commité**.

---

## 📊 Consulter les logs

### Méthode 1 : Via le code

```swift
// Afficher les informations sur les logs
TestAPIService.showLogInfo()
```

### Méthode 2 : Via le terminal

```bash
# Voir le log du jour en temps réel
tail -f ~/Library/Application\ Support/Correcteur\ Pro/api_logs/api_$(date +%Y-%m-%d).log

# Voir tous les logs du jour
cat ~/Library/Application\ Support/Correcteur\ Pro/api_logs/api_$(date +%Y-%m-%d).log

# Lister tous les fichiers de logs
ls -lh ~/Library/Application\ Support/Correcteur\ Pro/api_logs/
```

### Méthode 3 : Via Finder

1. Ouvrir Finder
2. Aller dans `~/Library/Application Support/Correcteur Pro/api_logs/`
3. Ouvrir le fichier `api_YYYY-MM-DD.log` avec un éditeur de texte

---

## 📝 Format des logs

Chaque ligne de log contient :
```
[YYYY-MM-DD HH:mm:ss.SSS] 🔍 [Service] LEVEL: Message
```

**Exemple** :
```
[2024-12-28 10:30:45.123] 🔍 [OpenAIService] INFO: 📡 Requête POST à https://api.openai.com/v1/chat/completions
[2024-12-28 10:30:45.124] 🔍 [OpenAIService] INFO:    Headers:
[2024-12-28 10:30:45.125] 🔍 [OpenAIService] INFO:      Authorization: Bearer sk-***...
[2024-12-28 10:30:46.500] 🔍 [OpenAIService] INFO: 📥 Réponse 200 reçue en 1.38s
[2024-12-28 10:30:46.501] 🔍 [OpenAIService] INFO:    Tokens: Prompt=25, Completion=50, Total=75
```

---

## 🧪 Tests disponibles

### Test simple

```swift
await TestAPIService.testSimpleMessage(
    message: "Dis bonjour",
    systemPrompt: "Tu es un assistant utile."
)
```

### Test avec historique

```swift
await TestAPIService.testWithHistory()
```

### Afficher les infos sur les logs

```swift
TestAPIService.showLogInfo()
```

---

## 🔒 Sécurité

### ⚠️ IMPORTANT

- **Ne jamais commiter** le fichier `.env` avec une vraie clé API
- Le fichier `.env` est dans `.gitignore` et sera ignoré par Git
- **Keychain est plus sécurisé** que `.env` pour la production
- Les logs **masquent automatiquement** la clé API (affichent seulement `sk-***...`)

### Nettoyage des logs

Les logs sont automatiquement nettoyés après 7 jours (par défaut). Pour changer :

```swift
APILogger.cleanOldLogs(olderThanDays: 14) // Garder 14 jours
```

---

## 📋 Exemple complet

```swift
import Foundation

// Test simple
Task {
    // Test avec clé depuis Keychain
    await TestAPIService.testSimpleMessage(
        message: "Quelle est la capitale de la France ?",
        systemPrompt: "Tu es un assistant géographique."
    )
    
    // Afficher les infos sur les logs
    TestAPIService.showLogInfo()
}
```

---

## 🐛 Debugging

Si vous avez des problèmes :

1. **Vérifier que la clé API est configurée** :
   ```swift
   if APIKeyManager.hasAPIKey() {
       print("✅ Clé API configurée")
   } else {
       print("❌ Aucune clé API")
   }
   ```

2. **Vérifier les logs** :
   - Ouvrir le fichier de log du jour
   - Chercher les erreurs (marquées avec ❌)
   - Vérifier les codes de statut HTTP

3. **Tester la connexion** :
   ```swift
   Task {
       do {
           let isConnected = try await OpenAIConnectionTester.testConnection(
               apiKey: APIKeyManager.loadAPIKey() ?? ""
           )
           print("Connexion: \(isConnected ? "✅" : "❌")")
       } catch {
           print("Erreur: \(error)")
       }
   }
   ```

---

## 📚 Ressources

- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

---

*Dernière mise à jour : Décembre 2024*

