# 📋 Plan d'action : Mode conversation avec historique

## 🎯 Objectif
Améliorer `OpenAIService` pour supporter l'historique conversationnel, permettant à ChatGPT de se souvenir du contexte précédent dans une conversation.

---

## 🔍 Problème à résoudre
- Actuellement, chaque message est envoyé isolément à l'API
- ChatGPT ne peut pas se souvenir des messages précédents
- Pas de contexte conversationnel maintenu
- Impossible d'avoir des conversations cohérentes sur plusieurs échanges

---

## ✅ Solution proposée
Modifier `OpenAIService` et `ChatViewModel` pour :
1. Envoyer tout l'historique de la conversation à l'API
2. Limiter l'historique aux 20 derniers messages pour économiser les tokens
3. Afficher le nombre de tokens estimés
4. Ajouter des optimisations (debounce, annulation, retry)

---

## 🚀 PLAN D'ACTION EN 4 ÉTAPES

### 📝 ÉTAPE 5.1 : Modifier OpenAIService pour accepter l'historique
**Objectif** : Adapter `OpenAIService` pour envoyer tout l'historique conversationnel

**Actions** :
1. Modifier la signature de `sendMessage` dans `OpenAIService.swift` :
   ```swift
   // Ancienne signature :
   static func sendMessage(message: String, systemPrompt: String) async throws -> String
   
   // Nouvelle signature :
   static func sendMessage(messages: [Message], systemPrompt: String) async throws -> String
   ```

2. Créer une méthode de conversion `convertMessagesToOpenAIFormat` :
   ```swift
   private static func convertMessagesToOpenAIFormat(
       _ messages: [Message],
       systemPrompt: String
   ) -> [[String: Any]] {
       var openAIMessages: [[String: Any]] = []
       
       // 1. Ajouter le systemPrompt en premier
       openAIMessages.append([
           "role": "system",
           "content": systemPrompt
       ])
       
       // 2. Convertir les messages utilisateur et assistant
       for message in messages {
           let role = message.isUser ? "user" : "assistant"
           openAIMessages.append([
               "role": role,
               "content": message.contenu
           ])
       }
       
       return openAIMessages
   }
   ```

3. Modifier le body JSON de la requête :
   ```swift
   let requestBody: [String: Any] = [
       "model": model,
       "messages": convertMessagesToOpenAIFormat(messages, systemPrompt: systemPrompt),
       "temperature": 0.7,
       "max_tokens": 2000
   ]
   ```

4. Garder la méthode ancienne pour compatibilité (optionnel) :
   ```swift
   // Méthode de compatibilité (dépréciée)
   static func sendMessage(message: String, systemPrompt: String) async throws -> String {
       let singleMessage = Message(contenu: message, isUser: true)
       return try await sendMessage(messages: [singleMessage], systemPrompt: systemPrompt)
   }
   ```

**Fichiers à modifier** :
- `Correcteur Pro/Services/OpenAIService.swift`

**Validation** : `OpenAIService.sendMessage()` accepte maintenant un tableau de messages et envoie tout l'historique à l'API.

---

### 📝 ÉTAPE 5.2 : Modifier ChatViewModel pour passer l'historique
**Objectif** : Passer toute la conversation active à l'API au lieu d'un seul message

**Actions** :
1. Modifier `ChatViewModel.sendMessage()` :
   ```swift
   // Récupérer tous les messages de la conversation actuelle
   let conversationMessages = conversations[index].messages
   
   // Limiter aux 20 derniers messages pour économiser les tokens
   let recentMessages = Array(conversationMessages.suffix(20))
   
   // Appeler OpenAIService avec tout l'historique
   let response = try await OpenAIService.sendMessage(
       messages: recentMessages,
       systemPrompt: systemPrompt
   )
   ```

2. Gérer le cas où il n'y a pas encore de messages :
   - Si c'est le premier message, envoyer seulement le message utilisateur
   - Le systemPrompt sera toujours inclus en premier

3. Exclure le message temporaire (typing indicator) de l'historique :
   ```swift
   // Filtrer les messages temporaires avant d'envoyer
   let messagesToSend = conversationMessages.filter { message in
       !message.contenu.contains("⏳ Génération en cours...")
   }
   ```

4. Logs pour debug :
   ```swift
   print("📝 [ChatViewModel] Envoi de \(messagesToSend.count) message(s) à l'API")
   print("📝 [ChatViewModel] Messages: \(messagesToSend.map { $0.isUser ? "User" : "Assistant" })")
   ```

**Fichiers à modifier** :
- `Correcteur Pro/ViewModels/ChatViewModel.swift`

**Validation** : Quand on envoie un message, tout l'historique de la conversation est envoyé à l'API.

---

### 📝 ÉTAPE 5.3 : Gestion du contexte et affichage des tokens
**Objectif** : Afficher le nombre de tokens estimés et avertir si la conversation est trop longue

**Actions** :
1. Créer une fonction d'estimation des tokens :
   ```swift
   // Approximation : 4 caractères = 1 token (règle générale OpenAI)
   private func estimateTokens(for messages: [Message], systemPrompt: String) -> Int {
       let totalChars = messages.reduce(0) { $0 + $1.contenu.count } + systemPrompt.count
       return totalChars / 4
   }
   ```

2. Ajouter un affichage dans le header :
   - Afficher le nombre de tokens estimés à côté du titre de la conversation
   - Format : "Conversation (≈ 450 tokens)"
   - Couleur : blanc avec opacité 0.6

3. Afficher un warning si > 3000 tokens :
   - Banner jaune/orange dans le header
   - Message : "⚠️ Conversation longue (≈ X tokens). Les réponses peuvent être plus lentes."
   - Bouton "Nouvelle conversation" pour reset

