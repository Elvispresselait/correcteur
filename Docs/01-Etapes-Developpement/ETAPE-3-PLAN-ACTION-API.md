# 📋 Plan d'action : Configuration de la clé API OpenAI

## 🎯 Objectif
Permettre à l'utilisateur de configurer sa clé API OpenAI de manière sécurisée, avec stockage dans Keychain, test de connexion, et interface de préférences intuitive.

---

## 🔍 Problème à résoudre
- L'application doit pouvoir communiquer avec l'API OpenAI
- La clé API doit être stockée de manière sécurisée (Keychain)
- L'utilisateur doit pouvoir tester la connexion avant d'utiliser l'API
- Un feedback visuel doit indiquer si la clé est configurée

---

## ✅ Solution proposée
Créer une fenêtre de préférences avec :
1. **Stockage sécurisé** : Utiliser Keychain (Security framework) pour stocker la clé API
2. **Interface utilisateur** : Fenêtre de préférences accessible via menu ou Cmd+,
3. **Test de connexion** : Bouton pour tester la clé API avec l'endpoint `/v1/models`
4. **Feedback visuel** : Banner d'avertissement si pas de clé configurée

---

## 🚀 PLAN D'ACTION EN 4 ÉTAPES

### 📝 ÉTAPE 1 : Créer APIKeyManager (Stockage Keychain)
**Objectif** : Gérer le stockage sécurisé de la clé API dans Keychain

**Actions** :
1. Créer `Correcteur Pro/Utilities/APIKeyManager.swift` :
   - Classe `APIKeyManager` avec méthodes statiques
   - Utiliser `Security` framework (import Security)
   - Service name : `"com.correcteurpro.apiKey"` (ou bundle identifier)
   - Account : `"openai_api_key"`

2. Implémenter `saveAPIKey(_ key: String) -> Bool` :
   ```swift
   - Supprimer l'ancienne clé si elle existe
   - Créer un dictionnaire de requête Keychain
   - Utiliser SecItemAdd pour ajouter la clé
   - Gérer les erreurs (OSStatus)
   - Retourner true si succès, false sinon
   ```

3. Implémenter `loadAPIKey() -> String?` :
   ```swift
   - Créer un dictionnaire de requête Keychain
   - Utiliser SecItemCopyMatching pour récupérer la clé
   - Convertir Data en String
   - Retourner nil si erreur ou clé non trouvée
   ```

4. Implémenter `deleteAPIKey() -> Bool` :
   ```swift
   - Créer un dictionnaire de requête Keychain
   - Utiliser SecItemDelete pour supprimer la clé
   - Retourner true si succès, false sinon
   ```

5. Implémenter `hasAPIKey() -> Bool` :
   ```swift
   - Vérifier si une clé existe sans la charger
   - Utiliser SecItemCopyMatching avec kSecReturnData: false
   - Retourner true si clé existe
   ```

6. Ajouter des logs détaillés pour le debug :
   - Logs de succès/échec pour chaque opération
   - Messages d'erreur OSStatus si échec

**Fichiers à créer** :
- `Correcteur Pro/Utilities/APIKeyManager.swift` (nouveau)

**Validation** : On peut sauvegarder, charger et supprimer une clé API dans Keychain. Les logs confirment les opérations.

---

### 📝 ÉTAPE 2 : Créer SettingsView (Interface utilisateur)
**Objectif** : Créer une fenêtre de préférences pour configurer la clé API

**Actions** :
1. Créer `Correcteur Pro/Views/SettingsView.swift` :
   - Vue SwiftUI avec `@State` pour la clé API (masquée)
   - `@State` pour le statut de connexion (non configuré, test en cours, connecté, erreur)
   - `@State` pour le message d'erreur (optionnel)

2. Section "API Configuration" :
   - **SecureField** pour la clé API :
     - Placeholder : "sk-..."
     - Binding vers `@State private var apiKeyInput: String`
     - Bouton "Afficher/Masquer" pour toggle visibilité
   - **Bouton "Tester la connexion"** :
     - Appelle `testAPIConnection()` en async
     - Désactivé pendant le test
     - Indicateur de chargement pendant le test
   - **Label de statut** :
     - ✅ "Connecté" (vert) si test réussi
     - ❌ "Non connecté" (rouge) si test échoué
     - ⏳ "Test en cours..." (orange) pendant le test
     - ⚠️ "Non configuré" (gris) si pas de clé
   - **Message d'erreur** (si erreur) :
     - Afficher le message d'erreur en rouge
     - Format : "Erreur : [message]"
   - **Lien vers OpenAI** :
     - Bouton "Obtenir une clé API" qui ouvre `https://platform.openai.com/api-keys`
     - Style : lien bleu avec icône externe

3. Boutons d'action :
   - **"Enregistrer"** :
     - Appelle `APIKeyManager.saveAPIKey(apiKeyInput)`
     - Affiche toast de succès/échec
     - Vide le champ si succès
   - **"Supprimer"** :
     - Appelle `APIKeyManager.deleteAPIKey()`
     - Affiche toast de confirmation
     - Reset le statut

