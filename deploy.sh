#!/bin/bash
# deploy.sh - Déploie Correcteur Pro vers /Applications
# Usage: ./deploy.sh

echo "🚀 Déploiement de Correcteur Pro..."

# Fermer l'app si elle tourne
echo "📦 Fermeture de l'app..."
pkill -f "Correcteur Pro" 2>/dev/null
sleep 1

# Trouver le dossier DerivedData
DERIVED_DATA=$(ls -d ~/Library/Developer/Xcode/DerivedData/Correcteur_Pro-* 2>/dev/null | head -1)

if [ -z "$DERIVED_DATA" ]; then
    echo "❌ Erreur: Aucun build trouvé dans DerivedData"
    echo "   Compile d'abord le projet dans Xcode (Cmd+B)"
    exit 1
fi

BUILD_PATH="$DERIVED_DATA/Build/Products/Debug/Correcteur Pro.app"

if [ ! -d "$BUILD_PATH" ]; then
    echo "❌ Erreur: App non trouvée à $BUILD_PATH"
    echo "   Compile d'abord le projet dans Xcode (Cmd+B)"
    exit 1
fi

# Supprimer l'ancienne version
echo "🗑️  Suppression de l'ancienne version..."
rm -rf "/Applications/Correcteur Pro.app"

# Copier la nouvelle version
echo "📋 Copie de la nouvelle version..."
cp -R "$BUILD_PATH" "/Applications/"

if [ $? -eq 0 ]; then
    echo "✅ Déploiement réussi!"
    echo ""
    echo "📍 App installée: /Applications/Correcteur Pro.app"
    echo "📅 Date: $(date)"
    echo ""

    # Demander si on veut lancer l'app
    read -p "🚀 Lancer l'app maintenant? (o/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        open "/Applications/Correcteur Pro.app"
        echo "✅ App lancée!"
    fi
else
    echo "❌ Erreur lors de la copie"
    exit 1
fi
