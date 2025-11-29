# ✅ Validation de l'ÉTAPE 5 : Mode conversation avec historique

## 📊 État d'avancement global

**Progression : 0/4 sous-étapes complétées (0%)**

---

## ⚠️ ÉTAPE 5.1 : Modifier OpenAIService pour accepter l'historique - EN ATTENTE

### Fichiers à modifier
- ❌ `Correcteur Pro/Services/OpenAIService.swift` - **NON MODIFIÉ**

### Fonctionnalités à implémenter
- ❌ Nouvelle signature `sendMessage(messages: [Message], systemPrompt: String) async throws -> String`
- ❌ Méthode `convertMessagesToOpenAIFormat` pour convertir les messages
- ❌ Conversion des messages user → `{"role": "user", "content": "..."}`
- ❌ Conversion des messages assistant → `{"role": "assistant", "content": "..."}`
- ❌ Ajout du systemPrompt en premier dans l'array messages
- ❌ Modification du body JSON pour utiliser l'array messages
- ❌ Méthode de compatibilité (optionnelle) pour l'ancienne signature

### Tests de validation à effectuer
- ❌ On peut appeler `OpenAIService.sendMessage()` avec un tableau de messages
- ❌ Le systemPrompt est toujours en premier dans l'array messages
- ❌ Les messages user et assistant sont correctement convertis
- ❌ L'API reçoit tout l'historique dans le bon format
- ❌ Les logs confirment le nombre de messages envoyés

### Statut
**⚠️ EN ATTENTE** - La modification d'OpenAIService n'est pas encore faite.

---

## ⚠️ ÉTAPE 5.2 : Modifier ChatViewModel pour passer l'historique - EN ATTENTE

### Fichiers à modifier
- ❌ `Correcteur Pro/ViewModels/ChatViewModel.swift` - **NON MODIFIÉ**

### Fonctionnalités à implémenter
- ❌ Récupérer tous les messages de la conversation active
- ❌ Limiter l'historique aux 20 derniers messages
- ❌ Exclure les messages temporaires (typing indicator) de l'historique
- ❌ Passer tout l'historique à `OpenAIService.sendMessage()`
- ❌ Gérer le cas où il n'y a pas encore de messages (premier message)
- ❌ Logs pour debug (nombre de messages envoyés)

