# Deploy Command

Build et déploie l'application dans /Applications.

## Instructions

1. Build le projet en mode Release avec xcodebuild
2. Ferme l'app si elle tourne (pkill)
3. Supprime l'ancienne version dans /Applications
4. Copie la nouvelle version
5. Lance l'application

## Commande

```bash
cd "/Users/hadrienrose/Code/Correcteur Pro" && \
xcodebuild -project "Correcteur Pro.xcodeproj" -scheme "Correcteur Pro" -configuration Release build && \
pkill -f "Correcteur Pro" 2>/dev/null; \
rm -rf "/Applications/Correcteur Pro.app" && \
cp -R ~/Library/Developer/Xcode/DerivedData/Correcteur_Pro-*/Build/Products/Release/Correcteur\ Pro.app /Applications/ && \
open "/Applications/Correcteur Pro.app"
```