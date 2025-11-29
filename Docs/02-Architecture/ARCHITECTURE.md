# 🏗️ Architecture - Correcteur Pro

**Date** : 29 novembre 2024
**Version** : 1.0
**Plateforme** : macOS 12.3+

---

## 📋 Vue d'ensemble

Correcteur Pro est une application macOS native développée en **SwiftUI** qui permet de corriger, traduire et analyser du texte et des images grâce à **GPT-4o Vision** d'OpenAI.

### Caractéristiques principales
- ✅ Interface SwiftUI moderne avec sidebar + chat
- ✅ Intégration API OpenAI (Chat Completions + Vision)
- ✅ Capture d'écran complète (écran principal + zone sélectionnée)
- ✅ Copier-coller d'images avec compression automatique
- ✅ Conversations multiples avec persistance
- ✅ Panneau de préférences natif macOS (Cmd+,)
- ✅ Raccourcis clavier globaux configurables
- ✅ Historique conversationnel (20 messages par défaut)

---

## 📁 Structure du projet

```
Correcteur Pro/
├── CorrecteurProApp.swift           # Point d'entrée SwiftUI App
│
├── Models/                           # Modèles de données
│   ├── AppPreferences.swift          # Préférences utilisateur
│   ├── Conversation.swift            # Modèle conversation
│   ├── Message.swift                 # Modèle message (ChatGPT)
│   └── ImageData.swift               # Métadonnées images
│
├── ViewModels/                       # Logique métier
│   └── ChatViewModel.swift           # Gestion conversations + API
│
├── Views/                            # Interface utilisateur
│   ├── ContentView.swift             # Vue principale (sidebar + chat)
│   ├── ChatView.swift                # Zone de chat + input
│   ├── SidebarView.swift             # Liste conversations
│   ├── TextEditorWithImagePaste.swift # Input avec support images
│   ├── ToastView.swift               # Notifications toast
│   ├── SettingsView.swift            # (Legacy - remplacé par Preferences)
│   ├── Previews.swift                # SwiftUI previews
│   │
│   └── Preferences/                  # Panneau préférences (Cmd+,)
│       ├── PreferencesWindow.swift   # Fenêtre principale avec onglets
│       ├── CapturePreferencesView.swift      # Onglet Capture
│       ├── InterfacePreferencesView.swift    # Onglet Interface
│       ├── APIPreferencesView.swift          # Onglet API
│       └── ConversationsPreferencesView.swift # Onglet Conversations
│
├── Services/                         # Services métier
│   ├── OpenAIService.swift           # Communication API OpenAI
│   └── ConversationStorage.swift     # Persistance conversations
│
├── Utilities/                        # Utilitaires et helpers
│   ├── APIKeyManager.swift           # Gestion clé API (Keychain)
│   ├── PreferencesManager.swift      # Gestion préférences (UserDefaults)
│   ├── GlobalHotKeyManager.swift     # Raccourcis clavier globaux
│   ├── HotKeyRecorder.swift          # Enregistrement raccourcis
│   ├── ScreenCaptureService.swift    # Capture écran principal
│   ├── NSImage+Compression.swift     # Compression images
│   ├── ClipboardHelper.swift         # Gestion clipboard
│   ├── ColorExtension.swift          # Couleurs personnalisées
│   ├── EnvLoader.swift               # Chargement variables .env
│   ├── APILogger.swift               # Logging API
│   │
│   ├── SelectionOverlay/             # Capture zone sélectionnée
│   │   ├── SelectionOverlayWindow.swift      # Fenêtre fullscreen overlay
│   │   ├── SelectionOverlayView.swift        # Vue SwiftUI overlay
│   │   └── SelectionCaptureService.swift     # Logique capture zone
│   │
│   └── [Fichiers de test]            # Tests unitaires et intégration
│       ├── FrontendTester.swift
│       ├── OpenAIConnectionTester.swift
│       ├── QuickTest.swift
│       └── TestAPIService.swift
│
├── Docs/                             # Documentation (nouveau)
│   ├── 01-Etapes-Developpement/      # Historique développement
│   ├── 02-Architecture/              # Architecture et contexte
│   └── 03-Guides/                    # Guides utilisateur
│
└── Assets/                           # Ressources
    └── [Images, icônes, etc.]
```

---

## 🔧 Architecture technique

### Pattern architectural : MVVM (Model-View-ViewModel)

