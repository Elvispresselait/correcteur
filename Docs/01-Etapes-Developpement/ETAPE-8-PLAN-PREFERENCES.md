# Plan d'Action : Panneau de Préférences (Cmd+,)

**Date** : Novembre 2024
**Objectif** : Créer un panneau de préférences macOS natif avec gestion complète des paramètres de l'application

---

## 📋 Vue d'ensemble

Créer un panneau de préférences accessible via **Cmd+,** (standard macOS) avec :
- Style macOS natif (NSWindow avec Toolbar)
- Onglets pour organiser les paramètres
- Sauvegarde automatique des préférences dans UserDefaults
- Interface SwiftUI moderne

---

## 🎯 Fonctionnalités demandées

### ✅ PRIORITÉ 1 : Capture d'écran

#### Sélection de l'écran
- [ ] Détection automatique de tous les écrans connectés
- [ ] Affichage : "MacBook Pro 16\" (3456x2234)" avec résolution
- [ ] Options :
  - **Écran principal** (défaut)
  - **Tous les écrans** (capture panoramique)
  - **Sélectionner un écran spécifique** (dropdown)
- [ ] Sauvegarde de la préférence

#### Raccourcis clavier (3 raccourcis différents)
1. **Capture écran principal/sélectionné** : Option+Shift+S (défaut)
2. **Capture tous les écrans** : Option+Shift+A (défaut)
3. **Capture zone sélectionnée** : Option+Shift+X (défaut) ⚠️ **COMPLEXE**

#### Interface d'enregistrement des raccourcis
- [ ] Champ cliquable qui détecte les touches pressées
- [ ] Affichage visuel : "⌥⇧S" avec symboles macOS
- [ ] Validation anti-conflits avec raccourcis système
- [ ] Bouton "Réinitialiser" pour revenir aux valeurs par défaut

#### Qualité de compression
- [ ] Slider : Basse / Moyenne / Haute / Aucune
- [ ] Aperçu de la taille estimée : "~500 KB pour 1920x1080"
- [ ] Par défaut : Haute (pour GPT-4o Vision)

#### Options capture
- [ ] Son de notification après capture (✓/✗)
- [ ] Curseur visible dans la capture (✓/✗)
- [ ] Format de sortie : PNG / JPEG (dropdown)

---

### ✅ PRIORITÉ 2 : Interface

#### Thème
- [ ] Clair / Sombre / Auto (système)
- [ ] Aperçu en temps réel du thème choisi

#### Texte
- [ ] Taille de la police dans les bulles : Slider 12-18pt (défaut 14pt)
- [ ] Aperçu du texte avec la taille choisie

#### Fenêtre
- [ ] Position au démarrage : Centre / Dernière position
- [ ] Lancer au démarrage du Mac (checkbox + helper)

---

### ✅ PRIORITÉ 3 : API OpenAI

#### Modèle
- [ ] Dropdown : GPT-4o / GPT-4 Turbo / GPT-3.5 Turbo
- [ ] Prix indicatif à côté : "~0.005€ / 1000 tokens"
- [ ] Par défaut : GPT-4o

#### Tokens
- [ ] Nombre max de tokens : Slider 1000-16000 (défaut 4096)
- [ ] Affichage du coût estimé en euros
- [ ] Afficher l'utilisation des tokens après chaque requête (✓/✗)

#### Calcul du coût en euros
```
GPT-4o : 0.005€ / 1000 input tokens, 0.015€ / 1000 output tokens
GPT-4 Turbo : 0.01€ / 1000 input, 0.03€ / 1000 output
GPT-3.5 Turbo : 0.0005€ / 1000 input, 0.0015€ / 1000 output
```

---

### ✅ PRIORITÉ 4 : Conversations

#### Historique
- [ ] Nombre de messages dans l'historique : Slider 10-50 (défaut 20)
- [ ] Info : "Plus de messages = meilleure mémoire mais plus de coût"

#### Sauvegarde
- [ ] Auto-sauvegarde des conversations (✓/✗) - déjà implémenté
- [ ] Dossier d'export des conversations (bouton "Choisir...")

---

## 🏗️ Architecture technique

