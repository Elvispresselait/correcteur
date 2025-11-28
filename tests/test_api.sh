#!/bin/bash

# Script de test rapide pour l'API OpenAI
# Ce script sauvegarde la clé API et exécute des tests

echo "🧪 Script de test API OpenAI"
echo "=============================="
echo ""

# La clé API
# ⚠️ REMPLACER PAR VOTRE CLÉ API
API_KEY="sk-your-api-key-here"

echo "📝 Note: Ce script nécessite que l'application soit compilée et exécutée."
echo "   La clé API sera sauvegardée dans Keychain via l'application."
echo ""
echo "✅ Pour tester:"
echo "   1. Ouvrez l'application"
echo "   2. Allez dans Préférences (⌘,)"
echo "   3. Collez la clé API et cliquez sur 'Enregistrer'"
echo "   4. Cliquez sur 'Tester la connexion'"
echo ""
echo "🔑 Clé API à copier:"
echo "$API_KEY"
echo ""

# Créer un fichier temporaire avec la clé pour faciliter le copier-coller
echo "$API_KEY" > /tmp/correcteur_api_key.txt
echo "💾 Clé API sauvegardée temporairement dans /tmp/correcteur_api_key.txt"
echo "   Vous pouvez la copier avec: pbcopy < /tmp/correcteur_api_key.txt"
echo ""

# Copier automatiquement dans le presse-papiers si pbcopy est disponible
if command -v pbcopy &> /dev/null; then
    echo "$API_KEY" | pbcopy
    echo "📋 Clé API copiée dans le presse-papiers !"
    echo ""
fi

echo "✅ Prêt ! Ouvrez l'application et collez la clé dans les Préférences."

