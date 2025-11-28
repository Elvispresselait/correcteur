# 🗺️ Roadmap - Correcteur Pro

## 📋 Vue d'ensemble

Ce document présente la vision à long terme de l'application Correcteur Pro, incluant les fonctionnalités actuelles et les améliorations futures envisagées.

---

## ✅ Fonctionnalités actuelles (implémentées)

- ✅ Interface utilisateur complète (sidebar, chat, header)
- ✅ Support du copier-coller d'images avec compression automatique
- ✅ Configuration de la clé API OpenAI (Keychain)
- ✅ Sélection de prompts système (Correcteur, Assistant, Traducteur, Personnalisé)
- ✅ Gestion des conversations multiples

---

## 🚀 Fonctionnalités en cours de développement

- 🔄 Intégration API OpenAI (Chat Completions)
- 🔄 Support Vision API pour l'analyse d'images
- 🔄 Persistance des conversations

---

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

### Phase 1 : API basique (actuelle)
- ✅ Configuration clé API
- 🔄 Intégration Chat Completions
- 🔄 Support Vision API
- **Durée estimée :** 2-3 semaines

### Phase 2 : Améliorations UX
- Persistance des conversations
- Recherche dans les conversations
- Export des corrections
- **Durée estimée :** 1-2 semaines

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
1. Finaliser l'intégration API basique
2. Améliorer l'UX (persistance, recherche)
3. Ajouter des prompts spécialisés par domaine

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

*Dernière mise à jour : Décembre 2024*

