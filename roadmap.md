# 🗺️ Roadmap - Correcteur Pro

## 📋 Vue d'ensemble

Ce document présente la vision à long terme de l'application Correcteur Pro, incluant les fonctionnalités actuelles et les améliorations futures envisagées.

---

## ✅ Fonctionnalités actuelles (implémentées)

### Interface utilisateur
- ✅ Interface utilisateur complète (sidebar, chat, header)
- ✅ Interface optimisée sans coins arrondis
- ✅ Raccourcis clavier (Enter = envoyer, Shift+Enter = nouvelle ligne)
- ✅ **Panneau de préférences natif macOS (Cmd+,)** avec 4 onglets
- ✅ **Effet verre dépoli** : Transparence subtile avec flou natif macOS (opacity 0.80)
- ✅ **Éditeur de prompt responsive** : Mode colonne (écran large) et inline (mode compact)

### Gestion des conversations
- ✅ Gestion des conversations multiples avec persistance
- ✅ Historique conversationnel (20 derniers messages configurables)
- ✅ Sélection de prompts système (Correcteur, Assistant, Traducteur, Personnalisé)

### Prompts personnalisés
- ✅ Création de prompts personnalisés illimités
- ✅ Archivage de prompts (avec bouton dédié)
- ✅ Restauration depuis les préférences
- ✅ Suppression automatique après 90 jours d'archivage
- ✅ Prompt correcteur anti-faux positifs (few-shot learning)

### Images et capture d'écran
- ✅ Support du copier-coller d'images avec compression automatique
- ✅ **Capture écran principal** : Raccourci global Option+Shift+S
- ✅ **Capture zone sélectionnée** : Raccourci global Option+Shift+X avec overlay interactif
- ✅ **Compression intelligente avec détection de contenu** (ÉTAPES 9-11)
  - Détection automatique : texte, photo, mixte, inconnu
  - 16 profils de compression optimisés
  - Réduction 70-80% pour texte, 40-60% pour photos
  - Validation qualité OCR optionnelle (Vision Framework)
- ✅ Compression configurable (None/Low/Medium/High)
- ✅ Format configurable (JPEG/PNG)
- ✅ Son notification après capture

### API OpenAI
- ✅ Configuration de la clé API OpenAI (Keychain sécurisé)
- ✅ Intégration API OpenAI (Chat Completions + Vision API)
- ✅ Modèle configurable (GPT-4o / GPT-4 Turbo / GPT-3.5 Turbo)
- ✅ MaxTokens configurable (1000-16000)
- ✅ Affichage coût estimé en euros

### Raccourcis clavier globaux
- ✅ Raccourcis configurables et personnalisables
- ✅ Réenregistrement dynamique sans redémarrage
- ✅ Support complet A-Z avec modificateurs (⌃⌥⇧⌘)

### Documentation et architecture
- ✅ Documentation complète organisée dans `/Docs`
- ✅ Architecture MVVM documentée
- ✅ Historique complet des étapes de développement
- ✅ Code nettoyé sans warnings

---

## 🚀 Déploiement vers /Applications

### Pourquoi c'est nécessaire ?
Quand tu lances l'app via **Spotlight** (Cmd+Espace), macOS lance l'app située dans `/Applications/`.
Si tu ne mets pas à jour ce fichier, tu lanceras l'ancienne version.

### Comment mettre à jour l'app dans /Applications ?

**Option 1 : Commande manuelle (Terminal)**
```bash
# Fermer l'app si elle tourne
pkill -f "Correcteur Pro"

# Supprimer l'ancienne version
rm -rf "/Applications/Correcteur Pro.app"

# Copier la nouvelle version depuis Xcode DerivedData
cp -R ~/Library/Developer/Xcode/DerivedData/Correcteur_Pro-*/Build/Products/Debug/Correcteur\ Pro.app /Applications/

# Lancer l'app
open "/Applications/Correcteur Pro.app"
```

**Option 2 : Script automatisé**
Le fichier `deploy.sh` à la racine du projet fait ça automatiquement :
```bash
./deploy.sh
```

