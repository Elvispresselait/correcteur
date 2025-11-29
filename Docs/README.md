# 📚 Documentation - Correcteur Pro

Bienvenue dans la documentation complète de Correcteur Pro.

---

## 📂 Structure de la documentation

```
Docs/
├── 01-Etapes-Developpement/     # Historique complet du développement
│   ├── 0.1 ETAPES DE DEVELLOPEMENT.md
│   ├── ETAPE-1-*.md             # Setup initial du projet
│   ├── ETAPE-2-*.md             # Support images
│   ├── ETAPE-3-*.md             # Configuration API
│   ├── ETAPE-4-*.md             # Intégration API OpenAI
│   ├── ETAPE-5-*.md             # Historique conversationnel
│   ├── ETAPE-6-*.md             # Améliorations UI/UX
│   ├── ETAPE-7-*.md             # Capture d'écran
│   └── ETAPE-8-*.md             # Panneau de préférences
│
├── 02-Architecture/              # Documentation technique
│   ├── ARCHITECTURE.md           # Architecture complète du projet
│   └── CONTEXTE-ACTUEL.md        # État actuel du projet
│
└── 03-Guides/                    # Guides utilisateur
    ├── README-ENV.md             # Configuration fichier .env
    └── README-TESTS-API.md       # Tests API OpenAI
```

---

## 🎯 Par où commencer ?

### Pour comprendre le projet
1. **[ARCHITECTURE.md](02-Architecture/ARCHITECTURE.md)** - Vue d'ensemble technique complète
2. **[CONTEXTE-ACTUEL.md](02-Architecture/CONTEXTE-ACTUEL.md)** - État actuel du projet
3. **[roadmap.md](../roadmap.md)** - Vision à long terme

### Pour développer
1. **[Étapes de développement](01-Etapes-Developpement/)** - Historique complet
2. **[ARCHITECTURE.md](02-Architecture/ARCHITECTURE.md)** - Patterns et structure
3. **[README-ENV.md](03-Guides/README-ENV.md)** - Configuration environnement

### Pour tester
1. **[README-TESTS-API.md](03-Guides/README-TESTS-API.md)** - Tests API
2. **[ETAPE-4-VALIDATION.md](01-Etapes-Developpement/ETAPE-4-VALIDATION.md)** - Validation API

---

## 📖 Documents clés

### ARCHITECTURE.md
Document principal décrivant :
- Structure du projet (37 fichiers Swift)
- Pattern MVVM
- Flux de données
- Services clés
- Gestion des permissions
- Performance et sécurité

**👉 [Lire ARCHITECTURE.md](02-Architecture/ARCHITECTURE.md)**

---

### Étapes de développement

Historique complet du développement par étapes :

| Étape | Description | Fichiers |
|-------|-------------|----------|
| 1 | Setup initial | ETAPE-1-*.md |
| 2 | Support images | ETAPE-2-*.md |
| 3 | Configuration API | ETAPE-3-*.md |
| 4 | Intégration OpenAI | ETAPE-4-*.md |
| 5 | Historique conversationnel | ETAPE-5-*.md |
| 6 | Améliorations UI/UX | ETAPE-6-*.md |
| 7 | Capture d'écran | ETAPE-7-*.md |
| 8 | Panneau préférences | ETAPE-8-*.md |

**👉 [Voir toutes les étapes](01-Etapes-Developpement/)**

---

## 🔧 Technologies utilisées

- **Langage** : Swift
- **Framework UI** : SwiftUI
- **Architecture** : MVVM
- **Persistence** : UserDefaults + Keychain
- **API** : OpenAI (Chat Completions + Vision)
- **Capture d'écran** : ScreenCaptureKit (macOS 12.3+)
- **Raccourcis** : Carbon Events API

---

## 📊 Métriques du projet

- **37 fichiers Swift**
- **~3900 lignes de code**
- **0 warnings**
- **0 bugs connus**
- **Version** : 1.0 (Production Ready)

---

## 🚀 Fonctionnalités principales

### ✅ Implémentées (v1.0)

#### Interface
- Sidebar + Chat + Header
- Panneau préférences (Cmd+,)
- Interface sans coins arrondis

#### Conversations
- Conversations multiples avec persistance
- Historique 20 messages (configurable)
- Prompts système personnalisables

#### Images
- Copier-coller avec compression auto
- Capture écran principal (⌥⇧S)
- Capture zone sélectionnée (⌥⇧X)
- Compression configurable (4 niveaux)
- Format JPEG/PNG

#### API
- GPT-4o / GPT-4 Turbo / GPT-3.5 Turbo
- MaxTokens configurable
- Calcul coût en euros

#### Raccourcis
- Personnalisables sans redémarrage
- Support A-Z + modificateurs

### ⏳ À venir (v1.1)

- Optimisation compression images
- Thème clair
- Recherche dans conversations
- Export des corrections

---

## 🔗 Liens utiles

### Documentation OpenAI
- [Chat Completions API](https://platform.openai.com/docs/api-reference/chat)
- [Vision API](https://platform.openai.com/docs/guides/vision)
- [Pricing](https://openai.com/api/pricing/)

### Documentation Apple
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

---

## 📝 Changelog

### v1.0 - 29 novembre 2024
- ✅ Base complète stable
- ✅ Panneau préférences complet
- ✅ Capture zone sélectionnée
- ✅ Documentation complète
- ✅ Code nettoyé sans warnings

### v0.9 - Novembre 2024
- Capture écran principal
- Historique conversationnel
- API OpenAI fonctionnelle

### v0.5 - Novembre 2024
- Interface de base
- Conversations multiples
- Support images

---

## 💡 Contribution

Pour contribuer au projet :

1. Lire [ARCHITECTURE.md](02-Architecture/ARCHITECTURE.md)
2. Consulter la [roadmap](../roadmap.md)
3. Respecter le pattern MVVM
4. Documenter les nouvelles étapes dans `01-Etapes-Developpement/`

---

## 📧 Contact

Pour toute question sur la documentation :
- Consulter d'abord [ARCHITECTURE.md](02-Architecture/ARCHITECTURE.md)
- Vérifier les [étapes de développement](01-Etapes-Developpement/)
- Consulter la [roadmap](../roadmap.md)

---

*Documentation créée le 29 novembre 2024*
*Dernière mise à jour : 29 novembre 2024*
