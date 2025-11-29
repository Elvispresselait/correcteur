#!/bin/bash

# Script pour lancer Correcteur Pro depuis /Applications

echo "🚀 Lancement de Correcteur Pro..."

if [ ! -d "/Applications/Correcteur Pro.app" ]; then
    echo "❌ Erreur: Correcteur Pro n'est pas installé dans /Applications"
    echo ""
    echo "Lance d'abord: ./build-and-install.sh"
    exit 1
fi

# Quitter l'app si elle tourne déjà
pkill -x "Correcteur Pro" 2>/dev/null || true

# Lancer l'app
open "/Applications/Correcteur Pro.app"

echo "✅ Application lancée!"
echo ""
echo "💡 Si c'est la première fois:"
echo "   1. Clique sur le bouton 🎥 (caméra)"
echo "   2. Si une alerte apparaît, clique sur 'Ouvrir les Réglages'"
echo "   3. Active 'Correcteur Pro' dans 'Enregistrement d'écran'"
echo "   4. Relance ce script: ./run-app.sh"