**Option 3 : Via Claude Code**
Demande simplement : "déploie l'app dans /Applications" ou "mets à jour l'app"

### Vérifier la version
Pour vérifier que tu as bien la dernière version, regarde la date de modification :
```bash
ls -la "/Applications/Correcteur Pro.app"
```

---

## 🚀 Fonctionnalités en cours de développement
- ✅ ~~Debugging prise de photo~~ → Corrigé (raccourcis ⌥⇧S et ⌥⇧X fonctionnels)

## 🕚 Fonctionnalités à implémenter

### Fonctionnalité archiver les chats
- Ce que j'aimerais ajouter c'est que quand tu quand je clique sur le bouton dupliquer, que c'est un nouveau chat, que dans cet nouveau chat qui a été dupliqué, on puisse directement déjà été préalablement copié-collé. Que j'ai plus qu'à le modifier. 



### Fonctionnalité copier-coller le texte en plus
- Mon objetctif est toujours de voir les erreurs dans mes textes rapidement pour pouvoir comprendre mes erreurs (grace aux mots rayés et aux mots en gras)
- Néanmoins je veux gagner du temps quand je modifie le fichier d'origne et je ne veux plus qu'à avoir à copier coller
- il faut que je puisse copier-coller dans le chatbot de ce qui m'est renvoyé. A chaque fois il faut qu'on ajoute une fonctionnalité pour copier le message qui a été renvoyé (genre en bas à droite de la réponse). Quand je copie le message qui a été envoyé, je veux bien que juste il y ait une petite étape supplémentaire qui va être l'adaptation au presse-papier. 
- Je souhaite que à chaque fois que je fasse copier passer dans un dans une petite moulinette, dans un petit... un truc pour modifier le texte. Et que le texte qu'on me renvoie..., on le modifie pour enlever les croix rouges ou les cases à cocher vertes. et que ça supprime les retours à la ligne. Parce que. il est probable que si au cours de l'OCR on avait bien reconnu des retours à la ligne, il est probable que ces retours à la ligne étaient É..taient. en quelque sorte automatiques. C'est juste parce qu'il n'y avait plus plus de place. Et donc l'objectif c'est que quand je colle, bah du coup il n'y ait pas ces retours à la ligne pour que ça se colle proprement et qu'il n'y ait pas la croix rouge devant, af Ainfin que. que.. j'ai pas besoin de la supprimer moi-même à la main. 

Ça veut dire qu'il faut que tu changes dans ce cas-là le la réponse qui est attendue de l'application. Ça veut dire que..., quand tu fais ton call, pardon, API, je veux que dans ton call. tu demandes à la fois du coup, bah cette version, là, la version corrigée avec la croix rouge et tout, et la version, dans un JSON, la version... propre prête à copier-coller. Et dans cette version propre prête à copier-coller, il faut que... donc il faut un JSON quand tu envoies... T'es demandé à l'API qui demande les deux trucs. A la fois the version of text avec les corrections, and at the fois the version corrigée, prête à copier-coller, sans explication. de ce qui a été modifié. 



