# 📋 Plan d'action : Support du copier-coller d'images

## 🔍 Problème identifié
- `onPasteCommand` sur `TextEditor` ne fonctionne pas correctement sur macOS
- Le TextEditor intercepte le paste et ne le propage pas au modifier
- Résultat : bruit d'erreur macOS + pas de visuel
- **NOUVEAU** : Les images > 4MB sont rejetées AVANT compression au lieu d'être acceptées puis compressées

## ✅ Solution proposée
Utiliser `NSPasteboard` directement avec un monitoring du clipboard ou un wrapper NSViewRepresentable pour avoir un contrôle total.

**NOUVELLE APPROCHE** : Accepter toutes les images, compresser automatiquement après upload, stocker l'image compressée en mémoire.

---

## 🎯 PLAN D'ACTION EN 3 TEMPS

### ⏱️ TEMPS 1 : Accepter toutes les images (supprimer validation préalable)
**Objectif** : Permettre l'upload d'images de n'importe quelle taille sans rejet

**Actions** :
1. Modifier `ClipboardHelper.checkClipboardForImage()` :
   - **SUPPRIMER** toutes les validations de taille avant compression
   - **SUPPRIMER** les erreurs `imageTooLarge` avant compression
   - Accepter toutes les images détectées, quelle que soit leur taille
   - Retourner l'image originale avec `error: nil` même si > 4MB

2. Modifier `TextEditorWithImagePaste` :
   - Ne plus bloquer les images > 4MB
   - Toujours appeler `handleImagePasteResult` avec l'image

3. Modifier `InputBarView.handleImagePasteResult()` :
   - Accepter toutes les images sans vérification de taille
   - Ajouter l'image à `pendingImages` même si très grande

**Fichiers à modifier** :
- `Correcteur Pro/Utilities/ClipboardHelper.swift` : Supprimer validations taille
- `Correcteur Pro/Views/TextEditorWithImagePaste.swift` : Accepter toutes images
- `Correcteur Pro/Views/ChatView.swift` : Supprimer vérifications taille

**Validation** : On peut coller une image de 20MB sans erreur, elle apparaît dans le preview

---

### ⏱️ TEMPS 2 : Compression automatique après upload
**Objectif** : Compresser automatiquement toutes les images > 2MB après leur ajout au preview

**Actions** :
1. Modifier `InputBarView.handleImagePasteResult()` :
   - Après avoir ajouté l'image à `pendingImages`
   - Vérifier si l'image > 2MB
   - Si oui : appeler `image.compressToMaxSize(maxSizeMB: 2.0)`
   - Remplacer l'image originale par l'image compressée dans `pendingImages`
   - Afficher un toast : "Image compressée de X MB à Y MB"

2. Créer une fonction `compressImageIfNeeded(_ image: NSImage) -> NSImage` :
   - Vérifier taille actuelle
   - Si > 2MB : compresser avec `compressToMaxSize(maxSizeMB: 2.0)`
   - Retourner image compressée ou originale si < 2MB

3. Gestion des erreurs de compression :
   - Si compression échoue : garder l'image originale mais afficher warning
   - Toast : "Impossible de compresser l'image (X MB). Elle sera envoyée telle quelle."

**Fichiers à modifier** :
- `Correcteur Pro/Views/ChatView.swift` : Compression dans `handleImagePasteResult`
- `Correcteur Pro/Utilities/NSImage+Compression.swift` : Améliorer logs

**Validation** : Une image de 8MB est automatiquement compressée à ~2MB après collage

---

### ⏱️ TEMPS 3 : Stocker image compressée et envoyer à l'API
**Objectif** : L'image compressée est stockée en mémoire et envoyée à l'API

**Actions** :
1. Modifier `ChatViewModel.sendMessage()` :
   - Les images dans `pendingImages` sont déjà compressées (depuis TEMPS 2)
   - Convertir directement en `ImageData` avec base64
   - Stocker `ImageData` dans le message
   - L'image compressée est celle qui est envoyée à l'API

