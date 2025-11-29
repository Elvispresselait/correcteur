# 📸 Plan : Capture d'écran automatique sur macOS

**Date** : 28 novembre 2024
**Objectif** : Permettre à l'application de capturer l'écran Mac et d'envoyer l'image à ChatGPT

---

## 🎯 Objectif Final

1. **Raccourci clavier global** : L'utilisateur appuie sur un raccourci (ex: `Cmd+Shift+S`)
2. **Capture automatique** : L'app capture tout l'écran (ou une sélection)
3. **Envoi à ChatGPT** : L'image capturée est automatiquement envoyée à l'API avec un prompt

---

## 🔐 Autorisations macOS Requises

### **1. Screen Recording Permission**
- **Entitlement** : `com.apple.security.personal-information.screen-recording`
- **Info.plist** : `NSScreenCaptureUsageDescription`
- ⚠️ **IMPORTANT** : Cette autorisation nécessite que l'app soit **signée et installée dans /Applications**
- Les builds Xcode en développement ne peuvent PAS obtenir cette autorisation
- L'utilisateur doit manuellement autoriser l'app dans **Préférences Système > Confidentialité > Enregistrement de l'écran**

### **2. Accessibility API (optionnel pour raccourcis globaux)**
- **Entitlement** : `com.apple.security.personal-information.accessibility`
- Nécessaire pour écouter les raccourcis clavier globaux même quand l'app est en arrière-plan

---

## 🚧 Limitations du Mode Développement (Xcode Preview/Debug)

### ❌ **Ce qui NE FONCTIONNE PAS en mode debug Xcode** :
1. ❌ Autorisations Screen Recording (toujours refusées)
2. ❌ Capture d'écran complète
3. ❌ Raccourcis clavier globaux (en arrière-plan)

### ✅ **Ce qui FONCTIONNE en mode debug** :
1. ✅ UI de l'application
2. ✅ Bouton manuel pour déclencher la capture (mais la capture échouera)
3. ✅ Test de l'envoi d'une image déjà existante à l'API
4. ✅ Logique de traitement des images

### 🔧 **Solution pour le développement** :
1. **Créer un build de release** et l'installer dans `/Applications`
2. **Signer l'app** (même avec signature locale)
3. **Autoriser manuellement** dans Préférences Système
4. **Tester avec l'app installée**, pas depuis Xcode

---

## 📋 Plan d'Implémentation (6 Étapes)

### **ÉTAPE 1 : Configuration des Entitlements et Info.plist**

**Fichier : `Correcteur Pro.entitlements`**
```xml
<key>com.apple.security.personal-information.screen-recording</key>
<true/>
<key>com.apple.security.personal-information.accessibility</key>
<true/>
```

**Fichier : `Info.plist`**
```xml
<key>NSScreenCaptureUsageDescription</key>
<string>Correcteur Pro a besoin d'accéder à votre écran pour capturer des images et les analyser avec ChatGPT.</string>
<key>NSAccessibilityUsageDescription</key>
<string>Correcteur Pro utilise les raccourcis clavier globaux pour déclencher les captures d'écran rapidement.</string>
```

**Validation** : Build réussit sans erreur, entitlements ajoutés au bundle.

---

### **ÉTAPE 2 : Service de Capture d'Écran**

**Créer : `Utilities/ScreenCaptureService.swift`**

