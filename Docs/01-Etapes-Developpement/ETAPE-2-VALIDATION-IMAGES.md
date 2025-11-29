# 🧪 Guide de tests - Support des images

## 📋 Objectif
Vérifier que toutes les fonctionnalités de copier-coller d'images fonctionnent correctement de bout en bout.

---

## ✅ Checklist de tests

### Test 1 : Coller une image depuis Preview
**Objectif** : Vérifier que le collage depuis Preview fonctionne

**Étapes** :
1. Ouvrir une image dans Preview (Cmd+O)
2. Sélectionner l'image (Cmd+A)
3. Copier l'image (Cmd+C)
4. Dans l'application, cliquer dans le champ de saisie
5. Coller l'image (Cmd+V)

**Résultat attendu** :
- ✅ L'image apparaît dans la zone de preview au-dessus du champ de saisie
- ✅ Toast "Image ajoutée" s'affiche
- ✅ Pas de bruit d'erreur macOS
- ✅ Console affiche : `✅ [InputBar] Image ajoutée: ...`

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 2 : Coller une image depuis Safari (screenshot)
**Objectif** : Vérifier que les screenshots fonctionnent

**Étapes** :
1. Prendre un screenshot (Cmd+Shift+4, sélectionner une zone)
2. Le screenshot est automatiquement copié dans le clipboard
3. Dans l'application, cliquer dans le champ de saisie
4. Coller (Cmd+V)

**Résultat attendu** :
- ✅ L'image apparaît dans la zone de preview
- ✅ Toast "Image ajoutée" s'affiche
- ✅ Pas de bruit d'erreur macOS

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 3 : Coller une image très grande (> 10MB)
**Objectif** : Vérifier que les grandes images sont acceptées et compressées

**Étapes** :
1. Trouver ou créer une image > 10MB (photo haute résolution)
2. Copier l'image (Cmd+C)
3. Dans l'application, coller (Cmd+V)

**Résultat attendu** :
- ✅ L'image est acceptée (pas de rejet)
- ✅ Toast "Image compressée: X MB → Y MB" s'affiche
- ✅ Console affiche : `🔧 [InputBar] TEMPS 2: Compression automatique activée`
- ✅ Console affiche : `✅ [InputBar] Compression réussie: ... MB -> ... MB`
- ✅ L'image dans le preview est la version compressée
- ✅ Pas de bruit d'erreur macOS

**Résultat** : ☐ Réussi ☐ Échec

**Note** : Vérifier dans les logs que la compression a bien eu lieu.

---

### Test 4 : Coller plusieurs images successivement
**Objectif** : Vérifier que plusieurs images peuvent être ajoutées

**Étapes** :
1. Copier une première image (Cmd+C)
2. Coller dans l'application (Cmd+V)
3. Copier une deuxième image (Cmd+C)
4. Coller dans l'application (Cmd+V)
5. Répéter avec une troisième image

**Résultat attendu** :
- ✅ Toutes les images apparaissent dans la zone de preview
- ✅ Le compteur affiche "3 images attachées"
- ✅ Les images sont affichées en grille 2 colonnes
- ✅ Chaque image peut être retirée individuellement (bouton X)

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 5 : Retirer une image avant envoi
**Objectif** : Vérifier que le bouton X fonctionne

**Étapes** :
1. Ajouter 2-3 images au preview
2. Cliquer sur le bouton X d'une image

**Résultat attendu** :
- ✅ L'image est retirée du preview
- ✅ Le compteur se met à jour
- ✅ Animation de retrait fluide
- ✅ Les autres images restent visibles

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 6 : Envoyer un message avec image + texte
**Objectif** : Vérifier l'envoi combiné

**Étapes** :
1. Ajouter une image au preview
2. Taper du texte dans le champ de saisie
3. Cliquer sur le bouton d'envoi (ou Cmd+Return)