### Tests de validation à effectuer
- ❌ Quand on envoie un message, tout l'historique est envoyé à l'API
- ❌ ChatGPT se souvient des messages précédents dans la conversation
- ❌ Les nouvelles conversations repartent de zéro (pas d'historique)
- ❌ L'historique est limité aux 20 derniers messages si > 20
- ❌ Les messages temporaires ne sont pas envoyés à l'API
- ❌ Les logs confirment le nombre de messages envoyés

### Statut
**⚠️ EN ATTENTE** - La modification de ChatViewModel n'est pas encore faite.

---

## ⚠️ ÉTAPE 5.3 : Gestion du contexte et affichage des tokens - EN ATTENTE

### Fichiers à modifier
- ❌ `Correcteur Pro/ViewModels/ChatViewModel.swift` - **NON MODIFIÉ**
- ❌ `Correcteur Pro/Views/ChatView.swift` - **NON MODIFIÉ**

### Fonctionnalités à implémenter
- ❌ Fonction `estimateTokens(for messages: [Message], systemPrompt: String) -> Int`
- ❌ Approximation : 4 caractères = 1 token
- ❌ Affichage du nombre de tokens estimés dans le header
- ❌ Format : "Conversation (≈ 450 tokens)"
- ❌ Warning visuel si > 3000 tokens (banner jaune/orange)
- ❌ Message d'avertissement : "⚠️ Conversation longue (≈ X tokens)..."
- ❌ Bouton "Nouvelle conversation" pour reset
- ❌ Compteur de messages dans le header

### Tests de validation à effectuer
- ❌ Le nombre de tokens estimés s'affiche dans le header
- ❌ Le calcul des tokens est approximativement correct
- ❌ Un warning s'affiche si > 3000 tokens
- ❌ Le compteur de messages s'affiche correctement
- ❌ Le bouton "Nouvelle conversation" reset le contexte

### Statut
**⚠️ EN ATTENTE** - L'affichage des tokens n'est pas encore implémenté.

---

## ⚠️ ÉTAPE 5.4 : Optimisations (debounce, annulation, retry) - EN ATTENTE

### Fichiers à modifier
- ❌ `Correcteur Pro/ViewModels/ChatViewModel.swift` - **NON MODIFIÉ**
- ❌ `Correcteur Pro/Views/ChatView.swift` - **NON MODIFIÉ**

### Fonctionnalités à implémenter
- ❌ Debounce : Gestion des tâches avec `Task` et annulation
- ❌ Variable `sendTask: Task<Void, Never>?` dans ChatViewModel
- ❌ Annulation de la tâche précédente avant d'en créer une nouvelle
- ❌ Bouton "Stop" pour annuler une génération en cours
- ❌ Gestion de `CancellationError` pour nettoyer proprement
- ❌ Message "❌ Génération annulée" si annulée
- ❌ Bouton "Retry" sur le dernier message assistant en cas d'erreur
- ❌ Action retry : supprimer le dernier message assistant et renvoyer

### Tests de validation à effectuer
- ❌ On peut annuler une génération en cours avec le bouton "Stop"
- ❌ Le message temporaire est remplacé par "❌ Génération annulée"
- ❌ On peut regénérer une réponse en cas d'erreur avec "Retry"
- ❌ Le retry supprime le dernier message assistant et renvoie
- ❌ Pas de crash lors de l'annulation
- ❌ Pas de messages dupliqués lors du retry

### Statut
**⚠️ EN ATTENTE** - Les optimisations ne sont pas encore implémentées.

---

## 📋 Checklist de validation finale

### Critères de validation (selon plan d'action)

| Critère | Statut | Notes |
|---------|--------|-------|
| Modifier OpenAIService pour accepter [Message] | ❌ | À implémenter |
| Convertir les messages au format OpenAI | ❌ | À implémenter |
| Passer tout l'historique dans ChatViewModel | ❌ | À implémenter |
| Limiter aux 20 derniers messages | ❌ | À implémenter |
| Afficher le nombre de tokens estimés | ❌ | À implémenter |
| Warning si > 3000 tokens | ❌ | À implémenter |
| Bouton Stop pour annuler | ❌ | À implémenter |
| Bouton Retry pour regénérer | ❌ | À implémenter |
| ChatGPT se souvient du contexte | ❌ | À tester |
| Nouvelles conversations repartent de zéro | ❌ | À tester |

**Score : 0/10 critères validés (0%)**

---

## 🎯 Prochaines actions

### Action immédiate : Implémenter l'ÉTAPE 5.1

**Objectif** : Modifier `OpenAIService` pour accepter un historique de messages.

**Fichier à modifier** : `Correcteur Pro/Services/OpenAIService.swift`

**Fonctionnalités à implémenter** :
1. Nouvelle signature `sendMessage(messages: [Message], systemPrompt: String)`
2. Méthode `convertMessagesToOpenAIFormat`
3. Conversion user/assistant au format OpenAI
4. Ajout du systemPrompt en premier

**Temps estimé** : 30 minutes

---

### Action suivante : Implémenter l'ÉTAPE 5.2

**Objectif** : Modifier `ChatViewModel` pour passer tout l'historique à l'API.

**Fichier à modifier** : `Correcteur Pro/ViewModels/ChatViewModel.swift`

**Fonctionnalités à implémenter** :
1. Récupérer tous les messages de la conversation
2. Limiter aux 20 derniers messages
3. Exclure les messages temporaires
4. Passer l'historique à OpenAIService

**Temps estimé** : 20 minutes

---

### Action suivante : Implémenter l'ÉTAPE 5.3

**Objectif** : Afficher le nombre de tokens estimés et avertir si trop long.

**Fichiers à modifier** :
- `Correcteur Pro/ViewModels/ChatViewModel.swift` (estimation)
- `Correcteur Pro/Views/ChatView.swift` (affichage)

**Fonctionnalités à implémenter** :
1. Fonction d'estimation des tokens
2. Affichage dans le header
3. Warning si > 3000 tokens
4. Compteur de messages

**Temps estimé** : 25 minutes

---

### Action suivante : Implémenter l'ÉTAPE 5.4

**Objectif** : Ajouter les optimisations (debounce, annulation, retry).

**Fichiers à modifier** :
- `Correcteur Pro/ViewModels/ChatViewModel.swift`
- `Correcteur Pro/Views/ChatView.swift`

**Fonctionnalités à implémenter** :
1. Gestion des tâches avec Task
2. Bouton Stop pour annuler
3. Bouton Retry pour regénérer
4. Gestion de CancellationError

**Temps estimé** : 30 minutes

---

## 📝 Scénarios de test

### Test 1 : Contexte conversationnel
**Étapes** :
1. Créer une nouvelle conversation
2. Envoyer : "Mon nom est Alice"
3. Envoyer : "Quel est mon nom ?"
4. Vérifier la réponse

**Résultat attendu** :
- ✅ ChatGPT répond "Alice" (se souvient du contexte)
- ✅ L'historique complet est envoyé à l'API
- ✅ Les logs confirment 2 messages envoyés

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 2 : Limite de 20 messages
**Étapes** :
1. Créer une conversation avec 25 messages
2. Envoyer un nouveau message
3. Vérifier les logs

**Résultat attendu** :
- ✅ Seulement les 20 derniers messages sont envoyés
- ✅ Les logs confirment "20 messages envoyés"
- ✅ Un message d'avertissement s'affiche (optionnel)

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 3 : Affichage des tokens
**Étapes** :
1. Créer une conversation avec plusieurs messages
2. Observer le header

**Résultat attendu** :
- ✅ Le nombre de tokens estimés s'affiche : "Conversation (≈ 450 tokens)"
- ✅ Le compteur de messages s'affiche : "X messages"
- ✅ Le calcul est approximativement correct

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 4 : Warning si > 3000 tokens
**Étapes** :
1. Créer une conversation très longue (> 3000 tokens estimés)
2. Observer le header

**Résultat attendu** :
- ✅ Un banner jaune/orange s'affiche
- ✅ Message : "⚠️ Conversation longue (≈ X tokens)..."
- ✅ Bouton "Nouvelle conversation" visible

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 5 : Annulation avec bouton Stop
**Étapes** :
1. Envoyer un message
2. Cliquer sur "Stop" pendant la génération
3. Vérifier le résultat

**Résultat attendu** :
- ✅ Le bouton "Stop" apparaît pendant la génération
- ✅ La génération s'arrête
- ✅ Le message temporaire est remplacé par "❌ Génération annulée"
- ✅ Pas de crash

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 6 : Retry en cas d'erreur
**Étapes** :
1. Simuler une erreur (désactiver internet)
2. Envoyer un message
3. Cliquer sur "Retry" sur le message d'erreur
4. Réactiver internet
5. Vérifier que le message est renvoyé

**Résultat attendu** :
- ✅ Un bouton "Retry" apparaît sur le message d'erreur
- ✅ Le retry supprime le dernier message assistant
- ✅ Le message est renvoyé avec succès
- ✅ Pas de duplication de messages

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 7 : Nouvelles conversations
**Étapes** :
1. Créer une conversation avec plusieurs messages
2. Créer une nouvelle conversation
3. Envoyer un message dans la nouvelle conversation
4. Vérifier que ChatGPT ne se souvient pas de l'ancienne conversation

**Résultat attendu** :
- ✅ La nouvelle conversation repart de zéro
- ✅ Seulement le nouveau message est envoyé (pas l'historique de l'ancienne)
- ✅ ChatGPT ne fait pas référence à l'ancienne conversation

**Résultat** : ☐ Réussi ☐ Échec

---

## 🔍 Validation technique

### Vérifications de code

- [ ] `OpenAIService.sendMessage()` accepte `[Message]` au lieu de `String`
- [ ] `convertMessagesToOpenAIFormat` convertit correctement les messages
- [ ] Le systemPrompt est toujours en premier dans l'array messages
- [ ] `ChatViewModel.sendMessage()` passe tout l'historique à l'API
- [ ] L'historique est limité aux 20 derniers messages
- [ ] Les messages temporaires sont exclus de l'historique
- [ ] `estimateTokens` calcule approximativement les tokens
- [ ] L'affichage des tokens est visible dans le header
- [ ] Le warning s'affiche si > 3000 tokens
- [ ] Le bouton "Stop" annule proprement la génération
- [ ] Le bouton "Retry" regénère la réponse
- [ ] Les tâches sont correctement gérées avec `Task`

### Vérifications de logs

Lors de l'envoi d'un message avec historique, les logs doivent afficher :
- [ ] `📝 [ChatViewModel] Envoi de X message(s) à l'API`
- [ ] `📝 [ChatViewModel] Messages: [User, Assistant, User, ...]`
- [ ] `📊 [ChatViewModel] Tokens estimés: X`
- [ ] `⚠️ [ChatViewModel] Historique tronqué à 20 messages` (si > 20)
- [ ] `🔍 [OpenAIService] Envoi de X messages à l'API`

---

## ✅ Résumé

### Ce qui doit être fait
- ⚠️ Modifier `OpenAIService` pour accepter l'historique
- ⚠️ Modifier `ChatViewModel` pour passer tout l'historique
- ⚠️ Afficher le nombre de tokens estimés
- ⚠️ Ajouter les optimisations (Stop, Retry)

### Statut global
**🔴 0% COMPLÉTÉ** - L'historique conversationnel n'est pas encore implémenté. Prêt à démarrer l'implémentation.

---

## 🚀 Prochaines étapes (après ÉTAPE 5)

Une fois l'historique conversationnel complété, passer à :
- **ÉTAPE 6** : Support des images dans l'API (Vision)
- **ÉTAPE 7** : Persistance et sauvegarde des conversations

---

*Dernière mise à jour : Décembre 2024*