```swift
import Cocoa
import ScreenCaptureKit

@available(macOS 12.3, *)
class ScreenCaptureService {

    // MARK: - Permission Status

    enum PermissionStatus {
        case authorized
        case notDetermined  // Jamais demandé
        case denied         // Refusé par l'utilisateur
        case restricted     // Bloqué par politique système
    }

    /// Vérifier l'état actuel des permissions
    static func getPermissionStatus() async -> PermissionStatus {
        if #available(macOS 14.0, *) {
            let canCapture = await SCScreenshotManager.canCapture()
            if canCapture {
                return .authorized
            }

            // Tester si on peut accéder au contenu pour distinguer denied vs notDetermined
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return .notDetermined
            } catch {
                return .denied
            }
        } else {
            // macOS < 14 : Pas de vérification native, on teste directement
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return .authorized
            } catch {
                return .denied
            }
        }
    }

    // MARK: - Capture

    /// Capture tout l'écran principal avec gestion d'erreurs détaillée
    static func captureMainScreen() async throws -> NSImage {
        // 1. ⚠️ IMPORTANT : Vérifier les autorisations AVANT de tenter la capture
        let permissionStatus = await getPermissionStatus()

        switch permissionStatus {
        case .denied:
            throw ScreenCaptureError.permissionDenied(
                message: "L'autorisation d'enregistrement d'écran a été refusée.",
                instructionStep: .openSystemPreferences
            )

        case .notDetermined:
            throw ScreenCaptureError.permissionNotRequested(
                message: "L'application doit être autorisée à enregistrer l'écran.",
                instructionStep: .openSystemPreferences
            )

        case .restricted:
            throw ScreenCaptureError.permissionRestricted(
                message: "L'enregistrement d'écran est bloqué par une politique système."
            )

        case .authorized:
            break // Continue
        }

        // 2. Obtenir les écrans disponibles
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw ScreenCaptureError.systemError(
                message: "Impossible d'accéder aux écrans disponibles.",
                underlyingError: error
            )
        }

        guard let mainDisplay = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound(
                message: "Aucun écran détecté. Vérifiez que votre Mac a au moins un écran connecté."
            )
        }

        // 3. Configurer le filtre pour capturer l'écran
        let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])

        // 4. Configuration de capture (résolution, framerate)
        let config = SCStreamConfiguration()
        config.width = Int(mainDisplay.width)
        config.height = Int(mainDisplay.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        // 5. Capturer une frame
        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            throw ScreenCaptureError.captureFailed(
                message: "La capture d'écran a échoué.",
                underlyingError: error
            )
        }

        // 6. Convertir CGImage en NSImage
        return NSImage(cgImage: image, size: mainDisplay.frame.size)
    }

    // MARK: - Permission Request

    /// Ouvre les Préférences Système à la bonne page
    static func openSystemPreferences() {
        if #available(macOS 13.0, *) {
            // macOS 13+ : Nouvelle URL pour Réglages Système
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            NSWorkspace.shared.open(url)
        } else {
            // macOS 12 : Ancienne URL pour Préférences Système
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Error Types

enum ScreenCaptureError: LocalizedError {
    case permissionDenied(message: String, instructionStep: InstructionStep)
    case permissionNotRequested(message: String, instructionStep: InstructionStep)
    case permissionRestricted(message: String)
    case noDisplayFound(message: String)
    case captureFailed(message: String, underlyingError: Error)
    case systemError(message: String, underlyingError: Error)

    enum InstructionStep {
        case openSystemPreferences
        case enablePermission
        case restartApp
    }

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message, _):
            return message
        case .permissionNotRequested(let message, _):
            return message
        case .permissionRestricted(let message):
            return message
        case .noDisplayFound(let message):
            return message
        case .captureFailed(let message, _):
            return message
        case .systemError(let message, _):
            return message
        }
    }

    /// Instructions détaillées pour l'utilisateur
    var userInstructions: String {
        switch self {
        case .permissionDenied(_, .openSystemPreferences),
             .permissionNotRequested(_, .openSystemPreferences):
            return """
            Pour autoriser la capture d'écran :

            1️⃣ Ouvrez les Réglages Système
            2️⃣ Allez dans "Confidentialité et sécurité"
            3️⃣ Cliquez sur "Enregistrement d'écran"
            4️⃣ Activez le bouton pour "Correcteur Pro"
            5️⃣ Relancez l'application

            Voulez-vous ouvrir les Réglages Système maintenant ?
            """

        case .permissionRestricted:
            return """
            L'enregistrement d'écran est désactivé par une politique système.

            Si vous utilisez un Mac professionnel, contactez votre administrateur système.
            """

        case .noDisplayFound:
            return """
            Aucun écran détecté.

            Vérifiez que :
            • Votre Mac a au moins un écran connecté
            • L'écran est allumé et détecté par macOS
            """

        case .captureFailed(_, let error):
            return """
            La capture d'écran a échoué.

            Erreur technique : \(error.localizedDescription)

            Essayez de :
            • Relancer l'application
            • Redémarrer votre Mac
            """

        case .systemError(_, let error):
            return """
            Erreur système lors de l'accès aux écrans.

            Erreur technique : \(error.localizedDescription)
            """
        }
    }

    /// Indique si on peut ouvrir les Réglages Système pour résoudre
    var canOpenSystemPreferences: Bool {
        switch self {
        case .permissionDenied, .permissionNotRequested:
            return true
        default:
            return false
        }
    }
}
```

