# Correcteur Pro - Context for Claude Code

## Project Overview

**Correcteur Pro** is a macOS application for spell-checking and text correction using OpenAI's GPT-4o Vision API. Users can paste screenshots of text, and the app returns corrections with visual markup (strikethrough for errors, bold for corrections).

## Tech Stack

- **Language**: Swift 5.9+
- **Framework**: SwiftUI (macOS 13+)
- **Architecture**: MVVM
- **API**: OpenAI Chat Completions + Vision API
- **Storage**: UserDefaults (preferences), Keychain (API key)

## Key Directories

```
Correcteur Pro/
├── Models/           # Data models (AppPreferences, Conversation, Message)
├── ViewModels/       # ChatViewModel (main business logic)
├── Views/            # SwiftUI views
│   ├── ChatView.swift      # Main chat interface
│   ├── ContentView.swift   # Root view with sidebar
│   ├── SidebarView.swift   # Conversation list
│   └── Preferences/        # Settings panels
├── Services/         # OpenAIService (API calls)
├── Utilities/        # PreferencesManager, DebugLogger, etc.
└── Docs/             # Documentation
```

## Important Files

- `CorrecteurProApp.swift` - Point d'entrée, AppDelegate, MenuBarExtra
- `ChatView.swift` - Main chat UI, message bubbles, input bar, prompt editor
- `ChatViewModel.swift` - Business logic, API calls orchestration
- `OpenAIService.swift` - OpenAI API integration
- `AppPreferences.swift` - All app preferences and prompt definitions
- `ContentView.swift` - Root layout with transparency effect, notification handlers
- `Views/MenuBarMenu.swift` - Menu déroulant pour l'icône menu bar

## Recent Features (v1.2)

1. **Menu Bar App** - L'application tourne en arrière-plan avec icône dans la barre de menu
2. **Raccourcis globaux permanents** - Fonctionnent même fenêtre fermée
3. **Envoi automatique** - Option pour envoyer automatiquement les captures pour correction
4. **Frosted glass effect** - Window transparency with blur (`VisualEffects.swift`)
5. **Prompt archiving** - Archive/restore custom prompts with 90-day auto-delete
6. **Screen capture via keyboard shortcuts**:
   - `⌥⇧S` (Option+Shift+S) - Capture zone sélectionnée avec overlay interactif
   - `⌥⇧X` (Option+Shift+X) - Capture écran principal
   - Captured images are automatically sent or added to pending images

## Menu Bar App Architecture (v1.2)

L'application est une **menu bar app** qui reste active en arrière-plan :

### Comportement
- **Icône menu bar** : `checkmark.circle` (SF Symbol) toujours visible
- **Icône Dock** : Visible par défaut, masquable dans Préférences > Interface
- **Fermer fenêtre** : L'app reste en vie (ne quitte pas)
- **Raccourcis globaux** : Fonctionnent même fenêtre fermée
- **Capture fenêtre fermée** : Ouvre automatiquement la fenêtre et envoie l'image

### Fichiers clés

| Fichier | Rôle |
|---------|------|
| `CorrecteurProApp.swift` | Point d'entrée avec `AppDelegate` et `MenuBarExtra` |
| `Views/MenuBarMenu.swift` | Menu déroulant de la barre de menu |
| `AppPreferences.swift` | Préférences `showInDock`, `launchAtLogin`, `autoSendOnCapture` |

### AppDelegate

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Applique showInDock, enregistre les hotkeys
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // CRITIQUE : ne pas quitter quand fenêtre fermée
    }
}
```

### Communication AppDelegate ↔ ContentView

Les captures sont transmises via `NotificationCenter` :

1. `AppDelegate.setupHotKeyCallbacks()` capture l'image
2. Post `.screenCaptured` notification avec l'image
3. `ContentView.onReceive(.screenCaptured)` traite l'image

```swift
// Notifications définies dans CorrecteurProApp.swift
extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
    static let screenCaptured = Notification.Name("screenCaptured")
    static let captureError = Notification.Name("captureError")
}
```

## Screen Capture Architecture

The screen capture system uses macOS ScreenCaptureKit:

- **GlobalHotKeyManager** (`Utilities/GlobalHotKeyManager.swift`) - Registers global hotkeys via Carbon Events API
- **ScreenCaptureService** (`Utilities/ScreenCaptureService.swift`) - Captures screens using SCScreenshotManager
- **SelectionCaptureService** (`Utilities/SelectionOverlay/`) - Interactive selection overlay

Flow (depuis v1.2):
1. User presses hotkey → `GlobalHotKeyManager` triggers callback in `AppDelegate`
2. `AppDelegate.setupHotKeyCallbacks()` appelle `ScreenCaptureService` ou `SelectionCaptureService`
3. Image capturée → `NotificationCenter.post(name: .screenCaptured, object: image)`
4. `ContentView.onReceive(.screenCaptured)` → auto-envoi ou ajout à `pendingImages`

**TCC Permission**: App requires Screen Recording permission (bundle ID: `Hadrien.Correcteur-Pro`)

## Build & Deploy (⚠️ IMPORTANT)

**Après chaque rebuild, le cache TCC doit être réinitialisé** car la signature de l'app change et macOS invalide les permissions.

### Commandes complètes (copier-coller) :

```bash
# 1. Build
xcodebuild -project "Correcteur Pro.xcodeproj" -scheme "Correcteur Pro" -configuration Release build