4. Ajouter un compteur de messages :
   - Afficher "X messages" dans le header
   - Mettre à jour automatiquement

**Fichiers à modifier** :
- `Correcteur Pro/ViewModels/ChatViewModel.swift` : Fonction d'estimation
- `Correcteur Pro/Views/ChatView.swift` : Affichage dans HeaderView

**Validation** : Le nombre de tokens estimés s'affiche dans le header et un warning apparaît si > 3000 tokens.

---

### 📝 ÉTAPE 5.4 : Optimisations (debounce, annulation, retry)
**Objectif** : Améliorer l'expérience utilisateur avec des optimisations

**Actions** :
1. **Debounce** : Empêcher l'envoi de multiples messages simultanés
   - Déjà géré par `isGenerating`, mais améliorer :
   ```swift
   // Dans ChatViewModel
   private var sendTask: Task<Void, Never>?
   
   func sendMessage(...) {
       // Annuler la tâche précédente si elle existe
       sendTask?.cancel()
       
       // Créer une nouvelle tâche
       sendTask = Task {
           // ... code d'envoi
       }
   }
   ```

2. **Bouton "Stop"** : Annuler une génération en cours
   - Ajouter un bouton "Stop" à côté du bouton d'envoi pendant `isGenerating`
   - Action : annuler le `Task` en cours
   - Remplacer le message temporaire par "❌ Génération annulée"

3. **Bouton "Retry"** : Regénérer la dernière réponse
   - Ajouter un bouton "Retry" sur le dernier message assistant en cas d'erreur
   - Action : supprimer le dernier message assistant et le dernier message user, puis renvoyer
   - Ou : renvoyer seulement le dernier message user

4. **Gestion de l'annulation** :
   ```swift
   // Dans le Task
   do {
       let response = try await OpenAIService.sendMessage(...)
       // Vérifier si la tâche a été annulée
       try Task.checkCancellation()
       // ... continuer
   } catch is CancellationError {
       print("⚠️ [ChatViewModel] Génération annulée par l'utilisateur")
       // Remplacer le message temporaire
   }
   ```

**Fichiers à modifier** :
- `Correcteur Pro/ViewModels/ChatViewModel.swift` : Gestion des tâches et annulation
- `Correcteur Pro/Views/ChatView.swift` : Boutons Stop et Retry

**Validation** : On peut annuler une génération en cours, et regénérer une réponse en cas d'erreur.

---

## 🎯 Ordre d'implémentation recommandé

1. **ÉTAPE 5.1** (OpenAIService) - 30 min
   - Modifier la signature et la conversion des messages
   - Tester avec un historique simple

2. **ÉTAPE 5.2** (ChatViewModel) - 20 min
   - Passer tout l'historique à l'API
   - Limiter aux 20 derniers messages

3. **ÉTAPE 5.3** (Affichage tokens) - 25 min
   - Estimation des tokens
   - Affichage dans le header
   - Warning si > 3000 tokens

4. **ÉTAPE 5.4** (Optimisations) - 30 min
   - Debounce et annulation
   - Boutons Stop et Retry

**Total estimé** : ~1h45

---

## 🔧 Fichiers à créer/modifier

### Fichiers à modifier :
- `Correcteur Pro/Services/OpenAIService.swift` : Nouvelle signature avec historique
- `Correcteur Pro/ViewModels/ChatViewModel.swift` : Passer l'historique, estimation tokens
- `Correcteur Pro/Views/ChatView.swift` : Affichage tokens, boutons Stop/Retry

---

## ✅ Critères de validation finale

L'ÉTAPE 5 est validée si :
- ✅ On peut envoyer plusieurs messages dans une conversation
- ✅ ChatGPT se souvient des messages précédents
- ✅ Le nombre de tokens estimés s'affiche dans le header
- ✅ Un warning s'affiche si > 3000 tokens
- ✅ On peut annuler une génération en cours
- ✅ On peut regénérer une réponse en cas d'erreur
- ✅ Les nouvelles conversations repartent de zéro (pas d'historique)
- ✅ L'historique est limité aux 20 derniers messages

---

## 🐛 Gestion des erreurs

### Cas à gérer :
- **Historique vide** : Envoyer seulement le message utilisateur + systemPrompt
- **Historique trop long** : Limiter aux 20 derniers messages
- **Annulation** : Nettoyer proprement le message temporaire
- **Erreur réseau pendant l'envoi** : Permettre le retry

### Gestion recommandée :
- Logger le nombre de messages envoyés
- Afficher un message si l'historique est tronqué (> 20 messages)
- Gérer proprement l'annulation (pas de crash)

---

## 📚 Ressources

- [OpenAI Chat Completions API - Messages](https://platform.openai.com/docs/api-reference/chat/create#chat/create-messages)
- [OpenAI Token Counting](https://platform.openai.com/tokenizer)
- [Swift Task Cancellation](https://developer.apple.com/documentation/swift/task)

---

## 🔄 Prochaines étapes (après ÉTAPE 5)

Une fois l'historique conversationnel terminé, passer à :
- **ÉTAPE 6** : Support des images dans l'API (Vision)
- **ÉTAPE 7** : Persistance et sauvegarde des conversations

---

## 📝 Notes de développement

- **Estimation tokens** : Approximation (4 chars = 1 token), pas exact mais suffisant pour l'UI
- **Limite 20 messages** : Équilibre entre contexte et coût (environ 2000-3000 tokens)
- **SystemPrompt** : Toujours inclus en premier, ne compte pas dans la limite de 20 messages
- **Performance** : L'envoi de l'historique peut ralentir légèrement, mais nécessaire pour le contexte
- **Debug** : Logger le nombre de messages et tokens estimés pour faciliter le debugging