**Validation** : La classe compile, les méthodes sont disponibles.

---

### **ÉTAPE 3 : Bouton de Test dans l'UI**

**Modifier : `Views/ChatView.swift` (HeaderView)**

Ajouter un bouton temporaire pour tester la capture :

```swift
// Dans HeaderView, à côté du menu de prompts
Button(action: {
    Task {
        // ⚠️ IMPORTANT : Appeler directement sendScreenCapture() du ViewModel
        // Ne PAS dupliquer la logique de capture ici
        await chatViewModel.sendScreenCapture(withPrompt: "Analyse cette capture d'écran.")
    }
}) {
    Image(systemName: "camera.fill")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.white.opacity(0.7))
}
.buttonStyle(.plain)
.help("Capturer l'écran")
```

**Validation** : Bouton visible, cliquable (mais capture échouera en mode debug).

---

### **ÉTAPE 4 : Intégration avec ChatViewModel**

**Modifier : `ViewModels/ChatViewModel.swift`**

Ajouter une méthode pour envoyer une capture d'écran :

```swift
/// Capture l'écran et envoie à ChatGPT avec un prompt
@MainActor
func sendScreenCapture(withPrompt customPrompt: String? = nil) async {
    guard let selectedConversationID,
          let index = conversations.firstIndex(where: { $0.id == selectedConversationID }) else {
        return
    }

    do {
        if #available(macOS 12.3, *) {
            // 1. Capturer l'écran
            let screenshot = try await ScreenCaptureService.captureMainScreen()
            print("📸 Capture d'écran réussie : \(screenshot.size)")

            // 2. Définir le prompt
            let prompt = customPrompt ?? "Analyse cette capture d'écran."

            // 3. ⚠️ IMPORTANT : Utiliser sendMessage() qui gère TOUT
            let success = sendMessage(prompt, images: [screenshot])
            if !success {
                print("❌ Échec de l'envoi du message")
                showErrorAlert(
                    title: "Échec de l'envoi",
                    message: "Impossible d'envoyer la capture d'écran à ChatGPT. Vérifiez votre connexion internet et votre clé API."
                )
            }
        }
    } catch let error as ScreenCaptureError {
        // ⚠️ Gestion détaillée des erreurs avec instructions utilisateur
        print("❌ Erreur capture : \(error.localizedDescription)")

        showErrorAlert(
            title: "Capture d'écran impossible",
            message: error.userInstructions,
            showOpenPreferencesButton: error.canOpenSystemPreferences
        )
    } catch {
        // Erreur inattendue
        print("❌ Erreur inattendue : \(error.localizedDescription)")
        showErrorAlert(
            title: "Erreur inattendue",
            message: "Une erreur inattendue s'est produite : \(error.localizedDescription)"
        )
    }
}

// MARK: - Alert Helper

/// Affiche une alerte à l'utilisateur
private func showErrorAlert(title: String, message: String, showOpenPreferencesButton: Bool = false) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning

    if showOpenPreferencesButton {
        alert.addButton(withTitle: "Ouvrir les Réglages")
        alert.addButton(withTitle: "Annuler")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // L'utilisateur a cliqué sur "Ouvrir les Réglages"
            if #available(macOS 12.3, *) {
                ScreenCaptureService.openSystemPreferences()
            }
        }
    } else {
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
```

