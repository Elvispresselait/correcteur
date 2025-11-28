#!/bin/bash

# Script pour supprimer l'entrée Keychain de Correcteur Pro
# Utile si vous utilisez uniquement .env et ne voulez plus d'accès Keychain

echo "🔐 Suppression de l'entrée Keychain pour Correcteur Pro..."
echo ""

# Supprimer l'entrée Keychain
security delete-generic-password -s "com.correcteurpro.apiKey" -a "openai_api_key" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Entrée Keychain supprimée avec succès"
    echo "ℹ️  L'application utilisera uniquement le fichier .env maintenant"
else
    echo "ℹ️  Aucune entrée Keychain trouvée (déjà supprimée ou n'existe pas)"
fi

echo ""
echo "💡 Pour vérifier, ouvrez 'Accès au trousseau' et cherchez 'com.correcteurpro.apiKey'"
echo "   Vous ne devriez plus voir cette entrée."