### Structure des fichiers

```
Correcteur Pro/
├── Models/
│   └── AppPreferences.swift              // Modèle des préférences
├── Utilities/
│   ├── PreferencesManager.swift          // Gestion UserDefaults
│   └── HotKeyRecorder.swift              // Enregistrement raccourcis
├── Views/
│   └── Preferences/
│       ├── PreferencesWindow.swift       // Fenêtre principale
│       ├── CapturePreferencesView.swift  // Onglet Capture
│       ├── InterfacePreferencesView.swift // Onglet Interface
│       ├── APIPreferencesView.swift      // Onglet API
│       └── ConversationsPreferencesView.swift // Onglet Conversations
```

---

## 🔧 Implémentation par étapes

### ÉTAPE 1 : Modèle et gestion des préférences

**Créer : `Models/AppPreferences.swift`**

```swift
import Foundation

struct AppPreferences: Codable {
    // CAPTURE
    var selectedDisplayID: CGDirectDisplayID?
    var captureMode: CaptureMode = .mainDisplay
    var compressionQuality: CompressionQuality = .high
    var playsSoundAfterCapture: Bool = true
    var showsCursorInCapture: Bool = false
    var outputFormat: ImageFormat = .png

    // RACCOURCIS (stockés comme String "⌥⇧S")
    var hotKeyMainDisplay: String = "⌥⇧S"
    var hotKeyAllDisplays: String = "⌥⇧A"
    var hotKeySelection: String = "⌥⇧X"

    // INTERFACE
    var theme: AppTheme = .auto
    var fontSize: Double = 14.0
    var windowPosition: WindowPosition = .center
    var launchAtLogin: Bool = false

    // API
    var defaultModel: OpenAIModel = .gpt4o
    var maxTokens: Int = 4096
    var showTokenUsage: Bool = true

    // CONVERSATIONS
    var historyMessageCount: Int = 20
    var exportFolder: String?
}

enum CaptureMode: String, Codable, CaseIterable {
    case mainDisplay = "Écran principal"
    case allDisplays = "Tous les écrans"
    case specificDisplay = "Écran sélectionné"
}

enum CompressionQuality: String, Codable, CaseIterable {
    case none = "Aucune"
    case low = "Basse"
    case medium = "Moyenne"
    case high = "Haute"

    var compressionRatio: Double {
        switch self {
        case .none: return 1.0
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.7
        }
    }
}

enum ImageFormat: String, Codable, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "Clair"
    case dark = "Sombre"
    case auto = "Auto"
}

enum WindowPosition: String, Codable, CaseIterable {
    case center = "Centre"
    case lastPosition = "Dernière position"
}

enum OpenAIModel: String, Codable, CaseIterable {
    case gpt4o = "GPT-4o"
    case gpt4Turbo = "GPT-4 Turbo"
    case gpt35Turbo = "GPT-3.5 Turbo"

    var displayName: String { rawValue }

    var costPer1kInputTokens: Double {
        switch self {
        case .gpt4o: return 0.005
        case .gpt4Turbo: return 0.01
        case .gpt35Turbo: return 0.0005
        }
    }

    var costPer1kOutputTokens: Double {
        switch self {
        case .gpt4o: return 0.015
        case .gpt4Turbo: return 0.03
        case .gpt35Turbo: return 0.0015
        }
    }

    var apiModelName: String {
        switch self {
        case .gpt4o: return "gpt-4o"
        case .gpt4Turbo: return "gpt-4-turbo"
        case .gpt35Turbo: return "gpt-3.5-turbo"
        }
    }
}
```

**Créer : `Utilities/PreferencesManager.swift`**

```swift
import Foundation

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    @Published var preferences: AppPreferences

    private let userDefaultsKey = "AppPreferences"

    private init() {
        // Charger depuis UserDefaults ou créer avec valeurs par défaut
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = AppPreferences()
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("✅ Préférences sauvegardées")
        }
    }

    func reset() {
        preferences = AppPreferences()
        save()
    }
}
```

---

### ÉTAPE 2 : Fenêtre de préférences macOS natif

**Créer : `Views/Preferences/PreferencesWindow.swift`**

