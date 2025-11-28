# 📋 Plan d'action : Intégration API OpenAI - Test basique

## 🎯 Objectif
Intégrer l'API OpenAI dans l'application pour permettre l'envoi de messages texte et recevoir des réponses réelles de ChatGPT, en remplaçant l'echo actuel.

---

## 🔍 Problème à résoudre
- L'application utilise actuellement un echo (réponse factice)
- Il faut connecter l'application à l'API OpenAI
- Les messages doivent être envoyés et les réponses affichées
- Gérer les erreurs (pas de clé API, erreur réseau, etc.)

---

## ✅ Solution proposée
Créer un service `OpenAIService` qui :
1. Envoie les messages à l'API OpenAI
2. Reçoit et parse les réponses
3. Gère les erreurs de manière élégante
4. Intègre avec `ChatViewModel` pour remplacer l'echo

---

## 🚀 PLAN D'ACTION EN 2 ÉTAPES

### 📝 ÉTAPE 4.1 : Créer OpenAIService (Service API)
**Objectif** : Créer le service de base pour communiquer avec l'API OpenAI

**Actions** :
1. Créer `Correcteur Pro/Services/OpenAIService.swift` :
   - Classe `OpenAIService` avec méthodes statiques
   - Utiliser `URLSession` pour les requêtes HTTP
   - Endpoint : `https://api.openai.com/v1/chat/completions`

2. Implémenter `sendMessage(message: String, systemPrompt: String) async throws -> String` :
   ```swift
   - Récupérer la clé API depuis APIKeyManager
   - Vérifier que la clé existe (sinon throw OpenAIError.noAPIKey)
   - Créer la requête HTTP POST
   - Headers :
     * "Authorization": "Bearer \(apiKey)"
     * "Content-Type": "application/json"
   - Body JSON :
     {
       "model": "gpt-4o-mini",
       "messages": [
         {"role": "system", "content": systemPrompt},
         {"role": "user", "content": message}
       ],
       "temperature": 0.7,
       "max_tokens": 2000
     }
   - Utiliser async/await avec URLSession.shared.data(for:)
   - Parser la réponse JSON
   - Extraire le contenu de la réponse (response.choices[0].message.content)
   - Retourner le texte de la réponse
   ```