### Fonctionnalité hors ligne
- J'aimerais qu'on réfléchisse ensemble à comment faire en sorte que cette application est également un mode hors ligne. 
-Déjà, je pense que dans les settings, il faut créer un mode qui puisse s'appeler mode hors ligne.
- Après, je pense qu'il faut qu'on réfléchisse à un système d'agents. 
- C'est-à-dire que tu me crées plusieurs processus pour ça. Et en gros, quand je me mets en mode hors ligne, ça appliquera toujours le correcteur hors ligne. 
- Ça devrait pas être du coup juste le mode hors ligne, mais le mode correcteur hors ligne. 
- Etape 1 Dans ce mode correcteur hors ligne, je veux d'abord qu'il y ait un premier agent pour compresser un petit peu les photos. Il ne faut pas qu'elles soient trop compressées, je pense qu'il faut qu'elles soient un tout petit peu compressées. 
- Etape 2, je pense qu'une fois que l'image on l'a et qu'elle est un peu compressée, il faut faire de l'OCR, donc de la reconnaissance de texte, pour faire en sorte que. qui s'affiche à l'écran. Et je veux que. dans la partie OCR, on ait les retours à la ligne. Dès que dans l'image on voit qu'il y a un retour à la ligne, et bah je veux que la partie OCR le détecte. 
- Etape 3, Je souhaite que l'on fasse les corrections avec un des meilleurs modèles d'intelligence artificielle orient horsale ligne. Je ne sais pas quels sont les modèles, mais peut-être que je puisse potentiellement après choisir le modèle, mais ça ce sera plus tard dans la roadmap. Je choisis moi juste pour l'instant un modèle qui est connu pour être bon en hors ligne.  Je sais pas s'il faut pas utiliser llm-lite on un truc comme ça pour pouvoir changer facilement de modèle par la suite. 
- étape 4 je veux que ce modèle du coup il corrige les fautes comme on l'avait fait dans le prompt système et peut-être que vu que c'est un modèle hors ligne là c'est bien de fournir un json avancé pour que ça corrige bien toujours comme je veux 
- Etape 5 Il faut que du coup le modèle hors ligne renvoie le message corrigé, bien comme je l'attends. 
- Étape 6, 


### Fonctionnalité thème clair
- Changer l'interface pour que la version claire ressemble à quelque chose
- Améliorer le contraste et la lisibilité en mode clair
- Respecter le design system macOS

### Toggle validation OCR dans préférences
- Ajouter option "Valider qualité texte" dans Préférences → Capture
- Permet d'activer la validation OCR automatique (ÉTAPE 10)
- Off par défaut pour préserver performance

### Statistiques compression dans UI
- Afficher taille avant/après compression
- Afficher pourcentage d'économie
- Compteur total MB économisés depuis début

### Recherche dans conversations
- Barre de recherche dans sidebar
- Filtrage en temps réel des conversations
- Highlight des résultats

### Refactorer le code pour qu'un designer puisse facilement modifier l'interface utilisateur


---

## 🐛 Bugs connus à corriger
- ✅ ~~Aperçu d'image bloquant~~ → Corrigé avec overlay ZStack (commit 1e57590)


## 🔮 Fonctionnalités futures - Agents OpenAI
### 📌 Pourquoi les agents ne sont pas nécessaires maintenant

**Situation actuelle :**
- Le workflow est simple : `Image + Prompt → GPT-4o Vision → Réponse formatée`
- Une seule requête API suffit
- Le prompt de correction fonctionne bien tel quel
- Pas de logique conditionnelle complexe

**Conclusion :** L'API basique (Chat Completions) est parfaitement adaptée pour l'instant.

---

### 🎯 Cas d'usage futurs où les agents prendront leur sens

#### 1. Détection automatique du type de contenu

**Objectif :** Détecter automatiquement le type de document analysé et adapter le traitement.

**Workflow avec Agent :**
```
1. L'utilisateur upload une image/document
   ↓
2. Agent : Analyser le contenu pour détecter le type
   - Document juridique (contrat, acte, jugement)
   - Document académique (dissertation, mémoire)
   - Document technique (manuel, spécification)
   - Document commercial (devis, facture)
   - Document administratif (formulaire, courrier)
   ↓
3. Agent : Choisir le prompt système approprié
   - Si juridique → prompt spécialisé droit
   - Si académique → prompt spécialisé académique
   - Si technique → prompt spécialisé technique
   ↓
4. Agent : Appliquer les règles spécifiques au type
   - Correction orthographique adaptée au domaine
   - Vérification de la terminologie spécialisée
   - Respect des conventions du type de document
```

**Bénéfices :**
- Correction plus précise selon le contexte
- Respect des conventions par domaine
- Meilleure qualité de sortie

---

#### 2. Référencement à des bases de données spécialisées

**Objectif :** Utiliser des bases de données de bonnes/mauvaises pratiques pour améliorer les corrections.

**Exemple concret : Droit du travail**

