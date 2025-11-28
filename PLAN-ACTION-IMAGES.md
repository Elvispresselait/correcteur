# 📋 Plan d'action : Support du copier-coller d'images

## 🔍 Problème identifié
- `onPasteCommand` sur `TextEditor` ne fonctionne pas correctement sur macOS
- Le TextEditor intercepte le paste et ne le propage pas au modifier
- Résultat : bruit d'erreur macOS + pas de visuel

## ✅ Solution proposée
Utiliser `NSPasteboard` directement avec un monitoring du clipboard ou un wrapper NSViewRepresentable pour avoir un contrôle total.

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
   - Image trop grande (afficher warning)

2. Feedback visuel :
   - Animation quand une image est ajoutée
   - Message temporaire "Image ajoutée" (toast)
   - Compteur d'images visible

3. Logs de debug :
   - Console logs pour diagnostiquer les problèmes
   - Afficher le type MIME détecté

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

2. Ajouter validation des images :
   - Taille max (4MB recommandé pour OpenAI)
   - Formats supportés (JPEG, PNG, GIF, WebP)
   - Compression automatique si trop grande

3. Stocker les images dans `Message` avec métadonnées :
   - Format original
   - Taille avant/après compression
   - Base64 ready pour l'API

**Validation** : Les images peuvent être converties en base64 sans perte de qualité excessive

---

## 📝 ÉTAPE 6 : Tests complets
**Objectif** : Vérifier que tout fonctionne de bout en bout

### Scénarios de test :
1. ✅ Coller une image depuis Preview (Cmd+C puis Cmd+V)
2. ✅ Coller une image depuis Safari (screenshot)
3. ✅ Coller plusieurs images successivement
4. ✅ Retirer une image avant envoi (bouton X)
5. ✅ Envoyer un message avec image + texte
6. ✅ Envoyer un message avec seulement des images
7. ✅ Voir les images dans l'historique
8. ✅ Cliquer sur une image pour voir en taille réelle
9. ✅ Conversion base64 fonctionne
10. ✅ Pas d'erreur macOS (bruit)

**Validation** : Tous les scénarios fonctionnent sans erreur

---

## 🎯 Ordre d'implémentation recommandé
1. **ÉTAPE 1** (Diagnostic) - 15 min
2. **ÉTAPE 2** (NSPasteboard) - 30 min
3. **ÉTAPE 4** (Erreurs/Feedback) - 20 min
4. **ÉTAPE 3** (Bouton alternatif) - 15 min
5. **ÉTAPE 5** (Base64) - 30 min
6. **ÉTAPE 6** (Tests) - 20 min

**Total estimé** : ~2h

---

## 🔧 Fichiers à modifier
- `ChatView.swift` : InputBarView et gestion du paste
- `Message.swift` : Déjà OK (support images)
- Nouveau fichier : `NSImage+Base64.swift` (extension pour conversion)

---

## 📚 Ressources
- [NSPasteboard Documentation](https://developer.apple.com/documentation/appkit/nspasteboard)
- [NSViewRepresentable pour TextEditor](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)
- [OpenAI Vision API Format](https://platform.openai.com/docs/guides/vision)

