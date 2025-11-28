#!/bin/bash

# Script de test rapide du flux frontend
# Simule l'envoi d'un message depuis l'interface

echo "🧪 Test du flux frontend (simulation)"
echo "======================================"
echo ""

# 1. Vérifier le fichier .env
echo "📋 ÉTAPE 1 : Vérification du fichier .env"
if [ -f .env ]; then
    echo "✅ Fichier .env trouvé"
    if grep -q "OPENAI_API_KEY=" .env; then
        echo "✅ OPENAI_API_KEY présente dans .env"
        KEY_LENGTH=$(grep "OPENAI_API_KEY=" .env | cut -d'=' -f2 | wc -c)
        echo "   Longueur de la clé : $((KEY_LENGTH - 1)) caractères"
    else
        echo "❌ OPENAI_API_KEY non trouvée dans .env"
        exit 1
    fi
else
    echo "❌ Fichier .env non trouvé"
    exit 1
fi

echo ""
echo "📋 ÉTAPE 2 : Test de l'API (appel réel)"
echo "─────────────────────────────────────────────────────"

# Charger la clé depuis .env
source .env 2>/dev/null

if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Impossible de charger OPENAI_API_KEY depuis .env"
    exit 1
fi

# Test rapide de l'API
echo "📡 Test de connexion à l'API OpenAI..."
RESPONSE=$(curl -s -m 10 -X GET "https://api.openai.com/v1/models" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json")

if echo "$RESPONSE" | grep -q "\"object\"" || echo "$RESPONSE" | grep -q "gpt-"; then
    echo "✅ Connexion API réussie"
    echo "   L'API répond correctement"
else
    echo "❌ Erreur de connexion API"
    echo "   Réponse : $(echo "$RESPONSE" | head -c 200)"
    exit 1
fi

echo ""
echo "📋 ÉTAPE 3 : Test d'envoi de message"
echo "─────────────────────────────────────────────────────"

# Test d'envoi d'un message simple
echo "📝 Envoi d'un message test..."
RESPONSE=$(curl -s -m 30 -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gpt-4o-mini",
        "messages": [
            {"role": "system", "content": "Tu es un assistant utile."},
            {"role": "user", "content": "Dis bonjour en français"}
        ],
        "temperature": 0.7,
        "max_tokens": 2000
    }')

if echo "$RESPONSE" | grep -q "\"choices\""; then
    echo "✅ Message envoyé avec succès"
    CONTENT=$(echo "$RESPONSE" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4)
    if [ -n "$CONTENT" ]; then
        echo "   Réponse : $CONTENT"
    fi
else
    echo "❌ Erreur lors de l'envoi du message"
    echo "   Réponse : $(echo "$RESPONSE" | head -c 300)"
    exit 1
fi

echo ""
echo "✅ ===== TOUS LES TESTS RÉUSSIS ====="
echo ""
echo "💡 Le problème ne vient PAS de l'API"
echo "   → Vérifiez les logs de l'application pour voir où ça bloque"
echo "   → Utilisez le bouton de test dans l'interface (icône testtube)"