**Résultat attendu** :
- ✅ Le message est envoyé avec l'image et le texte
- ✅ L'image apparaît dans la bulle de message
- ✅ Le texte apparaît sous l'image
- ✅ Console affiche : `🖼️ [ChatViewModel] TEMPS 3: Conversion de ... image(s) compressée(s) en ImageData...`
- ✅ Console affiche : `✅ [ChatViewModel] ... image(s) convertie(s) avec succès`
- ✅ Console affiche : `📦 Base64: ... MB, format: ...`

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 7 : Envoyer un message avec seulement des images
**Objectif** : Vérifier l'envoi sans texte

**Étapes** :
1. Ajouter 1-2 images au preview
2. Ne pas taper de texte
3. Cliquer sur le bouton d'envoi

**Résultat attendu** :
- ✅ Le message est envoyé avec uniquement les images
- ✅ Les images apparaissent dans la bulle de message
- ✅ Pas de texte affiché (ou texte vide)
- ✅ Console affiche la conversion en ImageData

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 8 : Voir les images dans l'historique
**Objectif** : Vérifier la persistance des images

**Étapes** :
1. Envoyer un message avec des images
2. Envoyer d'autres messages
3. Faire défiler vers le haut pour voir les anciens messages

**Résultat attendu** :
- ✅ Les images sont toujours visibles dans les anciens messages
- ✅ Les images sont affichées correctement (redimensionnées)
- ✅ Si plusieurs images, elles sont en grille 2 colonnes
- ✅ Les images sont cliquables (curseur change au survol)

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 9 : Cliquer sur une image pour voir en taille réelle
**Objectif** : Vérifier la modal d'image

**Étapes** :
1. Envoyer un message avec une image
2. Cliquer sur l'image dans la bulle de message

**Résultat attendu** :
- ✅ Une modal s'ouvre avec l'image en taille réelle
- ✅ L'image est scrollable (horizontal et vertical si grande)
- ✅ Bouton X en haut à droite pour fermer
- ✅ Fond noir pour meilleur contraste
- ✅ Fermeture avec bouton X ou clic en dehors

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 10 : Conversion base64 fonctionne avec image compressée
**Objectif** : Vérifier que le base64 est généré correctement

**Étapes** :
1. Ajouter une grande image (> 2MB)
2. Vérifier qu'elle est compressée (toast)
3. Envoyer le message
4. Vérifier les logs de la console

**Résultat attendu** :
- ✅ Console affiche : `✅ [ChatViewModel] Image ... déjà compressée (TEMPS 2), conversion directe en base64`
- ✅ Console affiche : `📦 Base64: ... MB, format: jpeg` (ou png)
- ✅ Le base64 commence par `data:image/...;base64,`
- ✅ La taille base64 est < 2MB (ou proche)
- ✅ Pas de double compression (pas de log de compression dans ChatViewModel)

**Résultat** : ☐ Réussi ☐ Échec

**Vérification manuelle** :
- Dans les logs, chercher `[Base64]` et vérifier que `skipCompression` est utilisé
- Vérifier que `ImageData.isValidBase64` retourne `true`

---

### Test 11 : Pas d'erreur macOS (bruit)
**Objectif** : Vérifier qu'il n'y a pas de bruit d'erreur

**Étapes** :
1. Tester tous les scénarios ci-dessus
2. Écouter attentivement les sons système

**Résultat attendu** :
- ✅ Aucun bruit d'erreur macOS (son "basso" ou "sosumi")
- ✅ Pas de message d'erreur dans la console (sauf logs d'avertissement normaux)
- ✅ L'application reste stable

**Résultat** : ☐ Réussi ☐ Échec

---

### Test 12 : Vérifier que l'image compressée est bien celle envoyée à l'API
**Objectif** : Vérifier que seule l'image compressée est stockée dans ImageData

**Étapes** :
1. Ajouter une grande image (> 10MB)
2. Vérifier qu'elle est compressée (toast + logs)
3. Envoyer le message
4. Vérifier les logs détaillés