2. Vérifier que `convertImageToImageData()` :
   - Utilise l'image compressée (pas besoin de re-compresser)
   - Convertit directement en base64
   - Stocke les métadonnées (taille originale, taille compressée)

3. Logs et feedback :
   - Afficher dans les logs : "Image compressée stockée : X MB -> Y MB"
   - Toast lors de l'envoi : "X image(s) compressée(s) envoyée(s)"

**Fichiers à modifier** :
- `Correcteur Pro/ViewModels/ChatViewModel.swift` : Utiliser images déjà compressées
- `Correcteur Pro/Models/Message.swift` : Vérifier stockage ImageData

**Validation** : L'image compressée est envoyée à l'API, pas l'originale

---

## 📝 ÉTAPE 1 : Diagnostic et test du clipboard
**Objectif** : Vérifier que le clipboard contient bien une image

### Actions :
1. Créer une fonction utilitaire `checkClipboardForImage()` qui :
   - Lit `NSPasteboard.general`
   - Vérifie les types disponibles (`.tiff`, `.png`, `.pdf`, etc.)
   - Retourne `NSImage?` si une image est trouvée
   - Affiche un log/console pour debug

2. Tester manuellement :
   - Copier une image (Cmd+C depuis Preview, Safari, etc.)
   - Vérifier dans la console que la fonction détecte l'image
   - Confirmer que `NSImage` est bien créé

**Validation** : Console affiche "Image détectée" quand on colle une image

---

## 📝 ÉTAPE 2 : Implémentation avec NSPasteboard
**Objectif** : Remplacer `onPasteCommand` par une détection directe du clipboard

### Actions :
1. Créer un `NSViewRepresentable` wrapper pour le TextEditor :
   - Permet d'intercepter les événements clavier (Cmd+V)
   - Détecte le paste avant que TextEditor ne le traite
   - Bloque le paste texte si une image est détectée

2. Alternative plus simple : Utiliser un `onKeyPress` ou un `NSEvent` monitor :
   - Détecter Cmd+V globalement quand le TextEditor a le focus
   - Vérifier le clipboard avant que TextEditor ne traite
   - Si image → extraire et ajouter à `pendingImages`
   - Si texte → laisser TextEditor gérer normalement

3. Implémenter `handleImagePasteFromClipboard()` :
   ```swift
   private func handleImagePasteFromClipboard() {
       let pasteboard = NSPasteboard.general
       guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
           return // Pas d'image, laisser TextEditor gérer
       }
       pendingImages.append(image)
       // Optionnel : vider le clipboard pour éviter que le texte soit collé
   }
   ```

**Validation** : Quand on colle une image (Cmd+V), elle apparaît dans le preview

---

## 📝 ÉTAPE 3 : Amélioration UX - Bouton "Coller image"
**Objectif** : Ajouter un moyen alternatif de coller des images

### Actions :
1. Ajouter un bouton avec icône image à côté du TextEditor
2. Action du bouton : appeler `handleImagePasteFromClipboard()`
3. Style cohérent avec l'interface (translucide, hover effect)
4. Tooltip : "Coller une image (Cmd+Shift+V)"

**Validation** : Le bouton fonctionne et colle l'image depuis le clipboard

---

## 📝 ÉTAPE 4 : Gestion des erreurs et feedback visuel
**Objectif** : Améliorer l'expérience utilisateur

### Actions :
1. Gérer les cas d'erreur :
   - Clipboard vide
   - Format non supporté
   - ~~Image trop grande (afficher warning)~~ **SUPPRIMÉ** : On accepte toutes les tailles

2. Feedback visuel :
   - Animation quand une image est ajoutée
   - Message temporaire "Image ajoutée" (toast)
   - Message "Image compressée de X MB à Y MB" si compression
   - Compteur d'images visible

