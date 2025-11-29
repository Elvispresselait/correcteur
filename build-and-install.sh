#!/bin/bash

# Script pour builder et installer Correcteur Pro dans /Applications

set -e  # Arrêter en cas d'erreur

echo "🔨 Building Correcteur Pro (Release)..."

cd "/Users/hadrienrose/Code/Correcteur Pro"

# Clean build folder
rm -rf build/

# Build en Release
xcodebuild \
    -scheme "Correcteur Pro" \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    clean build

# Trouver l'app buildée
APP_PATH="build/DerivedData/Build/Products/Release/Correcteur Pro.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Erreur: L'app n'a pas été buildée correctement"
    echo "Chemin attendu: $APP_PATH"
    exit 1
fi

echo "✅ Build réussi!"
echo ""
echo "📦 Installation dans /Applications..."

# Supprimer l'ancienne version si elle existe
if [ -d "/Applications/Correcteur Pro.app" ]; then
    echo "🗑️  Suppression de l'ancienne version..."
    rm -rf "/Applications/Correcteur Pro.app"
fi

# Copier la nouvelle version
cp -R "$APP_PATH" "/Applications/"

echo "✅ Installation terminée!"
echo ""
echo "⚠️  IMPORTANT : Autorisations requises"
echo ""
echo "1️⃣  Ouvre les Réglages Système"
echo "2️⃣  Va dans 'Confidentialité et sécurité'"
echo "3️⃣  Clique sur 'Enregistrement d'écran'"
echo "4️⃣  Active le bouton pour 'Correcteur Pro'"
echo "5️⃣  Relance l'application"
echo ""
echo "🚀 Pour lancer l'app:"
echo "   open \"/Applications/Correcteur Pro.app\""
echo ""