```swift
import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject var prefsManager = PreferencesManager.shared
    @State private var selectedTab: PreferenceTab = .capture

    enum PreferenceTab: String, CaseIterable {
        case capture = "Capture"
        case interface = "Interface"
        case api = "API"
        case conversations = "Conversations"

        var icon: String {
            switch self {
            case .capture: return "camera.fill"
            case .interface: return "paintpalette.fill"
            case .api: return "network"
            case .conversations: return "bubble.left.and.bubble.right.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar avec onglets
            HStack(spacing: 16) {
                ForEach(PreferenceTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 24))
                            Text(tab.rawValue)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        .frame(width: 80)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Contenu de l'onglet sélectionné
            Group {
                switch selectedTab {
                case .capture:
                    CapturePreferencesView()
                case .interface:
                    InterfacePreferencesView()
                case .api:
                    APIPreferencesView()
                case .conversations:
                    ConversationsPreferencesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 500)
    }
}
```

---

### ÉTAPE 3 : Onglet Capture d'écran

**Créer : `Views/Preferences/CapturePreferencesView.swift`**

```swift
import SwiftUI
import ScreenCaptureKit

struct CapturePreferencesView: View {
    @ObservedObject var prefsManager = PreferencesManager.shared
    @State private var availableDisplays: [DisplayInfo] = []

    struct DisplayInfo: Identifiable {
        let id: CGDirectDisplayID
        let name: String
        let resolution: String
    }

    var body: some View {
        Form {
            Section("Écran à capturer") {
                Picker("Mode de capture", selection: $prefsManager.preferences.captureMode) {
                    ForEach(CaptureMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .onChange(of: prefsManager.preferences.captureMode) { _, _ in
                    prefsManager.save()
                }

                if prefsManager.preferences.captureMode == .specificDisplay {
                    Picker("Écran", selection: $prefsManager.preferences.selectedDisplayID) {
                        ForEach(availableDisplays) { display in
                            Text("\(display.name) (\(display.resolution))")
                                .tag(display.id as CGDirectDisplayID?)
                        }
                    }
                }
            }

            Section("Raccourcis clavier") {
                HotKeyField(label: "Écran principal/sélectionné",
                           value: $prefsManager.preferences.hotKeyMainDisplay)
                HotKeyField(label: "Tous les écrans",
                           value: $prefsManager.preferences.hotKeyAllDisplays)
                HotKeyField(label: "Zone sélectionnée",
                           value: $prefsManager.preferences.hotKeySelection)

                Text("⚠️ La capture de zone sélectionnée nécessite des développements supplémentaires")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Section("Qualité") {
                Picker("Compression", selection: $prefsManager.preferences.compressionQuality) {
                    ForEach(CompressionQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .onChange(of: prefsManager.preferences.compressionQuality) { _, _ in
                    prefsManager.save()
                }

                Picker("Format", selection: $prefsManager.preferences.outputFormat) {
                    ForEach(ImageFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
            }

            Section("Options") {
                Toggle("Son de notification", isOn: $prefsManager.preferences.playsSoundAfterCapture)
                Toggle("Curseur visible", isOn: $prefsManager.preferences.showsCursorInCapture)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadAvailableDisplays()
        }
    }

    private func loadAvailableDisplays() {
        Task {
            if #available(macOS 12.3, *) {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    availableDisplays = content.displays.enumerated().map { index, display in
                        DisplayInfo(
                            id: display.displayID,
                            name: "Écran \(index + 1)",
                            resolution: "\(Int(display.width))x\(Int(display.height))"
                        )
                    }
                } catch {
                    print("❌ Erreur lors de la détection des écrans : \(error)")
                }
            }
        }
    }
}

struct HotKeyField: View {
    let label: String
    @Binding var value: String
    @State private var isRecording = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button(isRecording ? "Appuyez sur des touches..." : value) {
                isRecording = true
                // TODO: Implémenter l'enregistrement du raccourci
            }
            .frame(minWidth: 120)
        }
    }
}
```

---

## ⚠️ COMPLEXITÉ : Capture de zone sélectionnée

### Problématique