4. Charger la clé au démarrage :
   - Dans `onAppear`, charger la clé depuis Keychain
   - Si clé existe, remplir le champ (masqué) et tester automatiquement
   - Si pas de clé, afficher "Non configuré"

5. Design cohérent avec l'app :
   - Utiliser les mêmes couleurs que le reste de l'interface
   - Fond : `Color(hex: "031838")` ou similaire
   - Texte blanc avec opacité
   - Bordures arrondies

**Fichiers à créer** :
- `Correcteur Pro/Views/SettingsView.swift` (nouveau)

**Validation** : On peut ouvrir les préférences, saisir une clé API, tester la connexion, et voir le statut.

---

### 📝 ÉTAPE 3 : Créer OpenAIConnectionTester (Test de connexion)
**Objectif** : Tester la connexion à l'API OpenAI avec la clé configurée

**Actions** :
1. Créer `Correcteur Pro/Utilities/OpenAIConnectionTester.swift` :
   - Classe `OpenAIConnectionTester` avec méthode statique
   - Utiliser `URLSession` pour les requêtes HTTP

2. Implémenter `testConnection(apiKey: String) async throws -> Bool` :
   ```swift
   - Endpoint : https://api.openai.com/v1/models
   - Méthode : GET
   - Headers :
     * "Authorization": "Bearer \(apiKey)"
     * "Content-Type": "application/json"
   - Utiliser async/await avec URLSession.shared.data(from:)
   - Vérifier le status code HTTP (200 = succès)
   - Parser la réponse JSON (vérifier que c'est bien une liste de modèles)
   - Retourner true si succès
   ```

3. Gestion des erreurs :
   - **Enum `ConnectionTestError`** :
     ```swift
     enum ConnectionTestError: LocalizedError {
         case invalidAPIKey
         case networkError(Error)
         case invalidResponse
         case unauthorized
         case serverError(Int)
         
         var errorDescription: String? {
             switch self {
             case .invalidAPIKey:
                 return "Clé API invalide"
             case .networkError(let error):
                 return "Erreur réseau : \(error.localizedDescription)"
             case .invalidResponse:
                 return "Réponse invalide de l'API"
             case .unauthorized:
                 return "Clé API non autorisée (401)"
             case .serverError(let code):
                 return "Erreur serveur (\(code))"
             }
         }
     }
     ```
   - Gérer les codes HTTP :
     - 200 : Succès
     - 401 : Clé API invalide
     - 429 : Rate limit
     - 500+ : Erreur serveur
   - Gérer les erreurs réseau (pas de connexion internet)

4. Logs détaillés :
   - Log de début de test
   - Log du status code
   - Log de succès/échec
   - Log des erreurs détaillées

**Fichiers à créer** :
- `Correcteur Pro/Utilities/OpenAIConnectionTester.swift` (nouveau)

**Validation** : On peut tester une clé API valide et invalide, et voir les messages d'erreur appropriés.

---

### 📝 ÉTAPE 4 : Intégrer SettingsView dans l'application
**Objectif** : Rendre les préférences accessibles et afficher un banner si pas de clé

**Actions** :
1. Modifier `CorrecteurProApp.swift` :
   - Ajouter un menu "Préférences" dans la barre de menu
   - Raccourci clavier : Cmd+,
   - Action : ouvrir `SettingsView` dans une fenêtre

2. Créer une fenêtre de préférences :
   - Option A : Utiliser `WindowGroup` avec `.windowStyle(.hiddenTitleBar)`
   - Option B : Utiliser `NSWindow` programmatiquement
   - Option C : Utiliser un `Sheet` modal (plus simple)
   - **Recommandation** : Utiliser un `Sheet` modal pour commencer

3. Modifier `ContentView.swift` :
   - Ajouter `@State private var showSettings = false`
   - Ajouter un bouton "Préférences" dans le header (ou menu)
   - Afficher `SettingsView` en `.sheet(isPresented: $showSettings)`

4. Ajouter un banner d'avertissement :
   - Dans `ContentView`, vérifier `APIKeyManager.hasAPIKey()`
   - Si `false`, afficher un banner en haut :
     ```swift
     BannerView {
         HStack {
             Image(systemName: "exclamationmark.triangle.fill")
             Text("Clé API non configurée. Ouvrez les Préférences pour configurer.")
             Spacer()
             Button("Ouvrir les Préférences") {
                 showSettings = true
             }
         }
         .padding()
         .background(Color.orange.opacity(0.2))
         .cornerRadius(8)
     }
     ```
   - Le banner disparaît automatiquement quand une clé est configurée

5. Mise à jour automatique :
   - Utiliser `@AppStorage` ou `@StateObject` pour tracker l'état
   - Observer les changements de clé API
   - Mettre à jour le banner automatiquement

**Fichiers à modifier** :
- `Correcteur Pro/CorrecteurProApp.swift` : Ajouter menu Préférences
- `Correcteur Pro/Views/ContentView.swift` : Ajouter bouton et banner
- `Correcteur Pro/Views/SettingsView.swift` : Intégrer dans Sheet

