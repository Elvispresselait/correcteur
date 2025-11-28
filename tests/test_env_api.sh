#!/bin/bash

# Script de test rapide de l'API OpenAI en utilisant le fichier .env

echo "🧪 Test API OpenAI depuis .env"
echo "================================"
echo ""

# Lire le fichier .env
ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Fichier .env non trouvé"
    exit 1
fi

# Extraire la clé API
API_KEY=$(grep "^OPENAI_API_KEY=" "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'")

if [ -z "$API_KEY" ] || [ "$API_KEY" = "sk-your-api-key-here" ]; then
    echo "❌ Clé API non trouvée ou non configurée dans .env"
    echo "   Assurez-vous que OPENAI_API_KEY=sk-... est défini"
    exit 1
fi

echo "✅ Clé API trouvée dans .env"
echo ""

# Test 1 : Test de connexion simple avec curl
echo "📡 TEST 1 : Test de connexion à l'API..."
echo "─────────────────────────────────────────"

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X GET "https://api.openai.com/v1/models" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    --max-time 10)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Connexion réussie ! (HTTP $HTTP_CODE)"
    echo ""
    
    # Test 2 : Envoi d'un message simple
    echo "📝 TEST 2 : Envoi d'un message simple..."
    echo "─────────────────────────────────────────"
    
    MESSAGE_RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": "Tu es un assistant utile."},
                {"role": "user", "content": "Dis bonjour en français"}
            ],
            "max_tokens": 50
        }' \
        --max-time 30)
    
    MESSAGE_HTTP_CODE=$(echo "$MESSAGE_RESPONSE" | tail -n1)
    MESSAGE_BODY=$(echo "$MESSAGE_RESPONSE" | sed '$d')
    
    if [ "$MESSAGE_HTTP_CODE" = "200" ]; then
        echo "✅ Message envoyé avec succès ! (HTTP $MESSAGE_HTTP_CODE)"
        
        # Extraire la réponse avec jq si disponible, sinon avec grep/sed
        if command -v jq &> /dev/null; then
            REPLY=$(echo "$MESSAGE_BODY" | jq -r '.choices[0].message.content' 2>/dev/null)
            TOKENS=$(echo "$MESSAGE_BODY" | jq -r '.usage.total_tokens' 2>/dev/null)
            echo ""
            echo "💬 Réponse:"
            echo "$REPLY"
            echo ""
            if [ ! -z "$TOKENS" ] && [ "$TOKENS" != "null" ]; then
                echo "📊 Tokens utilisés: $TOKENS"
            fi
        else
            # Fallback sans jq
            REPLY=$(echo "$MESSAGE_BODY" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4)
            echo ""
            echo "💬 Réponse (extrait):"
            echo "$REPLY"
            echo ""
            echo "ℹ️  Installez 'jq' pour une meilleure extraction: brew install jq"
        fi
    else
        echo "❌ Erreur lors de l'envoi du message (HTTP $MESSAGE_HTTP_CODE)"
        echo "Réponse: $MESSAGE_BODY"
    fi
    
    echo ""
    echo "✅ ===== TESTS TERMINÉS ====="
    echo ""
else
    echo "❌ Erreur de connexion (HTTP $HTTP_CODE)"
    echo "Réponse: $BODY"
    exit 1
fi
