# 🧪 Tests et Scripts de développement

Ce dossier contient tous les scripts de test et utilitaires pour le développement de l'application.

## 📁 Structure

```
tests/
├── README.md              # Ce fichier
├── test_api.sh           # Script de test avec clé API (copie dans presse-papiers)
├── test_env_api.sh       # Script de test utilisant le fichier .env
└── ...
```

## 🚀 Scripts disponibles

### `test_api.sh`
Script qui copie la clé API dans le presse-papiers pour faciliter la configuration.

**Utilisation** :
```bash
./tests/test_api.sh
```

**Fonctionnalités** :
- Copie la clé API dans le presse-papiers macOS
- Sauvegarde temporairement dans `/tmp/correcteur_api_key.txt`
- Affiche des instructions pour configurer l'application

---

### `test_env_api.sh`
Script de test complet de l'API OpenAI en utilisant le fichier `.env`.

**Prérequis** :
- Fichier `.env` à la racine du projet avec `OPENAI_API_KEY=sk-...`

**Utilisation** :
```bash
./tests/test_env_api.sh
```

**Tests effectués** :
1. ✅ Test de connexion à l'API (GET /v1/models)
2. ✅ Test d'envoi de message simple (POST /v1/chat/completions)
3. ✅ Extraction et affichage de la réponse
4. ✅ Affichage du nombre de tokens utilisés

**Exemple de sortie** :
```
🧪 Test API OpenAI depuis .env
================================

✅ Clé API trouvée dans .env

📡 TEST 1 : Test de connexion à l'API...
─────────────────────────────────────────
✅ Connexion réussie ! (HTTP 200)

📝 TEST 2 : Envoi d'un message simple...
─────────────────────────────────────────
✅ Message envoyé avec succès ! (HTTP 200)

💬 Réponse:
Bonjour ! Comment puis-je vous aider aujourd'hui ?

📊 Tokens utilisés: 32

✅ ===== TESTS TERMINÉS =====
```

---

## 🔧 Dépendances

### Optionnel mais recommandé
- `jq` : Pour une meilleure extraction JSON des réponses
  ```bash
  brew install jq
  ```

### Requis
- `curl` : Pour les appels HTTP (installé par défaut sur macOS)
- `bash` : Pour exécuter les scripts (installé par défaut sur macOS)

---

## 📝 Notes

- Les scripts utilisent le fichier `.env` à la racine du projet
- Le fichier `.env` est dans `.gitignore` et ne sera jamais commité
- Les scripts sont exécutables (`chmod +x`)
- Tous les tests sont non-destructifs (lecture seule de l'API)

---

## 🐛 Dépannage

### Erreur : "Fichier .env non trouvé"
- Vérifiez que le fichier `.env` existe à la racine du projet
- Vérifiez que `OPENAI_API_KEY=sk-...` est défini dans `.env`

### Erreur : "Clé API non trouvée"
- Vérifiez le format : `OPENAI_API_KEY=sk-...` (sans espaces autour du `=`)
- Vérifiez que la clé commence bien par `sk-`

### Erreur HTTP 401
- La clé API est invalide ou expirée
- Vérifiez votre clé sur [platform.openai.com](https://platform.openai.com/api-keys)

### Erreur HTTP 429
- Limite de requêtes atteinte
- Attendez quelques minutes avant de réessayer

---

## 🔒 Sécurité

⚠️ **IMPORTANT** :
- Ne commitez **jamais** le fichier `.env` avec une vraie clé API
- Le fichier `.env` est dans `.gitignore`
- Les scripts masquent automatiquement la clé dans les logs
- Pour la production, utilisez Keychain (via l'application)

---

*Dernière mise à jour : Décembre 2024*