# 2. Deploy + Reset TCC
pkill -f "Correcteur Pro" 2>/dev/null
rm -rf "/Applications/Correcteur Pro.app"
cp -R ~/Library/Developer/Xcode/DerivedData/Correcteur_Pro-*/Build/Products/Release/Correcteur\ Pro.app /Applications/
tccutil reset ScreenCapture Hadrien.Correcteur-Pro
open "/Applications/Correcteur Pro.app"

# 3. Quand le dialogue de permission apparaît :
#    - Cliquer "Ouvrir Réglages Système..."
#    - Activer Correcteur Pro
#    - RELANCER l'app (obligatoire pour macOS)
pkill -f "Correcteur Pro"; open "/Applications/Correcteur Pro.app"
```

### One-liner pour Claude Code :

```bash
xcodebuild -project "Correcteur Pro.xcodeproj" -scheme "Correcteur Pro" -configuration Release build && pkill -f "Correcteur Pro" 2>/dev/null; rm -rf "/Applications/Correcteur Pro.app" && cp -R ~/Library/Developer/Xcode/DerivedData/Correcteur_Pro-*/Build/Products/Release/Correcteur\ Pro.app /Applications/ && tccutil reset ScreenCapture Hadrien.Correcteur-Pro && open "/Applications/Correcteur Pro.app"
```

**Note:** Ce problème n'existe pas en production (signature stable).

## Code Conventions

- French comments and documentation
- English variable/function names
- MARK comments for section organization
- Emoji prefixes for log messages (✅ success, ❌ error, 📸 capture, etc.)

## Testing

No automated tests yet. Manual testing via:
1. Build and run in Xcode
2. Test with sample images containing text
3. Verify corrections display correctly
4. Test screen capture shortcuts (⌥⇧S zone, ⌥⇧X écran) - requires TCC permission

### Tests Menu Bar App (v1.2)
- [ ] Icône checkmark.circle apparaît dans la barre de menu
- [ ] Menu déroulant s'affiche au clic sur l'icône
- [ ] "Ouvrir Correcteur Pro" ouvre/active la fenêtre
- [ ] Fermer la fenêtre (⌘W) ne quitte PAS l'app
- [ ] ⌥⇧S fonctionne même fenêtre fermée → ouvre la fenêtre
- [ ] ⌥⇧X fonctionne même fenêtre fermée → ouvre la fenêtre
- [ ] Toggle "Afficher dans le Dock" fonctionne immédiatement
- [ ] "Quitter Correcteur Pro" termine vraiment l'app

## Common Tasks

- **Add new preference**: Edit `AppPreferences.swift`, add UI in appropriate preferences view
- **Modify prompt**: Edit `AppPreferences.defaultPromptCorrecteur` or relevant prompt property
- **Change UI colors**: Most gradients defined in view files (ContentView, ChatView, SidebarView)
- **Debug issues**: Enable debug console via terminal icon in header
- **Build & test**: Toujours utiliser le workflow complet (voir section "Build & Deploy") incluant le reset TCC
- **Modifier le menu bar**: Edit `Views/MenuBarMenu.swift`
- **Ajouter un callback hotkey**: Edit `AppDelegate.setupHotKeyCallbacks()` dans `CorrecteurProApp.swift`
- **Changer l'icône menu bar**: Modifier le `Image(systemName:)` dans `MenuBarExtra` de `CorrecteurProApp.swift`