```
┌─────────────────────────────────────────────────────────────┐
│                         VIEWS (SwiftUI)                      │
│  ContentView, ChatView, SidebarView, Preferences...          │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ @StateObject / @ObservedObject
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      VIEW MODELS                             │
│  ChatViewModel (@Published properties)                       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ Utilise
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        SERVICES                              │
│  OpenAIService, ConversationStorage, ScreenCaptureService    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ Manipule
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                         MODELS                               │
│  Conversation, Message, AppPreferences, ImageData            │
└─────────────────────────────────────────────────────────────┘
```

### Flux de données principal

```
User Input (ChatView)
    ↓
ChatViewModel.sendMessage()
    ↓
OpenAIService.sendMessage() → API OpenAI
    ↓
Response reçue
    ↓
ChatViewModel met à jour @Published messages
    ↓
SwiftUI rafraîchit automatiquement ChatView
```

---

## 🔑 Composants clés

### 1. ChatViewModel

**Responsabilités** :
- Gestion des conversations et messages
- Communication avec OpenAIService
- Gestion des images (copier-coller + captures d'écran)
- Persistance via ConversationStorage
- Historique conversationnel (20 derniers messages)

**Propriétés principales** :
```swift
@Published var conversations: [Conversation]
@Published var currentConversationId: UUID?
@Published var isLoading: Bool
```

**Méthodes principales** :
```swift
func sendMessage(text: String, images: [ImageData])
func sendScreenCapture(withPrompt: String?, screenshot: NSImage?)
func createNewConversation()
func deleteConversation(id: UUID)
func selectConversation(id: UUID)
```

---

### 2. OpenAIService

**Responsabilités** :
- Communication HTTP avec API OpenAI
- Formatage des requêtes (messages + images)
- Gestion des erreurs API
- Support multimodal (texte + vision)

**Méthodes principales** :
```swift
static func sendMessage(
    messages: [Message],
    systemPrompt: String
) async throws -> String

static func sendMessageWithHistory(
    newMessage: Message,
    conversationHistory: [Message],
    systemPrompt: String
) async throws -> String
```

**Particularités** :
- Conversion images en base64 avec compression
- Utilise le modèle depuis PreferencesManager
- Force GPT-4o pour images (seul modèle vision)
- Support maxTokens configuré dans préférences

---

### 3. ScreenCaptureService

**Responsabilités** :
- Capture écran principal via ScreenCaptureKit
- Gestion permissions macOS
- Détection erreurs avec codes spécifiques (-3801)

**Méthode principale** :
```swift
static func captureMainScreen() async throws -> NSImage
```

**Gestion permissions** :
```swift
static func getPermissionStatus() async -> PermissionStatus
```

**Note importante** : Ne pas pré-vérifier les permissions avec try/catch (crée une boucle). Laisser le système gérer automatiquement.

---

### 4. SelectionCaptureService (macOS 12.3+)

**Responsabilités** :
- Affichage overlay fullscreen transparent
- Détection zone sélectionnée par l'utilisateur
- Capture et crop de la zone spécifique
- Support multi-écrans

**Méthode principale** :
```swift
static func showSelectionOverlay(completion: @escaping (NSImage?) -> Void)
static func captureRect(_ rect: NSRect) async throws -> NSImage
```

**Architecture overlay** :
```
SelectionOverlayWindow (NSWindow)
    ├── Level: .screenSaver (au-dessus de tout)
    ├── Couvre tous les écrans (union des frames)
    ├── Background: noir 30% opacité
    └── Contient: SelectionOverlayView (SwiftUI)
            ├── DragGesture pour dessiner rectangle
            ├── Affichage dimensions en temps réel
            ├── Conversion coords SwiftUI → NSRect
            └── Callbacks: onSelectionComplete / onCancel
```

---

### 5. PreferencesManager

**Responsabilités** :
- Singleton pour gérer AppPreferences
- Sauvegarde/chargement dans UserDefaults
- Observable pour SwiftUI (@Published)

**Propriétés** :
```swift
@Published var preferences: AppPreferences
```

**Méthodes** :
```swift
func save()
func reset()
```

**Préférences disponibles** :
- **Capture** : Mode, compression, format, son, curseur
- **Raccourcis** : 3 raccourcis configurables (⌥⇧S, ⌥⇧A, ⌥⇧X)
- **Interface** : Thème, police, position fenêtre, démarrage
- **API** : Modèle, maxTokens, affichage usage
- **Conversations** : Nombre messages historique, dossier export

---

### 6. GlobalHotKeyManager

**Responsabilités** :
- Enregistrement raccourcis clavier globaux via Carbon Events
- Parsing raccourcis ("⌥⇧S" → keyCode + modifiers)
- Callbacks pour chaque type de capture
- Réenregistrement dynamique sans redémarrage

**Architecture** :
```swift
private var hotKeyRefs: [EventHotKeyRef] = []
private var eventHandler: EventHandlerRef?

var onMainDisplayCapture: (() -> Void)?
var onAllDisplaysCapture: (() -> Void)?
var onSelectionCapture: (() -> Void)?

func registerAllHotKeys()
func unregisterAllHotKeys()
private func parseHotKey(_ hotKeyString: String) -> (keyCode: UInt32, modifiers: UInt32)?
```

**Mapping keycodes** :
```swift
let keyCodeMap: [Character: UInt32] = [
    "S": 1, "A": 0, "X": 7, "C": 8, "D": 2,
    // ... alphabet complet A-Z
]
```

---

### 7. NSImage+Compression

**Responsabilités** :
- Compression images avec qualité configurable
- Conversion base64 pour API OpenAI
- Support JPEG et PNG
- Gestion taille max selon qualité

**Méthodes principales** :
```swift
func toBase64JPEG(quality: Double, maxSizeMB: Double) -> String?
func toBase64PNG(maxSizeMB: Double) -> String?
func toBase64WithPreferences(skipCompression: Bool) -> String?
```

**Tailles max selon qualité** :
- None : 20 MB
- Low : 5 MB
- Medium : 3 MB
- High : 2 MB

---

## 🔄 Flux de travail principaux

### Flux 1 : Envoi d'un message texte

```
1. User tape message dans TextEditorWithImagePaste
2. User appuie sur Enter
3. ChatView appelle viewModel.sendMessage(text, images)
4. ChatViewModel :
   - Ajoute message user aux messages
   - Crée message temporaire "loading"
   - Récupère les 20 derniers messages (historique)
   - Appelle OpenAIService.sendMessageWithHistory()
5. OpenAIService :
   - Lit modèle depuis PreferencesManager
   - Construit requête JSON avec historique
   - Envoie POST à https://api.openai.com/v1/chat/completions
6. Réponse reçue :
   - ChatViewModel remplace message loading par réponse
   - ConversationStorage sauvegarde dans UserDefaults
7. SwiftUI rafraîchit automatiquement ChatView
```

---

### Flux 2 : Capture écran principale (⌥⇧S)

```
1. User appuie sur Option+Shift+S
2. GlobalHotKeyManager détecte l'événement
3. Callback onMainDisplayCapture exécuté
4. ContentView :
   - Ramène app au premier plan
   - Attend 0.1s (laisser app se mettre au premier plan)
   - Appelle viewModel.sendScreenCapture()
5. ChatViewModel.sendScreenCapture() :
   - Appelle ScreenCaptureService.captureMainScreen()
   - Compresse image avec NSImage+Compression
   - Convertit en base64
   - Ajoute à message avec prompt par défaut
   - Envoie à OpenAIService (force GPT-4o)
6. OpenAIService analyse l'image via Vision API
7. Réponse affichée dans le chat
8. Son notification si activé dans préférences
```

---

### Flux 3 : Capture zone sélectionnée (⌥⇧X)

```
1. User appuie sur Option+Shift+X
2. GlobalHotKeyManager détecte l'événement
3. Callback onSelectionCapture exécuté
4. ContentView appelle SelectionCaptureService.showSelectionOverlay()
5. SelectionCaptureService :
   - Crée SelectionOverlayWindow
   - Affiche fenêtre fullscreen (level .screenSaver)
   - Curseur devient croix
6. User drag pour sélectionner zone :
   - SelectionOverlayView dessine rectangle bleu
   - Affiche dimensions en temps réel
7. User relâche souris :
   - Convertit coords SwiftUI → NSRect
   - Callback onSelectionComplete avec rect
8. SelectionCaptureService.captureRect(rect) :
   - Détecte écran contenant la zone
   - Convertit en coordonnées relatives
   - Capture écran complet
   - Crop la zone sélectionnée
9. Image retournée à ContentView :
   - Ramène app au premier plan
   - Appelle viewModel.sendScreenCapture(screenshot: image)
10. Même flux qu'une capture normale
```

---

### Flux 4 : Copier-coller d'image

```
1. User copie image dans clipboard (Cmd+C depuis autre app)
2. User colle dans TextEditorWithImagePaste (Cmd+V)
3. TextEditorWithImagePaste détecte image :
   - ClipboardHelper.getImageFromClipboard()
   - Convertit NSImage → ImageData
   - Ajoute à @State images[]
4. User tape texte + appuie Enter
5. ChatView envoie message avec images[] à ChatViewModel
6. ChatViewModel :
   - Compresse chaque image avec NSImage+Compression
   - Convertit en base64
   - Construit message multimodal
   - Envoie à OpenAIService (force GPT-4o)
7. OpenAIService analyse texte + images
8. Réponse affichée
```

---

## 🔐 Gestion des secrets

### APIKeyManager (Keychain)

```swift
static let shared = APIKeyManager()

func saveAPIKey(_ key: String)
func getAPIKey() -> String?
func deleteAPIKey()
```

**Stockage sécurisé** :
- Utilise Keychain macOS (secure by design)
- Service: "com.correcteurpro.openai"
- Account: "api_key"

### Fichier .env (développement)

```
OPENAI_API_KEY=sk-...
```

**Chargement** :
- EnvLoader.load() cherche dans Bundle.main.resourcePath
- Support .env et env.txt (visible dans Xcode)
- Compatible sandbox macOS

---

## 💾 Persistance des données

### Conversations (UserDefaults)

**Clé** : `"SavedConversations"`
**Format** : JSON encodé avec `Codable`

```swift
// Sauvegarde
if let encoded = try? JSONEncoder().encode(conversations) {
    UserDefaults.standard.set(encoded, forKey: "SavedConversations")
}

// Restauration
if let data = UserDefaults.standard.data(forKey: "SavedConversations"),
   let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
    conversations = decoded
}
```

**Déclenchement** :
- Après chaque message envoyé/reçu
- Après création/suppression conversation
- Automatique via `@Published` + observer

---

### Préférences (UserDefaults)

**Clé** : `"AppPreferences"`
**Format** : JSON encodé avec `Codable`

```swift
struct AppPreferences: Codable {
    // Capture
    var selectedDisplayID: CGDirectDisplayID?
    var captureMode: CaptureMode = .mainDisplay
    var compressionQuality: CompressionQuality = .high
    var playsSoundAfterCapture: Bool = true
    var showsCursorInCapture: Bool = false
    var outputFormat: ImageFormat = .png

    // Raccourcis
    var hotKeyMainDisplay: String = "⌥⇧S"
    var hotKeyAllDisplays: String = "⌥⇧A"
    var hotKeySelection: String = "⌥⇧X"

    // Interface
    var theme: AppTheme = .auto
    var fontSize: Double = 14.0
    var windowPosition: WindowPosition = .center
    var launchAtLogin: Bool = false

    // API
    var defaultModel: OpenAIModel = .gpt4o
    var maxTokens: Int = 4096
    var showTokenUsage: Bool = true

    // Conversations
    var historyMessageCount: Int = 20
    var exportFolder: String?
}
```

**Sauvegarde automatique** :
- Via `PreferencesManager.save()`
- Déclenchée par `.onChange()` dans les vues
- Synchronisation immédiate

---

## 🔌 API OpenAI

### Configuration

**Base URL** : `https://api.openai.com/v1/chat/completions`
**Authentification** : Bearer token (clé API)

### Format requête

```json
{
  "model": "gpt-4o",
  "messages": [
    {
      "role": "system",
      "content": "Tu es un correcteur professionnel..."
    },
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "Corrige ce texte" },
        { "type": "image_url", "image_url": { "url": "data:image/jpeg;base64,..." } }
      ]
    }
  ],
  "temperature": 0.7,
  "max_tokens": 4096
}
```

### Modèles supportés

| Modèle | Utilisation | Prix input | Prix output |
|--------|-------------|------------|-------------|
| GPT-4o | Images + texte (défaut) | 0.005€/1k tokens | 0.015€/1k tokens |
| GPT-4 Turbo | Texte uniquement | 0.01€/1k tokens | 0.03€/1k tokens |
| GPT-3.5 Turbo | Texte uniquement | 0.0005€/1k tokens | 0.0015€/1k tokens |

**Règle automatique** :
- Si message contient images → Force GPT-4o (seul modèle vision)
- Si texte seul → Utilise modèle choisi dans préférences

---

## ⚙️ Configuration système requise

### macOS version

**Minimum** : macOS 12.3 (Monterey)
**Raison** : ScreenCaptureKit introduit dans macOS 12.3

### Permissions

1. **Screen Recording** (obligatoire)
   - Nécessaire pour ScreenCaptureService
   - System Preferences → Privacy & Security → Screen Recording
   - Cocher "Correcteur Pro"

2. **Keychain Access** (automatique)
   - Gestion clé API OpenAI
   - Aucune action utilisateur requise

### Entitlements

```xml
<key>com.apple.security.device.camera</key>
<false/>
<key>com.apple.security.screen-capture</key>
<true/>
<key>com.apple.security.app-sandbox</key>
<true/>
```

---

## 🧪 Tests et debugging

### Fichiers de test

- `FrontendTester.swift` : Tests programmatiques de l'interface
- `OpenAIConnectionTester.swift` : Test connexion API
- `QuickTest.swift` : Tests rapides unitaires
- `TestAPIService.swift` : Mock service API
- `APILogger.swift` : Logging requêtes/réponses API

### Logs importants

**Format** :
```
📸 [ScreenCapture] Début capture...
✅ [ScreenCapture] Capture réussie
❌ [ScreenCapture] Erreur : ...
🤖 [OpenAIService] Modèle sélectionné : gpt-4o
```

**Préfixes** :
- 📸 Capture d'écran
- 🤖 API OpenAI
- ✅ Succès
- ❌ Erreur
- ⚠️ Warning

---

## 🚀 Performance

### Compression d'images

**Temps moyen** : ~100-200ms pour une capture 1920x1080

**Stratégies** :
- Compression JPEG progressive (quality 0.3-1.0)
- Réduction taille si > maxSizeMB
- Cache des images déjà compressées (skipCompression)

### API OpenAI

**Latence moyenne** : 2-5 secondes selon complexité

**Optimisations** :
- Historique limité à 20 messages (configurable)
- Compression images avant envoi
- Requêtes async/await

---

## 🔒 Sécurité

### Bonnes pratiques implémentées

1. **Clé API stockée dans Keychain** (pas en clair)
2. **Pas de logs des clés API** (masquées dans APILogger)
3. **Sandbox macOS activé** (isolation app)
4. **HTTPS uniquement** pour API OpenAI
5. **Validation permissions** avant capture écran

### Points d'attention

- ⚠️ Fichier .env ne doit PAS être commité (ajouté à .gitignore)
- ⚠️ Clé API ne doit jamais apparaître dans les logs
- ⚠️ Images capturées ne sont pas sauvegardées localement (privacy)

---

## 📊 Métriques du projet

**Nombre de fichiers Swift** : 37
**Architecture** : MVVM + Services
**UI Framework** : SwiftUI
**Minimum macOS** : 12.3 (Monterey)
**Dépendances externes** : 0 (APIs système uniquement)

**Lignes de code estimées** :
- Models : ~300 lignes
- ViewModels : ~500 lignes
- Views : ~1200 lignes
- Services : ~400 lignes
- Utilities : ~1500 lignes
- **Total** : ~3900 lignes

---

## 🔮 Évolution future

### Fonctionnalités prévues (roadmap.md)

1. **Refactoring code** ✅ (en cours)
   - Documentation organisée
   - Code nettoyé

2. **Écrasement images**
   - Réduction taille au strict minimum pour lisibilité

3. **Thème clair**
   - Interface optimisée pour mode clair

4. **Refactoring UI**
   - Faciliter modifications par designer

### Fonctionnalités futures (agents)

- Détection automatique type document
- Bases de données spécialisées (juridique, académique)
- Analyse multi-étapes
- Recherche sémantique (Vector DB)

---

## 📚 Références

### Documentation Apple

- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Carbon Events](https://developer.apple.com/documentation/carbon/carbon_event_manager)

### Documentation OpenAI

- [Chat Completions API](https://platform.openai.com/docs/api-reference/chat)
- [Vision API](https://platform.openai.com/docs/guides/vision)
- [Pricing](https://openai.com/api/pricing/)

---

**Document créé le** : 29 novembre 2024
**Auteur** : Claude Code
**Statut** : ✅ À jour
