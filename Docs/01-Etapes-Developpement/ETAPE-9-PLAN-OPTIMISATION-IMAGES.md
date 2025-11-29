# ÉTAPE 9 : Plan d'optimisation compression images

**Date** : 29 novembre 2024
**Objectif** : Réduire drastiquement la taille des images envoyées à l'API tout en maintenant la lisibilité du texte

---

## 📋 Analyse de l'existant

### Code actuel : [NSImage+Compression.swift](../../Correcteur%20Pro/Utilities/NSImage+Compression.swift)

**Paramètres actuels** :
- **Résolution max** : 2048px (dimension max)
- **Qualité JPEG** : 0.8 → 0.6 → 0.4 → 0.3 → 0.2 (progressive)
- **Taille max selon préférences** :
  - None: 20 MB
  - Low: 5 MB
  - Medium: 3 MB
  - High: 2 MB

### Problèmes identifiés

1. **Résolution excessive pour captures d'écran texte**
   - 2048px est trop pour lire du texte
   - Une capture 1920x1080 à 2048px = ~4 MP
   - Économie possible : **50-75%** avec 1024-1280px

2. **Qualité JPEG trop élevée**
   - Qualité 0.8 conserve beaucoup de détails inutiles pour du texte
   - Qualité 0.5-0.6 suffit largement pour la lisibilité
   - Économie possible : **30-50%**

3. **Pas de différenciation contenu**
   - Photo avec détails ≠ Capture d'écran avec texte
   - Devrait adapter la compression selon le type

4. **Tailles max trop généreuses**
   - 2-5 MB pour du texte est excessif
   - **0.5-1 MB suffit** pour 90% des cas

---

## 🎯 Objectifs

### Objectif principal
**Réduire la taille moyenne des captures d'écran de 70-80%** tout en maintenant une lisibilité parfaite du texte.

### Objectifs mesurables

| Métrique | Actuel | Cible | Amélioration |
|----------|--------|-------|--------------|
| Résolution moyenne | 2048px | 1024px | -50% pixels |
| Qualité JPEG | 0.6-0.8 | 0.4-0.5 | -30% |
| Taille moyenne (High) | 1.5-2 MB | 0.4-0.6 MB | -70% |
| Taille moyenne (Medium) | 2-3 MB | 0.6-0.8 MB | -70% |

### Résultats attendus

**Économies sur 100 requêtes/mois** :
- Avant : ~200 MB de données
- Après : ~50 MB de données
- **Économie : 150 MB/mois** → Moins de coûts API, réponses plus rapides

---

## 🔧 Plan d'implémentation

### Phase 1 : Détection intelligente du contenu (2-3h)

**Objectif** : Détecter si l'image est principalement du texte ou une photo

**Méthode** : Analyse basique de l'image
```swift
enum ImageContentType {
    case text        // Capture d'écran avec texte (compress agressif)
    case photo       // Photo avec détails (compress modéré)
    case mixed       // Mixte (compress modéré)
    case unknown     // Inconnu (compress conservatif)
}

func detectContentType() -> ImageContentType {
    // Analyser :
    // 1. Ratio contraste (texte = contraste élevé)
    // 2. Complexité couleurs (texte = peu de couleurs)
    // 3. Zones uniformes (texte = beaucoup de zones blanches/unies)
}
```

**Heuristiques simples** :
- Capture d'écran macOS → `text` (détectable via métadonnées)
- < 50 couleurs uniques → `text`
- > 70% pixels clairs/foncés → `text`
- Sinon → `photo`

---

### Phase 2 : Profils de compression optimisés (1-2h)

**Objectif** : Créer des profils adaptés à chaque type de contenu

```swift
struct CompressionProfile {
    let maxDimension: CGFloat
    let jpegQuality: CGFloat
    let maxSizeMB: Double
    let name: String
}

extension ImageContentType {
    func compressionProfile(quality: CompressionQuality) -> CompressionProfile {
        switch (self, quality) {
        case (.text, .high):
            return CompressionProfile(
                maxDimension: 1024,    // Réduit de 2048 → 1024
                jpegQuality: 0.4,      // Réduit de 0.7 → 0.4
                maxSizeMB: 0.5,        // Réduit de 2.0 → 0.5
                name: "Text-High"
            )
        case (.text, .medium):
            return CompressionProfile(
                maxDimension: 1280,
                jpegQuality: 0.5,
                maxSizeMB: 0.8,
                name: "Text-Medium"
            )
        case (.photo, .high):
            return CompressionProfile(
                maxDimension: 1600,    // Photos besoin plus détails
                jpegQuality: 0.6,
                maxSizeMB: 1.5,
                name: "Photo-High"
            )
        // ... autres cas
        }
    }
}
```

**Profils détaillés** :

| Type | Qualité | Résolution | JPEG Quality | Max Size |
|------|---------|------------|--------------|----------|
| Text | High | 1024px | 0.4 | 0.5 MB |
| Text | Medium | 1280px | 0.5 | 0.8 MB |
| Text | Low | 1600px | 0.6 | 1.5 MB |
| Text | None | 2048px | 0.7 | 5.0 MB |
| Photo | High | 1600px | 0.6 | 1.5 MB |
| Photo | Medium | 1920px | 0.7 | 2.5 MB |
| Photo | Low | 2048px | 0.8 | 4.0 MB |
| Photo | None | Original | 0.9 | 10.0 MB |