3. Gestion des erreurs :
   - **Enum `OpenAIError`** :
     ```swift
     enum OpenAIError: LocalizedError {
         case noAPIKey
         case invalidAPIKey
         case networkError(Error)
         case invalidResponse
         case rateLimitExceeded
         case serverError(Int)
         case emptyResponse
         
         var errorDescription: String? {
             switch self {
             case .noAPIKey:
                 return "Aucune clé API configurée. Ouvrez les Préférences pour configurer."
             case .invalidAPIKey:
                 return "Clé API invalide ou expirée"
             case .networkError(let error):
                 return "Erreur réseau : \(error.localizedDescription)"
             case .invalidResponse:
                 return "Réponse invalide de l'API"
             case .rateLimitExceeded:
                 return "Limite de requêtes atteinte. Réessayez plus tard."
             case .serverError(let code):
                 return "Erreur serveur OpenAI (\(code))"
             case .emptyResponse:
                 return "La réponse de l'API est vide"
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
   - Log de début d'envoi
   - Log du status code
   - Log de succès/échec
   - Log des erreurs détaillées
   - Log du nombre de tokens utilisés (si disponible)

**Fichiers à créer** :
- `Correcteur Pro/Services/OpenAIService.swift` (nouveau)

**Validation** : On peut appeler `OpenAIService.sendMessage()` et recevoir une réponse de l'API OpenAI.

---

### 📝 ÉTAPE 4.2 : Intégrer OpenAIService dans ChatViewModel
**Objectif** : Remplacer l'echo par un appel réel à l'API OpenAI

**Actions** :
1. Modifier `ChatViewModel.sendMessage()` :
   - Supprimer l'echo actuel
   - Ajouter un message "assistant" temporaire avec "..." (typing indicator)
   - Appeler `OpenAIService.sendMessage()` en async
   - Remplacer le message temporaire par la vraie réponse
   - Gérer les erreurs avec un message d'erreur dans la conversation

2. Gestion de l'état de chargement :
   - Ajouter `@Published var isGenerating: Bool = false` dans `ChatViewModel`
   - Mettre à jour `isGenerating` pendant l'appel API
   - Afficher un indicateur de chargement dans l'UI

3. Typing indicator :
   - Créer un message temporaire avec contenu "..." ou "⏳ Génération en cours..."
   - Afficher ce message dans la liste des messages
   - Remplacer par la vraie réponse quand elle arrive
   - Supprimer le message temporaire en cas d'erreur

4. Gestion des erreurs dans l'UI :
   - Si erreur `noAPIKey` : Afficher un message invitant à configurer la clé
   - Si erreur réseau : Afficher un message d'erreur réseau
   - Si erreur API : Afficher le message d'erreur de l'API
   - Afficher les erreurs dans un message "assistant" avec style d'erreur

5. Optimisations :
   - Désactiver le bouton d'envoi pendant la génération
   - Empêcher l'envoi de multiples messages simultanés
   - Afficher un toast pour les erreurs critiques

**Fichiers à modifier** :
- `Correcteur Pro/ViewModels/ChatViewModel.swift` : Intégrer OpenAIService
- `Correcteur Pro/Views/ChatView.swift` : Afficher l'état de chargement

**Validation** : On peut envoyer un message texte et recevoir une vraie réponse de ChatGPT. Les erreurs sont gérées proprement.

---

## 🎯 Ordre d'implémentation recommandé

1. **ÉTAPE 4.1** (OpenAIService) - 45 min
   - Créer le service API
   - Tester avec une requête simple
   - Vérifier la gestion d'erreurs

2. **ÉTAPE 4.2** (Intégration) - 30 min
   - Modifier ChatViewModel
   - Ajouter le typing indicator
   - Tester le flux complet

**Total estimé** : ~1h15

---

## 🔧 Fichiers à créer/modifier

### Nouveaux fichiers :
- `Correcteur Pro/Services/OpenAIService.swift`

### Fichiers à modifier :
- `Correcteur Pro/ViewModels/ChatViewModel.swift` : Intégrer OpenAIService
- `Correcteur Pro/Views/ChatView.swift` : Afficher l'état de chargement

---

## ✅ Critères de validation finale

L'ÉTAPE 4 est validée si :
- ✅ On peut envoyer un message texte simple
- ✅ On reçoit une vraie réponse de ChatGPT
- ✅ Le typing indicator s'affiche pendant la génération
- ✅ Les erreurs sont gérées proprement (pas de crash)
- ✅ Un message d'erreur s'affiche si pas de clé API
- ✅ Un message d'erreur s'affiche en cas d'erreur réseau
- ✅ Le bouton d'envoi est désactivé pendant la génération
- ✅ Les logs confirment les appels API

---

## 🐛 Gestion des erreurs

### Erreurs API possibles :
- **401 Unauthorized** : Clé API invalide ou expirée
- **429 Too Many Requests** : Rate limit atteint
- **500 Internal Server Error** : Problème côté OpenAI
- **Network Error** : Pas de connexion internet
- **No API Key** : Clé API non configurée

### Gestion recommandée :
- Afficher des messages d'erreur clairs à l'utilisateur
- Logger toutes les erreurs pour le debug
- Ne pas exposer la clé API dans les logs
- Inviter à configurer la clé si absente

---

## 📚 Ressources

- [OpenAI Chat Completions API](https://platform.openai.com/docs/api-reference/chat)
- [OpenAI Models](https://platform.openai.com/docs/models)
- [URLSession Documentation](https://developer.apple.com/documentation/foundation/urlsession)
- [Swift async/await](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

## 🔄 Prochaines étapes (après ÉTAPE 4)

Une fois l'intégration API basique terminée, passer à :
- **ÉTAPE 5** : Mode conversation avec historique (envoyer tout l'historique)
- **ÉTAPE 6** : Support des images dans l'API (Vision)

---

## 📝 Notes de développement

- **Modèle** : Utiliser `gpt-4o-mini` pour les tests (économique)
- **Performance** : L'appel API peut prendre 2-5 secondes
- **UX** : Feedback visuel immédiat (typing indicator)
- **Debug** : Logs détaillés pour faciliter le debugging
- **Sécurité** : Ne jamais logger la clé API complète