3. Logs de debug :
   - Console logs pour diagnostiquer les problèmes
   - Afficher le type MIME détecté
   - Afficher taille avant/après compression

**Validation** : Pas de bruit d'erreur macOS, feedback clair pour l'utilisateur

---

## 📝 ÉTAPE 5 : Préparation pour le backend (conversion base64)
**Objectif** : Préparer les images pour l'envoi à l'API

### Actions :
1. Créer une extension `NSImage` pour conversion base64 :
   ```swift
   extension NSImage {
       func toBase64JPEG(quality: CGFloat = 0.8) -> String? {
           // Convertir en JPEG avec compression
           // Retourner data:image/jpeg;base64,...
       }
       
       func toBase64PNG() -> String? {
           // Convertir en PNG
           // Retourner data:image/png;base64,...
       }
   }
   ```

2. ~~Ajouter validation des images :~~
   - ~~Taille max (4MB recommandé pour OpenAI)~~ **SUPPRIMÉ** : Compression automatique
   - Formats supportés (JPEG, PNG, GIF, WebP)
   - Compression automatique si > 2MB (déjà fait dans TEMPS 2)

3. Stocker les images dans `Message` avec métadonnées :
   - Format original
   - Taille avant/après compression
   - Base64 ready pour l'API (image compressée)

**Validation** : Les images compressées peuvent être converties en base64

---

## 📝 ÉTAPE 6 : Tests complets
**Objectif** : Vérifier que tout fonctionne de bout en bout

### Scénarios de test :
1. ✅ Coller une image depuis Preview (Cmd+C puis Cmd+V)
2. ✅ Coller une image depuis Safari (screenshot)
3. ✅ Coller une image très grande (> 10MB) - doit être acceptée et compressée
4. ✅ Coller plusieurs images successivement
5. ✅ Retirer une image avant envoi (bouton X)
6. ✅ Envoyer un message avec image + texte
7. ✅ Envoyer un message avec seulement des images
8. ✅ Voir les images dans l'historique
9. ✅ Cliquer sur une image pour voir en taille réelle
10. ✅ Conversion base64 fonctionne avec image compressée
11. ✅ Pas d'erreur macOS (bruit)
12. ✅ Vérifier que l'image compressée est bien celle envoyée à l'API

**Validation** : Tous les scénarios fonctionnent sans erreur

**📋 Guide de test détaillé** : Voir `GUIDE-TESTS-IMAGES.md` pour une checklist complète avec étapes détaillées et critères de validation.

---

## 🎯 Ordre d'implémentation recommandé
1. **TEMPS 1** (Accepter toutes images) - 20 min
2. **TEMPS 2** (Compression après upload) - 30 min
3. **TEMPS 3** (Stocker et envoyer compressée) - 20 min

**Total estimé** : ~1h10

---

## 🔧 Fichiers à modifier

### TEMPS 1 :
- `Correcteur Pro/Utilities/ClipboardHelper.swift` : Supprimer validations taille
- `Correcteur Pro/Views/TextEditorWithImagePaste.swift` : Accepter toutes images
- `Correcteur Pro/Views/ChatView.swift` : Supprimer vérifications taille

### TEMPS 2 :
- `Correcteur Pro/Views/ChatView.swift` : Compression dans `handleImagePasteResult`
- `Correcteur Pro/Utilities/NSImage+Compression.swift` : Améliorer logs

### TEMPS 3 :
- `Correcteur Pro/ViewModels/ChatViewModel.swift` : Utiliser images déjà compressées
- `Correcteur Pro/Models/Message.swift` : Vérifier stockage ImageData

---

## 📚 Ressources
- [NSPasteboard Documentation](https://developer.apple.com/documentation/appkit/nspasteboard)
- [NSViewRepresentable pour TextEditor](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)
- [OpenAI Vision API Format](https://platform.openai.com/docs/guides/vision)