**Validation** : On peut ouvrir les préférences via menu ou Cmd+,, et le banner s'affiche si pas de clé configurée.

---

## 📚 Documentation utilisateur

### Créer un fichier guide pour l'utilisateur

**Fichier** : `GUIDE-CONFIGURATION-API.md`

**Contenu** :
1. **Introduction** : Pourquoi configurer la clé API
2. **Où obtenir une clé API** :
   - Lien vers https://platform.openai.com/api-keys
   - Étapes pour créer un compte OpenAI
   - Comment générer une clé API
3. **Comment configurer** :
   - Ouvrir les Préférences (Cmd+,)
   - Coller la clé API (format : `sk-...`)
   - Tester la connexion
   - Enregistrer
4. **Sécurité** :
   - La clé est stockée dans Keychain (sécurisé)
   - Ne jamais partager sa clé API
   - Que faire si la clé est compromise
5. **Dépannage** :
   - Erreur "Clé API invalide" : Vérifier le format
   - Erreur "Erreur réseau" : Vérifier la connexion internet
   - Erreur "401 Unauthorized" : Clé API expirée ou invalide

**Fichiers à créer** :
- `GUIDE-CONFIGURATION-API.md` (nouveau)

---

## 🎯 Ordre d'implémentation recommandé

1. **ÉTAPE 1** (APIKeyManager) - 30 min
   - Créer la classe de gestion Keychain
   - Tester avec des logs

2. **ÉTAPE 3** (OpenAIConnectionTester) - 25 min
   - Créer le testeur de connexion
   - Tester avec une clé API valide/invalide

3. **ÉTAPE 2** (SettingsView) - 45 min
   - Créer l'interface utilisateur
   - Intégrer APIKeyManager et OpenAIConnectionTester

4. **ÉTAPE 4** (Intégration) - 20 min
   - Ajouter menu et banner
   - Tester le flux complet

5. **Documentation** - 15 min
   - Créer le guide utilisateur

**Total estimé** : ~2h15

---

## 🔧 Fichiers à créer/modifier

### Nouveaux fichiers :
- `Correcteur Pro/Utilities/APIKeyManager.swift`
- `Correcteur Pro/Utilities/OpenAIConnectionTester.swift`
- `Correcteur Pro/Views/SettingsView.swift`
- `GUIDE-CONFIGURATION-API.md`

### Fichiers à modifier :
- `Correcteur Pro/CorrecteurProApp.swift` : Ajouter menu Préférences
- `Correcteur Pro/Views/ContentView.swift` : Ajouter bouton et banner

---

## ✅ Critères de validation finale

L'ÉTAPE 3 est validée si :
- ✅ On peut sauvegarder une clé API dans Keychain
- ✅ On peut charger la clé API depuis Keychain
- ✅ On peut supprimer la clé API
- ✅ On peut ouvrir les préférences (menu ou Cmd+,)
- ✅ On peut tester la connexion avec une clé valide
- ✅ On voit un message d'erreur avec une clé invalide
- ✅ Le banner s'affiche si pas de clé configurée
- ✅ Le banner disparaît quand une clé est configurée
- ✅ La clé est persistante après redémarrage de l'app
- ✅ Les logs confirment toutes les opérations

---

## 🐛 Gestion des erreurs

### Erreurs Keychain possibles :
- `errSecDuplicateItem` : Clé déjà existante (gérer avec SecItemDelete puis SecItemAdd)
- `errSecItemNotFound` : Clé non trouvée (normal si première utilisation)
- `errSecAuthFailed` : Problème d'autorisation Keychain

### Erreurs API possibles :
- **401 Unauthorized** : Clé API invalide ou expirée
- **429 Too Many Requests** : Rate limit atteint
- **500 Internal Server Error** : Problème côté OpenAI
- **Network Error** : Pas de connexion internet

### Gestion recommandée :
- Afficher des messages d'erreur clairs à l'utilisateur
- Logger toutes les erreurs pour le debug
- Ne pas exposer la clé API dans les logs

---

## 📚 Ressources

- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [URLSession Documentation](https://developer.apple.com/documentation/foundation/urlsession)
- [SwiftUI SecureField](https://developer.apple.com/documentation/swiftui/securefield)
- [SwiftUI Sheet](https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:))

---

## 🔄 Prochaines étapes (après ÉTAPE 3)

Une fois la configuration API terminée, passer à :
- **ÉTAPE 4** : Intégration API OpenAI - Test basique (envoi de messages texte)
- **ÉTAPE 5** : Support des images dans l'API (Vision)

---

## 📝 Notes de développement

- **Sécurité** : Toujours utiliser Keychain pour stocker les clés API
- **Performance** : Le test de connexion doit être rapide (< 2 secondes)
- **UX** : Feedback visuel immédiat pour toutes les actions
- **Debug** : Logs détaillés pour faciliter le debugging
- **Compatibilité** : Tester sur différentes versions de macOS

