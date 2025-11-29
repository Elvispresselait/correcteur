# 📄 Configuration avec fichier .env

Ce projet supporte le chargement de la clé API depuis un fichier `.env` pour faciliter le développement et le debug.

## 🚀 Utilisation

### 1. Créer le fichier .env

Copiez le fichier `.env.example` en `.env` à la racine du projet :

```bash
cp .env.example .env
```

### 2. Ajouter votre clé API

Ouvrez le fichier `.env` et ajoutez votre clé API :

```env
OPENAI_API_KEY=sk-proj-VOTRE_CLE_API_ICI
```

### 3. Utilisation automatique

L'application charge automatiquement la clé depuis `.env` en **priorité**, puis utilise Keychain si le fichier `.env` n'existe pas.

**Ordre de priorité :**
1. ✅ Fichier `.env` (développement)
2. ✅ Keychain (production)

## 📍 Emplacements recherchés

Le fichier `.env` est recherché dans cet ordre :

1. Répertoire du projet (racine du workspace)
2. Répertoire de travail actuel
3. Répertoire home (`~/.env`)
4. Répertoire du bundle (pour les builds)

## 🔒 Sécurité

⚠️ **Important :**
- Le fichier `.env` est **ignoré par Git** (déjà dans `.gitignore`)
- Ne commitez **jamais** votre fichier `.env` avec votre clé API réelle
- Pour la production, utilisez Keychain (plus sécurisé)

## 🧪 Debug

Pour voir si le `.env` est chargé, regardez les logs au démarrage de l'application :

```
📄 [EnvLoader] Fichier .env trouvé: /path/to/.env
✅ [EnvLoader] OPENAI_API_KEY = sk-proj...heAA
✅ [EnvLoader] 1 variable(s) d'environnement chargée(s) depuis .env
```

## 🔄 Recharger le .env

Si vous modifiez le fichier `.env` pendant l'exécution, vous pouvez forcer le rechargement :

```swift
EnvLoader.clearCache()
```

## 📝 Format du fichier .env

Le fichier `.env` supporte :

- Variables simples : `KEY=value`
- Guillemets : `KEY="value"` ou `KEY='value'`
- Commentaires : `# Ceci est un commentaire`
- Lignes vides (ignorées)

Exemple :

```env
# Clé API OpenAI
OPENAI_API_KEY=sk-proj-abc123...

# Modèle à utiliser
OPENAI_MODEL=gpt-4o-mini

# Timeout en secondes
OPENAI_TIMEOUT=30
```

## 🐛 Dépannage

### Le .env n'est pas chargé

1. Vérifiez que le fichier `.env` existe à la racine du projet
2. Vérifiez les logs au démarrage pour voir les chemins recherchés
3. Vérifiez que le format est correct (`KEY=value`)

### La clé n'est pas trouvée

1. Vérifiez l'orthographe : `OPENAI_API_KEY` (en majuscules)
2. Vérifiez qu'il n'y a pas d'espaces autour du `=`
3. Vérifiez les logs pour voir quelle source est utilisée

### Fenêtre Keychain macOS apparaît

Si macOS vous demande l'accès au Keychain même avec un `.env` :

1. **Cause** : Une ancienne entrée existe dans le Keychain
2. **Solution rapide** : Exécutez le script de suppression :
   ```bash
   ./scripts/remove_keychain_entry.sh
   ```
3. **Solution manuelle** : Supprimez l'entrée Keychain manuellement :
   - Ouvrez "Accès au trousseau" (Keychain Access)
   - Cherchez `com.correcteurpro.apiKey` ou `openai_api_key`
   - Supprimez l'entrée
4. **Alternative** : Cliquez sur "Refuser" dans la fenêtre - l'application fonctionnera quand même avec `.env`

**Note** : Si vous utilisez uniquement `.env`, l'application n'accède **jamais** au Keychain. La fenêtre n'apparaîtra plus après suppression de l'ancienne entrée.