**Workflow avec Agent :**
```
1. L'utilisateur upload un document de droit du travail
   ↓
2. Agent : Détecter que c'est un document juridique (droit du travail)
   ↓
3. Agent : Interroger la base de données spécialisée
   - Base de données de clauses types (bonnes pratiques)
   - Base de données de clauses à éviter (mauvaises pratiques)
   - Base de données de jurisprudence récente
   ↓
4. Agent : Comparer le document avec les références
   - Identifier les clauses conformes aux bonnes pratiques
   - Identifier les clauses problématiques
   - Suggérer des améliorations basées sur la jurisprudence
   ↓
5. Agent : Générer un rapport de correction enrichi
   - Corrections orthographiques classiques
   - Suggestions d'amélioration basées sur la base de données
   - Alertes sur les clauses à risque
```

**Structure de la base de données :**
```json
{
  "domaine": "droit_du_travail",
  "bonnes_pratiques": [
    {
      "type": "clause",
      "contenu": "La clause de non-concurrence doit préciser...",
      "reference": "Article L. 1121-1 du Code du travail"
    }
  ],
  "mauvaises_pratiques": [
    {
      "type": "clause",
      "contenu": "Clause de non-concurrence sans limitation géographique",
      "risque": "Nullité de la clause",
      "reference": "Cass. soc. 10 juillet 2019"
    }
  ]
}
```

**Bénéfices :**
- Corrections enrichies par l'expertise métier
- Détection de clauses problématiques
- Suggestions basées sur la jurisprudence
- Amélioration continue via la base de données

---

#### 3. Analyse contextuelle multi-étapes

**Objectif :** Analyser un document en plusieurs passes pour une correction plus approfondie.

**Workflow avec Agent :**
```
1. L'utilisateur upload un document complexe
   ↓
2. Agent - Étape 1 : Analyse structurelle
   - Identifier les sections (introduction, développement, conclusion)
   - Détecter les incohérences structurelles
   ↓
3. Agent - Étape 2 : Analyse orthographique
   - Corriger les fautes d'orthographe
   - Vérifier la grammaire
   ↓
4. Agent - Étape 3 : Analyse stylistique
   - Vérifier la cohérence du style
   - Suggérer des améliorations de formulation
   ↓
5. Agent - Étape 4 : Analyse sémantique
   - Vérifier la cohérence du contenu
   - Détecter les contradictions
   ↓
6. Agent - Étape 5 : Génération du rapport final
   - Combiner toutes les analyses
   - Prioriser les corrections
   - Générer un document corrigé complet
```

**Bénéfices :**
- Correction multi-niveaux (orthographe, style, sens)
- Analyse plus approfondie
- Rapport détaillé avec priorités

---

## ❓ Questions techniques

### Est-ce possible d'intégrer une base de données avec un agent ?

**Réponse : OUI, c'est exactement l'un des cas d'usage principaux des agents !**

**Comment ça fonctionne :**

1. **Base de données locale (recommandé pour commencer) :**
   - Stocker les bases de données en JSON/SQLite dans l'app
   - L'agent peut interroger la base via des fonctions/tools
   - Avantages : Rapide, pas de dépendance externe, données privées

2. **Base de données externe (pour plus tard) :**
   - API REST pour interroger une base distante
   - L'agent appelle l'API via des tools
   - Avantages : Mise à jour centralisée, partage entre utilisateurs

3. **Vector Database (pour recherche sémantique) :**
   - Stocker les références dans une base vectorielle (Pinecone, Weaviate)
   - L'agent peut faire des recherches sémantiques
   - Avantages : Recherche par similarité, meilleure pertinence

**Exemple d'intégration :**
```swift
// L'agent peut appeler une fonction pour interroger la base
func queryLegalDatabase(domain: String, query: String) -> [Reference] {
    // Interroger la base de données locale
    // Retourner les références pertinentes
}

// L'agent utilise cette fonction via un "tool"
{
  "type": "function",
  "function": {
    "name": "queryLegalDatabase",
    "description": "Interroge la base de données juridique pour trouver des références",
    "parameters": {
      "domain": "droit_du_travail",
      "query": "clause de non-concurrence"
    }
  }
}
```