La capture de **zone sélectionnée** (comme Cmd+Shift+4 sur macOS) est **beaucoup plus complexe** que la capture d'écran complète.

### Défis techniques

1. **Overlay fullscreen transparent**
   - Créer une fenêtre fullscreen au-dessus de tout
   - Gérer le dessin du rectangle de sélection
   - Détecter les clics souris (début/fin de sélection)

2. **Multi-écrans**
   - L'overlay doit couvrir TOUS les écrans
   - Coordonnées relatives entre écrans

3. **Permissions macOS**
   - Accessibility API pour détecter les clics globaux
   - Screen Recording déjà OK

4. **Performance**
   - Overlay doit être fluide (60fps)
   - Pas de lag lors du drag

### Plan d'implémentation (PHASE 2)

```
ÉTAPE A : Créer SelectionOverlayWindow
- NSWindow fullscreen transparent
- Détecter mouseDown / mouseDragged / mouseUp
- Dessiner rectangle en temps réel

ÉTAPE B : Capturer la zone
- Récupérer les coordonnées du rectangle
- Capturer uniquement cette partie de l'écran
- Convertir NSRect → CGRect pour SCScreenshotManager

ÉTAPE C : Intégration
- Nouveau raccourci Option+Shift+X
- Ouvrir l'overlay au lieu de capturer directement
- Fermer l'overlay → envoyer la capture à ChatGPT
```

### Fichiers à créer (PHASE 2)

```
Utilities/
└── SelectionOverlay/
    ├── SelectionOverlayWindow.swift      // Fenêtre fullscreen
    ├── SelectionOverlayView.swift        // SwiftUI overlay
    └── SelectionCaptureService.swift     // Logique de capture
```

---

## 🚀 Ordre d'implémentation recommandé

### Phase 1 : Basique (1-2h)
1. ✅ Créer AppPreferences + PreferencesManager
2. ✅ Créer PreferencesWindow avec onglets
3. ✅ Implémenter Cmd+, pour ouvrir les préférences

### Phase 2 : Onglets simples (2-3h)
4. ✅ InterfacePreferencesView (thème, police, etc.)
5. ✅ APIPreferencesView (modèle, tokens, coût)
6. ✅ ConversationsPreferencesView (historique, export)

### Phase 3 : Capture simple (2-3h)
7. ✅ CapturePreferencesView (écrans, compression, format)
8. ✅ Détection des écrans disponibles
9. ✅ Sauvegarder les préférences

### Phase 4 : Raccourcis clavier (3-4h)
10. ✅ HotKeyRecorder pour enregistrer les touches
11. ✅ Validation anti-conflits
12. ✅ Réenregistrer les raccourcis globaux à la volée

### Phase 5 : Capture zone sélectionnée (6-8h) ⚠️ **COMPLEXE**
13. ⚠️ SelectionOverlayWindow
14. ⚠️ Gestion du drag de sélection
15. ⚠️ Capture de la zone sélectionnée
16. ⚠️ Tests multi-écrans

---

## 📝 Checklist finale

### Configuration
- [ ] AppPreferences créé avec toutes les propriétés
- [ ] PreferencesManager sauvegarde dans UserDefaults
- [ ] Cmd+, ouvre la fenêtre de préférences

### Onglets
- [ ] Capture : écrans, raccourcis, compression, options
- [ ] Interface : thème, police, fenêtre, démarrage
- [ ] API : modèle, tokens, coût en euros
- [ ] Conversations : historique, export

### Fonctionnalités avancées
- [ ] Détection des écrans avec résolution
- [ ] HotKeyRecorder fonctionnel
- [ ] Validation anti-conflits
- [ ] Capture zone sélectionnée (PHASE 2)

---

## 💡 Notes importantes

1. **UserDefaults** : Toutes les préférences sont sauvegardées automatiquement
2. **Raccourcis globaux** : Réenregistrer quand l'utilisateur change un raccourci
3. **Coût API** : Calculer en temps réel selon le modèle sélectionné
4. **Capture zone** : Feature complexe, à implémenter en PHASE 2 après validation du reste

---

**Prêt à commencer par la PHASE 1 ?**