**⚠️ BUGS ÉVITÉS** :
1. ✅ **Simplification maximale** : On utilise directement `sendMessage()` qui fait TOUT le travail
2. ✅ **Pas de doublon** : On n'ajoute PAS manuellement le message à la conversation (sendMessage le fait)
3. ✅ **Pas de risque d'oubli** : sendMessage gère automatiquement imageData, storage.save(), etc.
4. ✅ **Gestion d'erreurs complète** : Alertes utilisateur avec instructions détaillées
5. ✅ **Bouton "Ouvrir les Réglages"** : L'utilisateur peut résoudre les problèmes de permissions en 1 clic

**Validation** : La méthode compile et envoie correctement à l'API.

---

### **ÉTAPE 5 : Raccourci Clavier Global (optionnel)**

**Créer : `Utilities/GlobalHotKeyManager.swift`**

```swift
import Cocoa
import Carbon

class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()
    private var eventHandler: EventHandlerRef?

    /// Enregistrer un raccourci global (ex: Cmd+Shift+S)
    func registerHotKey(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        // Utilise Carbon Event Manager pour les raccourcis globaux
        // Note: Nécessite l'autorisation Accessibility

        var hotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("CRPR".fourCharCodeValue)
        hotKeyID.id = 1

        // Enregistrer le raccourci
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            print("✅ Raccourci global enregistré")
        } else {
            print("❌ Échec d'enregistrement du raccourci")
        }
    }
}

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for char in self.utf8 {
            result = result << 8 + FourCharCode(char)
        }
        return result
    }
}
```