---

## 📅 Plan d'implémentation suggéré

### Phase 1 : API basique (✅ COMPLÉTÉE)
- ✅ Configuration clé API
- ✅ Intégration Chat Completions
- ✅ Support Vision API
- ✅ Panneau de préférences complet
- ✅ Capture d'écran avec zone sélectionnée

### Phase 2 : Améliorations UX (🔄 EN PARTIE)
- ✅ Persistance des conversations
- ⏳ Recherche dans les conversations
- ⏳ Export des corrections
- ⏳ Implémentation thème clair
- ⏳ Implémentation préférences Interface complètes

### Phase 3 : Détection de type de contenu (sans agent)
- Analyse simple du contenu pour suggérer un prompt
- Menu de sélection de domaine (juridique, académique, etc.)
- Prompts spécialisés par domaine
- **Durée estimée :** 1 semaine

### Phase 4 : Bases de données locales (sans agent)
- Création de bases de données JSON pour chaque domaine
- Recherche simple dans les bases
- Affichage des références dans les corrections
- **Durée estimée :** 2-3 semaines

### Phase 5 : Migration vers Agent Builder (futur)
- Création d'un workflow agent pour détection automatique
- Intégration des bases de données comme tools
- Workflow multi-étapes pour analyse approfondie
- **Durée estimée :** 3-4 semaines

---

## 🎯 Priorités

### Court terme (1-2 mois)
1. ✅ ~~Finaliser l'intégration API basique~~ (COMPLÉTÉ)
2. Optimisation compression images (réduction taille minimale)
3. Implémentation thème clair
4. Recherche dans les conversations
5. Export des corrections

### Moyen terme (3-6 mois)
1. Créer des bases de données de références
2. Implémenter la détection de type de contenu
3. Intégrer les bases de données dans les corrections

### Long terme (6+ mois)
1. Migrer vers Agent Builder pour workflows complexes
2. Ajouter des bases de données vectorielles
3. Implémenter l'analyse multi-étapes

---

## 📚 Ressources

- [OpenAI Agent Builder Documentation](https://platform.openai.com/docs/guides/agent-builder)
- [OpenAI Function Calling](https://platform.openai.com/docs/guides/function-calling)
- [OpenAI Assistants API](https://platform.openai.com/docs/assistants/overview)

---

## 💡 Notes importantes

1. **Les agents ne sont pas nécessaires maintenant** : L'API basique suffit largement pour les besoins actuels.

2. **Migration progressive** : On peut commencer avec des bases de données simples (JSON) et migrer vers des agents plus tard.

3. **Valeur ajoutée des agents** : Les agents apportent de la valeur quand il y a :
   - Décisions conditionnelles complexes
   - Intégration d'outils externes
   - Workflows multi-étapes avec dépendances

4. **Coût** : Les agents peuvent être plus coûteux (plus de tokens, plus d'appels API). À utiliser quand la valeur ajoutée justifie le coût.

---

---

## 📊 État du projet

**Version actuelle** : 1.1 (prompts & transparence)
**Statut** : ✅ Production Ready
**Dernière mise à jour** : 30 novembre 2024

### Nouveautés v1.1
- Système d'archivage des prompts personnalisés (90 jours)
- Effet verre dépoli avec transparence
- Prompt correcteur amélioré (anti-faux positifs)
- Éditeur de prompt responsive
- **Capture d'écran via raccourcis clavier** (⌥⇧S et ⌥⇧X) - corrigé et fonctionnel

### Métriques
- **~40 fichiers Swift**
- **~4200 lignes de code**
- **0 warnings de compilation**
- **0 bugs connus**
- **100%** des fonctionnalités de base implémentées

### Prochaine version prévue : 1.2
**Objectifs** :
- Bouton copier texte corrigé
- Thème clair
- Recherche dans conversations

---

*Dernière mise à jour de la roadmap : 30 novembre 2024*