---

### Phase 3 : Implémentation (3-4h)

**Fichiers à modifier** :

1. **NSImage+Compression.swift**
   - Ajouter `detectContentType()`
   - Ajouter struct `CompressionProfile`
   - Modifier `compressToMaxSize()` pour utiliser les profils

2. **Nouvelle méthode principale** :
   ```swift
   func compressOptimized(userQuality: CompressionQuality) -> NSImage? {
       // 1. Détecter le type de contenu
       let contentType = detectContentType()

       // 2. Choisir le profil approprié
       let profile = contentType.compressionProfile(quality: userQuality)

       // 3. Appliquer la compression
       return compress(using: profile)
   }
   ```

3. **Migration progressive** :
   - Garder l'ancien code en fallback
   - Ajouter flag `useOptimizedCompression` dans préférences
   - Logger les résultats pour comparer

---

### Phase 4 : Tests et validation (2-3h)

**Tests à effectuer** :

1. **Captures d'écran texte** :
   - Code source (monospace)
   - Document Word
   - PDF texte
   - Site web
   - Terminal

2. **Photos** :
   - Photos haute résolution
   - Graphiques complexes
   - Diagrammes

3. **Mixte** :
   - Slides de présentation
   - Interface app avec icônes

**Métriques à mesurer** :

| Scénario | Avant (MB) | Après (MB) | Économie | Lisibilité |
|----------|-----------|-----------|----------|------------|
| Code 1920x1080 | 2.0 | 0.4 | -80% | ✅ Parfaite |
| Document Word | 1.8 | 0.5 | -72% | ✅ Parfaite |
| PDF texte | 2.2 | 0.6 | -73% | ✅ Parfaite |
| Photo 4K | 3.5 | 1.5 | -57% | ✅ Bonne |
| Slide présentation | 2.5 | 0.8 | -68% | ✅ Bonne |

**Critères de validation** :
- ✅ Texte 12pt lisible à 100%
- ✅ Texte 10pt lisible à 100%
- ✅ Texte 8pt lisible à 90%+
- ✅ Pas d'artefacts visibles sur texte
- ✅ Réduction taille moyenne > 60%

---

### Phase 5 : Documentation (1h)

1. Créer **ETAPE-9-VALIDATION-OPTIMISATION-IMAGES.md**
2. Documenter les résultats des tests
3. Mettre à jour ARCHITECTURE.md
4. Ajouter exemples dans README

---

## 📊 Estimation

### Temps total : **8-12 heures**

| Phase | Durée | Priorité |
|-------|-------|----------|
| Phase 1 - Détection contenu | 2-3h | Haute |
| Phase 2 - Profils compression | 1-2h | Haute |
| Phase 3 - Implémentation | 3-4h | Haute |
| Phase 4 - Tests | 2-3h | Moyenne |
| Phase 5 - Documentation | 1h | Basse |

---

## 🎯 Résultats attendus

### Avant optimisation

**Capture écran 1920x1080 avec texte** :
- Résolution finale : 2048x1152
- Qualité JPEG : 0.7
- **Taille : ~2.0 MB**
- Tokens estimés : ~800 tokens

### Après optimisation

**Même capture** :
- Résolution finale : 1024x576 (détection texte)
- Qualité JPEG : 0.4
- **Taille : ~0.4 MB**
- Tokens estimés : ~200 tokens

**Économies** :
- **-80% taille fichier**
- **-75% tokens utilisés**
- **-75% coût API pour les images**
- **Réponses 2-3x plus rapides**

---

## 🔄 Migration

### Option 1 : Activation progressive (recommandé)

Ajouter préférence :
```swift
struct AppPreferences {
    // ...
    var useOptimizedCompression: Bool = true
}
```

Dans code :
```swift
if PreferencesManager.shared.preferences.useOptimizedCompression {
    return image.compressOptimized(userQuality: quality)
} else {
    return image.compressToMaxSize(maxSizeMB: maxSize)
}
```

### Option 2 : Remplacement direct

Remplacer directement `compressToMaxSize()` par `compressOptimized()`.

**Recommandation** : Option 1 pour pouvoir revenir en arrière si problème.

---

## 📝 Notes importantes

1. **Lisibilité avant tout** : Toujours privilégier la lisibilité du texte sur la compression
2. **Tests réels** : Tester avec vraies captures d'écran utilisateur
3. **Monitoring** : Logger les tailles avant/après pour analyser les gains
4. **Fallback** : Garder l'ancien système en backup

---

## 🚀 Prochaines étapes après optimisation

1. **Monitoring** : Analyser les gains réels sur 1-2 semaines
2. **Fine-tuning** : Ajuster les profils selon retours
3. **Cache** : Implémenter cache pour images déjà compressées
4. **OCR (futur)** : Extraire texte avant compression pour validation

---

**Status** : ⏳ EN ATTENTE DE VALIDATION
**Créé le** : 29 novembre 2024