**Validation** : Le raccourci est enregistré (mais ne fonctionnera qu'avec autorisation Accessibility).

---

### **ÉTAPE 6 : Build, Installation et Tests**

**1. Créer un build Archive (Release)**
```bash
cd "/Users/hadrienrose/Code/Correcteur Pro"
xcodebuild -scheme "Correcteur Pro" -configuration Release archive -archivePath build/CorrecteurPro.xcarchive
```

**2. Exporter l'app**
```bash
xcodebuild -exportArchive -archivePath build/CorrecteurPro.xcarchive -exportPath build -exportOptionsPlist ExportOptions.plist
```

**3. Créer ExportOptions.plist**

Créer ce fichier à la racine du projet :

**Fichier : `ExportOptions.plist`**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

**4. Copier dans /Applications**
```bash
cp -r "build/Correcteur Pro.app" /Applications/
```

**5. Autoriser manuellement**
- Ouvrir **Préférences Système > Confidentialité**
- Aller dans **Enregistrement d'écran**
- Cocher **Correcteur Pro**
- (Optionnel) Aller dans **Accessibilité** et cocher **Correcteur Pro**

**6. Lancer l'app depuis /Applications**
```bash
open "/Applications/Correcteur Pro.app"
```

**7. Tester la capture**
- Cliquer sur le bouton caméra dans l'interface
- Vérifier que la capture fonctionne
- Vérifier que l'image est envoyée à ChatGPT

---

## 🔄 Workflow de Développement Recommandé

### **Phase 1 : Développement UI (mode debug Xcode)**
- ✅ Créer les boutons et l'UI
- ✅ Implémenter la logique de traitement
- ✅ Tester avec des images statiques (déjà existantes)
- ✅ Vérifier l'envoi à l'API avec des images de test

### **Phase 2 : Test Capture Réelle (app installée)**
- ⚠️ Créer un build Release
- ⚠️ Installer dans /Applications
- ⚠️ Autoriser dans Préférences Système
- ⚠️ Tester la capture d'écran réelle
- ⚠️ Valider le workflow complet

### **Phase 3 : Retour en Mode Développement**
- ✅ Une fois la capture validée, revenir en mode debug
- ✅ Continuer le développement d'autres features
- ✅ Tester périodiquement avec l'app installée

---

## ⚠️ Points d'Attention & Pièges à Éviter

### **Autorisations & Configuration**

1. **Autorisations** : Les autorisations Screen Recording ne peuvent PAS être testées en mode debug Xcode
2. **Signature** : L'app doit être signée (même localement) pour obtenir les autorisations
3. **Redémarrage** : Après avoir autorisé l'app, il faut TOUJOURS la relancer
4. **macOS Version** : ScreenCaptureKit nécessite macOS 12.3+ (vérifier la version de l'utilisateur)
5. **Sandbox** : Le sandbox peut bloquer certaines fonctionnalités (désactiver temporairement si besoin)
6. **Info.plist** : TOUJOURS ajouter `NSScreenCaptureUsageDescription` sinon crash au runtime

---

## 📝 Résumé des Étapes

| Étape | Description | Testable en Debug? |
|-------|-------------|-------------------|
| 1 | Configuration Entitlements | ✅ Oui (compile) |
| 2 | Service Capture | ✅ Oui (compile uniquement) |
| 3 | Bouton UI | ✅ Oui |
| 4 | Intégration ChatViewModel | ✅ Oui (avec images statiques) |
| 5 | Raccourci Global | ❌ Non (nécessite app installée) |
| 6 | Tests Réels | ❌ Non (nécessite app installée) |

---

## ⚠️ Bugs Critiques à Éviter

### **1. 🐛 BUG : Dupliquer la logique d'envoi API**
- ❌ **NE PAS** créer manuellement le Message, ajouter à la conversation, appeler l'API, etc.
- ✅ **Solution** : Appeler uniquement `sendMessage(prompt, images: [screenshot])` qui fait TOUT
- **Pourquoi** : `sendMessage()` gère déjà imageData, storage.save(), API call, message de réponse, etc.

### **2. 🐛 BUG : Ajouter manuellement le message à la conversation**
- ❌ Si tu fais `conversations[index].messages.append(userMessage)`, tu auras un doublon
- ✅ **Solution** : `sendMessage()` ajoute déjà le message, ne rien faire manuellement

### **3. 🐛 BUG : Oublier la compression d'image**
- ❌ Les captures d'écran peuvent être TRÈS grosses (10-20 MB)
- ✅ **Solution** : `sendMessage()` appelle `convertImagesToImageData()` qui compresse automatiquement

### **4. 🐛 BUG : Mauvaise gestion async/await**
- ❌ Appeler `sendMessage()` sans `@MainActor` peut créer des problèmes
- ✅ **Solution** : Marquer `sendScreenCapture()` avec `@MainActor`

### **5. 🐛 BUG : Ne pas afficher d'erreur à l'utilisateur**
- ❌ Erreur silencieuse → L'utilisateur ne sait pas ce qui ne va pas
- ✅ **Solution** : Utiliser `showErrorAlert()` avec instructions détaillées et bouton "Ouvrir les Réglages"

### **6. 🐛 BUG : Ne pas gérer tous les cas d'erreur de permissions**
- ❌ Traiter toutes les erreurs de la même façon
- ✅ **Solution** : Utiliser `ScreenCaptureError` avec `userInstructions` spécifiques à chaque cas

---

## 🚨 Gestion des Erreurs de Permissions (CRITIQUE)

### **Scénarios d'erreur possibles**

#### **Scénario 1 : Permission jamais demandée** (`notDetermined`)
**Ce qui se passe** : L'utilisateur n'a jamais autorisé l'app
**Message affiché** :
```
Pour autoriser la capture d'écran :

1️⃣ Ouvrez les Réglages Système
2️⃣ Allez dans "Confidentialité et sécurité"
3️⃣ Cliquez sur "Enregistrement d'écran"
4️⃣ Activez le bouton pour "Correcteur Pro"
5️⃣ Relancez l'application

[Bouton: Ouvrir les Réglages] [Bouton: Annuler]
```

#### **Scénario 2 : Permission refusée** (`denied`)
**Ce qui se passe** : L'utilisateur a explicitement refusé
**Message affiché** : Identique au Scénario 1
**Action** : Bouton "Ouvrir les Réglages" → ouvre directement la bonne page

#### **Scénario 3 : Permission restreinte** (`restricted`)
**Ce qui se passe** : Politique système (MDM, contrôle parental)
**Message affiché** :
```
L'enregistrement d'écran est désactivé par une politique système.

Si vous utilisez un Mac professionnel, contactez votre administrateur système.

[Bouton: OK]
```

#### **Scénario 4 : Aucun écran détecté** (`noDisplayFound`)
**Ce qui se passe** : Problème matériel
**Message affiché** :
```
Aucun écran détecté.

Vérifiez que :
• Votre Mac a au moins un écran connecté
• L'écran est allumé et détecté par macOS

[Bouton: OK]
```

#### **Scénario 5 : Échec de capture** (`captureFailed`)
**Ce qui se passe** : Erreur système inattendue
**Message affiché** :
```
La capture d'écran a échoué.

Erreur technique : [détails]

Essayez de :
• Relancer l'application
• Redémarrer votre Mac

[Bouton: OK]
```

### **Workflow de résolution pour l'utilisateur**

```
Utilisateur clique sur 🎥 Capture d'écran
         ↓
Permission refusée ?
         ↓ OUI
Alerte: "Capture d'écran impossible"
Instructions en 5 étapes
         ↓
[Bouton: Ouvrir les Réglages] cliqué
         ↓
Réglages Système s'ouvre automatiquement
sur la page "Enregistrement d'écran"
         ↓
Utilisateur active "Correcteur Pro"
         ↓
Message système: "Vous devez relancer l'app"
         ↓
Utilisateur relance l'app
         ↓
Capture fonctionne ✅
```

---

## 🚀 Prochaines Actions

1. ✅ Pusher le code actuel (FAIT)
2. 📝 Valider ce plan avec toi
3. 🔧 Implémenter ÉTAPE 1-4 (testables en debug)
4. 📦 Créer un build Release et installer dans /Applications
5. ✅ Tester la capture réelle avec autorisations
6. 🎯 Implémenter le raccourci clavier global

---

## ✅ Checklist de Vérification Finale

Avant de tester, assure-toi que :

### **Configuration**
- [ ] `Correcteur Pro.entitlements` contient bien `com.apple.security.personal-information.screen-recording`
- [ ] `Info.plist` contient `NSScreenCaptureUsageDescription`
- [ ] `ExportOptions.plist` créé avec ton Team ID

### **Code**
- [ ] `ScreenCaptureService.swift` créé dans `Utilities/`
- [ ] `checkScreenRecordingPermission()` implémentée
- [ ] `captureMainScreen()` retourne un `NSImage`
- [ ] Bouton de test ajouté dans `ChatView.swift` (HeaderView)
- [ ] `sendScreenCapture()` ajoutée dans `ChatViewModel.swift`
- [ ] **CRITIQUE** : `sendScreenCapture()` appelle uniquement `sendMessage()` (pas de duplication de logique)
- [ ] **CRITIQUE** : On n'ajoute PAS manuellement le message à la conversation (sendMessage le fait)
- [ ] **CRITIQUE** : Pas d'appel manuel à `storage.save()` (sendMessage le fait)

### **Build & Installation**
- [ ] Build Archive créé sans erreurs
- [ ] App exportée dans `build/`
- [ ] App copiée dans `/Applications/`
- [ ] App autorisée dans **Préférences Système > Enregistrement d'écran**
- [ ] App relancée depuis `/Applications/`

### **Tests**
- [ ] Bouton caméra visible dans l'interface
- [ ] Clic sur le bouton déclenche la capture
- [ ] Aucune erreur de permission dans la console
- [ ] Image capturée visible dans le chat
- [ ] Message envoyé à ChatGPT avec l'image
- [ ] Réponse de ChatGPT reçue
- [ ] Conversation sauvegardée correctement

---

## 🔧 Dépannage Rapide

### **Erreurs de permissions**

#### ❌ **Alerte: "L'autorisation d'enregistrement d'écran a été refusée"**
**Cause** : L'utilisateur a refusé ou n'a jamais autorisé l'app
**Solution** :
1. Clique sur "Ouvrir les Réglages" dans l'alerte
2. Active le bouton pour "Correcteur Pro" dans "Enregistrement d'écran"
3. **IMPORTANT** : Quitte COMPLÈTEMENT l'app (Cmd+Q)
4. Relance l'app depuis `/Applications/`

#### ❌ **"Autorisation refusée" même après avoir autorisé l'app**
**Cause** : L'app n'a pas été relancée après autorisation
**Solution** : Quitte COMPLÈTEMENT l'app (Cmd+Q) puis relance-la

#### ❌ **"L'enregistrement d'écran est désactivé par une politique système"**
**Cause** : MDM ou contrôle parental bloque la fonctionnalité
**Solution** : Si Mac professionnel, contacte ton administrateur système. Sinon, vérifie les Restrictions dans Préférences Système

#### ❌ **"Aucun écran détecté"**
**Cause** : Problème matériel ou app lancée depuis Xcode
**Solution** :
- Vérifie que l'app est bien installée dans `/Applications/` (pas lancée depuis Xcode)
- Vérifie qu'au moins un écran est connecté et allumé

### **Erreurs de build/installation**

#### ❌ **Build Archive échoue**
**Solution** : Vérifie ton Team ID dans Xcode > Signing & Capabilities

#### ❌ **"No such file or directory" lors de xcodebuild**
**Solution** : Crée le fichier `ExportOptions.plist` à la racine du projet avec ton Team ID

#### ❌ **L'app ne s'ouvre pas après installation**
**Solution** : Ouvre le Terminal et lance `open "/Applications/Correcteur Pro.app"`

### **Erreurs d'envoi API**

#### ❌ **L'image n'apparaît pas dans ChatGPT**
**Cause** : Bug dans le code (imageData non converti)
**Solution** : Vérifie que `sendMessage()` est bien appelé avec `images: [screenshot]`

#### ❌ **Message disparaît au redémarrage**
**Cause** : Conversation non sauvegardée
**Solution** : Vérifie que `sendMessage()` est utilisé (il sauvegarde automatiquement)

#### ❌ **API retourne une erreur 400**
**Cause** : Image trop grosse
**Solution** : Vérifie que `sendMessage()` appelle `convertImagesToImageData()` qui compresse automatiquement

#### ❌ **"Échec de l'envoi du message"**
**Cause** : Pas de connexion internet ou clé API invalide
**Solution** :
- Vérifie ta connexion internet
- Vérifie que ta clé API OpenAI est valide dans les réglages

### **Erreurs de développement**

#### ❌ **Capture échoue en mode debug Xcode**
**Cause** : NORMAL - Les permissions Screen Recording ne fonctionnent PAS en mode debug
**Solution** : Crée un build Release et installe dans `/Applications/`

#### ❌ **"Cannot find 'ScreenCaptureService' in scope"**
**Cause** : Fichier `ScreenCaptureService.swift` pas créé ou pas ajouté au target
**Solution** : Vérifie que le fichier existe dans `Utilities/` et est coché dans le target

---

**Question pour toi** : Veux-tu qu'on implémente d'abord toutes les étapes 1-4 en mode debug (sans pouvoir tester la capture réelle), puis qu'on fasse un build pour tester ? Ou préfères-tu qu'on fasse étape par étape avec des builds intermédiaires ?
