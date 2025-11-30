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

- `ChatView.swift` - Main chat UI, message bubbles, input bar, prompt editor
- `ChatViewModel.swift` - Business logic, API calls orchestration
- `OpenAIService.swift` - OpenAI API integration
- `AppPreferences.swift` - All app preferences and prompt definitions
- `ContentView.swift` - Root layout with transparency effect

## Recent Features (v1.1)

1. **Frosted glass effect** - Window transparency with blur (`VisualEffects.swift`)
2. **Prompt archiving** - Archive/restore custom prompts with 90-day auto-delete
3. **Anti-false-positive prompt** - Few-shot learning to prevent incorrect corrections
4. **Responsive prompt editor** - Column mode (wide) and inline mode (compact)
5. **Screen capture via keyboard shortcuts**:
   - `⌥⇧S` (Option+Shift+S) - Capture main screen
   - `⌥⇧X` (Option+Shift+X) - Capture selected zone with interactive overlay
   - Captured images are automatically added to pending images in chat

## Screen Capture Architecture

The screen capture system uses macOS ScreenCaptureKit:

- **GlobalHotKeyManager** (`Utilities/GlobalHotKeyManager.swift`) - Registers global hotkeys via Carbon Events API
- **ScreenCaptureService** (`Utilities/ScreenCaptureService.swift`) - Captures screens using SCScreenshotManager
- **SelectionCaptureService** (`Utilities/SelectionOverlay/`) - Interactive selection overlay

Flow:
1. User presses hotkey → `GlobalHotKeyManager` triggers callback
2. `ContentView.setupGlobalHotKey()` calls `ScreenCaptureService.captureMainScreen()`
3. Captured image is stored in `ChatViewModel.capturedImage`
4. `ChatView.onChange(of: viewModel.capturedImage)` transfers it to `pendingImages`

**TCC Permission**: App requires Screen Recording permission (bundle ID: `Hadrien.Correcteur-Pro`)

## Build & Deploy

```bash
# Build
xcodebuild -project "Correcteur Pro.xcodeproj" -scheme "Correcteur Pro" -configuration Release build

# Deploy to /Applications
pkill -f "Correcteur Pro" 2>/dev/null
rm -rf "/Applications/Correcteur Pro.app"
cp -R ~/Library/Developer/Xcode/DerivedData/Correcteur_Pro-*/Build/Products/Release/Correcteur\ Pro.app /Applications/
open "/Applications/Correcteur Pro.app"
```

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
4. Test screen capture shortcuts (⌥⇧S, ⌥⇧X) - requires TCC permission

## Common Tasks

- **Add new preference**: Edit `AppPreferences.swift`, add UI in appropriate preferences view
- **Modify prompt**: Edit `AppPreferences.defaultPromptCorrecteur` or relevant prompt property
- **Change UI colors**: Most gradients defined in view files (ContentView, ChatView, SidebarView)
- **Debug issues**: Enable debug console via terminal icon in header
- **Fix TCC permission**: Run `tccutil reset ScreenCapture Hadrien.Correcteur-Pro` then relaunch app
