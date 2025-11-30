# Build Command

Build le projet sans déployer.

## Instructions

1. Build le projet en mode Release
2. Affiche le résultat du build

## Commande

```bash
cd "/Users/hadrienrose/Code/Correcteur Pro" && \
xcodebuild -project "Correcteur Pro.xcodeproj" -scheme "Correcteur Pro" -configuration Release build 2>&1 | grep -E "(error:|warning:|BUILD)"
```