**Résultat attendu** :
- ✅ Console affiche : `✅ [ChatViewModel] Image ... déjà compressée (TEMPS 2)`
- ✅ Console affiche : `📦 Base64: X MB` où X < 2MB (ou proche)
- ✅ `ImageData.compressedSizeMB` est `nil` (car compression faite au TEMPS 2)
- ✅ `ImageData.originalSizeMB` = taille de l'image compressée
- ✅ `ImageData.base64` contient le base64 de l'image compressée
- ✅ `ImageData.finalSizeMB` < 2MB

**Vérification dans le code** :
- Dans `ChatViewModel.sendMessage()`, vérifier que `message.imageData` contient les bonnes données
- Vérifier que `ImageData.isValidBase64` retourne `true`

**Résultat** : ☐ Réussi ☐ Échec

---

## 🔍 Tests de régression

### Test R1 : Image petite (< 2MB)
**Objectif** : Vérifier qu'une petite image n'est pas compressée inutilement

**Étapes** :
1. Ajouter une image < 2MB
2. Envoyer le message

**Résultat attendu** :
- ✅ Pas de toast de compression
- ✅ Console affiche : `✅ [InputBar] Image déjà sous 2.0 MB, pas de compression nécessaire`
- ✅ L'image est convertie en base64 sans compression

**Résultat** : ☐ Réussi ☐ Échec

---

### Test R2 : Image avec transparence (PNG)
**Objectif** : Vérifier que les PNG avec transparence sont gérés correctement

**Étapes** :
1. Ajouter une image PNG avec transparence
2. Envoyer le message

**Résultat attendu** :
- ✅ L'image est détectée comme PNG (avec alpha)
- ✅ Console affiche : `format: png`
- ✅ Le base64 est au format PNG (ou JPEG si trop grand)

**Résultat** : ☐ Réussi ☐ Échec

---

### Test R3 : Coller du texte après avoir collé une image
**Objectif** : Vérifier que le collage de texte fonctionne toujours

**Étapes** :
1. Ajouter une image
2. Coller du texte (Cmd+V)

**Résultat attendu** :
- ✅ Le texte est collé normalement dans le champ de saisie
- ✅ L'image reste dans le preview
- ✅ Pas de conflit entre collage image et texte

**Résultat** : ☐ Réussi ☐ Échec

---

## 📊 Résumé des tests

**Date du test** : _______________

**Tests réussis** : ___ / 15

**Tests échoués** : ___ / 15

**Problèmes identifiés** :
1. 
2. 
3. 

**Notes** :
- 

---

## 🐛 Debugging

### Si un test échoue :

1. **Vérifier les logs de la console** :
   - Chercher les préfixes `[Clipboard]`, `[InputBar]`, `[ChatViewModel]`, `[Base64]`
   - Vérifier les messages d'erreur (❌) et d'avertissement (⚠️)

2. **Vérifier le clipboard** :
   - Appeler `ClipboardHelper.diagnostic()` dans le code pour voir ce qui est dans le clipboard

3. **Vérifier la compression** :
   - Vérifier que `compressImageIfNeeded()` est appelée
   - Vérifier que `compressToMaxSize()` retourne une image

4. **Vérifier le base64** :
   - Vérifier que `toBase64()` retourne une string valide
   - Vérifier que `ImageData.isValidBase64` retourne `true`

5. **Vérifier les métadonnées** :
   - Vérifier que `ImageData` contient toutes les informations nécessaires
   - Vérifier que `Message.imageData` est bien rempli

---

## ✅ Critères de validation finale

L'ÉTAPE 6 est validée si :
- ✅ Tous les tests 1-12 sont réussis
- ✅ Aucun bruit d'erreur macOS
- ✅ Les images sont correctement compressées
- ✅ Le base64 est généré correctement
- ✅ Les images sont persistantes dans l'historique
- ✅ L'expérience utilisateur est fluide

---

## 📝 Notes de développement

- Les images sont stockées dans `Message.images` pour l'affichage UI
- Les images sont stockées dans `Message.imageData` pour l'envoi API
- La compression se fait au TEMPS 2 (après collage)
- La conversion base64 se fait au TEMPS 3 (avant envoi)
- Le format base64 est : `data:image/jpeg;base64,...` ou `data:image/png;base64,...`

