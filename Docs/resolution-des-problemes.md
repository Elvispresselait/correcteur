# Plan : Résolution des problèmes Menu Bar App

## Problèmes identifiés

### Problème 1 : Capture d'écran ne s'envoie pas
- **Symptôme** : Après sélection de zone, l'image n'arrive pas dans l'app
- **Contexte** : L'overlay de sélection fonctionne, mais l'image disparaît

### Problème 2 : Fenêtre ne s'ouvre pas après capture
- **Symptôme** : Correcteur Pro reste en arrière-plan après capture
- **Attendu** : La fenêtre devrait s'ouvrir automatiquement

### Problème 3 : Clic sur icône Dock ne fonctionne pas
- **Symptôme** : Cliquer sur l'icône Dock n'ouvre pas la fenêtre
- **Attendu** : Devrait ouvrir/activer la fenêtre principale
- **Contournement actuel** : Menu bar > "Ouvrir Correcteur Pro"

---

## Étape 1 : Recherches Internet ✅ TERMINÉ

### 1.1 Problème du clic Dock - CAUSE TROUVÉE

**Bug connu** : `applicationShouldHandleReopen` ne fonctionne PAS avec `@NSApplicationDelegateAdaptor` dans les apps SwiftUI lifecycle !

> "applicationShouldHandleReopen is never called in a SwiftUI lifecycle app. Even if you implement the @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate, that method is never called."

**Sources** :
- [Apple Developer Forums - FB9754295](https://github.com/feedback-assistant/reports/issues/246)
- [Stack Overflow - SwiftUI dock icon click](https://stackoverflow.com/questions/71904374/swiftui-how-can-you-make-your-app-come-to-the-front-when-clicking-on-the-dock-i)

**Solution 1** : Manuellement définir le delegate au lancement
```swift
func applicationDidFinishLaunching(_ aNotification: Notification) {
    NSApplication.shared.delegate = self  // <-- CRUCIAL
}
```

**Solution 2** : Utiliser `applicationWillBecomeActive` au lieu de `applicationShouldHandleReopen`
```swift
func applicationWillBecomeActive(_ notification: Notification) {
    (notification.object as? NSApplication)?.windows.first?.makeKeyAndOrderFront(self)
}
```

### 1.2 Ouverture de fenêtre depuis MenuBarExtra

**Pattern correct** trouvé sur [Stack Overflow](https://stackoverflow.com/questions/78009398/macos-desktop-app-with-swiftui-how-to-open-window-from-menubar-menubarextra) :
```swift
func openConfigWindow() {
    NSApplication.shared.activate(ignoringOtherApps: true)
    openWindow(id: "content-view")  // Utiliser openWindow, pas les notifications!
}
```

**Problème identifié** : On ne peut PAS utiliser `openWindow(id:)` depuis AppDelegate car c'est un `@Environment` disponible uniquement dans les Views SwiftUI.

### 1.3 Communication AppDelegate ↔ SwiftUI

Le problème est que :
- AppDelegate ne peut pas accéder à `@Environment(\.openWindow)`
- NotificationCenter ne fonctionne pas si ContentView n'existe pas (fenêtre fermée)

**Solution** : Stocker une référence à `openWindow` dans un singleton accessible

---

## Étape 2 : Analyse du code actuel

### 2.1 Diagnostic du flux de capture
- [ ] Vérifier si `openWindowAndSendImage()` est bien appelé
- [ ] Vérifier si la notification `.screenCaptured` est bien postée
- [ ] Vérifier si ContentView reçoit la notification

### 2.2 Diagnostic du clic Dock
- [ ] Vérifier si `applicationShouldHandleReopen` est appelé
- [ ] Vérifier si la notification `.openMainWindow` est postée
- [ ] Vérifier pourquoi la fenêtre ne s'ouvre pas

### 2.3 Ajouter des logs de debug
- [ ] Log à chaque étape du flux de capture
- [ ] Log dans `applicationShouldHandleReopen`
- [ ] Log dans le handler de `.openMainWindow`

---

## Étape 3 : Correction du clic Dock

### 3.1 Cause confirmée
`applicationShouldHandleReopen` n'est JAMAIS appelé car SwiftUI intercepte les appels delegate.

### 3.2 Solution à implémenter

**Option A** : Ajouter `NSApplication.shared.delegate = self` dans `applicationDidFinishLaunching`
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.delegate = self  // AJOUTER CETTE LIGNE
    // ... reste du code
}
```

**Option B** : Utiliser `applicationWillBecomeActive` (plus fiable)
```swift
func applicationWillBecomeActive(_ notification: Notification) {
    // Réactiver la fenêtre au clic Dock
    if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
        window.makeKeyAndOrderFront(nil)
    }
}
```

---

## Étape 4 : Correction de l'ouverture de fenêtre après capture

### 4.1 Cause confirmée
La notification `.openMainWindow` est postée mais personne n'écoute car la fenêtre (et donc ContentView) n'existe pas.

### 4.2 Solution à implémenter

Créer un **WindowManager** singleton qui stocke une référence à `openWindow` :

```swift
// WindowManager.swift
class WindowManager {
    static let shared = WindowManager()
    var openWindowAction: ((String) -> Void)?
}

// Dans CorrecteurProApp.swift, dans le body:
WindowGroup(id: "main") {
    ContentView()
        .onAppear {
            // Capturer openWindow une seule fois
            WindowManager.shared.openWindowAction = { id in
                // Utiliser l'URL scheme comme fallback
                if let url = URL(string: "correcteurpro://open") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
}

// Dans AppDelegate, utiliser:
func openMainWindow() {
    NSApp.activate(ignoringOtherApps: true)

    // Essayer d'abord de réutiliser une fenêtre existante
    if let window = NSApp.windows.first(where: {
        $0.contentView != nil && $0.frame.width > 300
    }) {
        window.makeKeyAndOrderFront(nil)
    } else {
        // Forcer l'ouverture via URL scheme
        WindowManager.shared.openWindowAction?("main")
    }
}
```

**Alternative plus simple** : Utiliser URL scheme `handlesExternalEvents`

---

## Étape 5 : Correction de l'envoi d'image

### 5.1 Cause confirmée
L'image est stockée dans `pendingCapturedImage` mais `consumePendingImage()` n'est appelé que si ContentView existe ET fait son `onAppear`.

### 5.2 Solution à implémenter

Le flux actuel est correct MAIS il faut s'assurer que :
1. La fenêtre s'ouvre vraiment (Étape 4)
2. ContentView fait bien son `onAppear` après ouverture
3. `checkForPendingImage()` est bien appelé

**Amélioration** : Augmenter le délai de retry ou utiliser un observer pour détecter quand ContentView est prête.

---

## Étape 6 : Plan d'implémentation

### 6.1 Modifications dans `CorrecteurProApp.swift`

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // FIX 1: Restaurer le delegate pour que applicationShouldHandleReopen fonctionne
        NSApplication.shared.delegate = self

        // ... reste du code existant
    }

    // FIX 2: Ajouter applicationWillBecomeActive comme backup
    func applicationWillBecomeActive(_ notification: Notification) {
        // Si on clique sur le Dock et qu'il n'y a pas de fenêtre visible
        let hasVisibleWindow = NSApp.windows.contains {
            $0.isVisible && $0.canBecomeKey
        }
        if !hasVisibleWindow {
            openMainWindowDirectly()
        }
    }

    // FIX 3: Nouvelle méthode pour ouvrir la fenêtre directement
    private func openMainWindowDirectly() {
        NSApp.activate(ignoringOtherApps: true)

        // Chercher une fenêtre existante à réactiver
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
        // Note: Si aucune fenêtre, SwiftUI devrait en créer une automatiquement
        // grâce à WindowGroup
    }
}
```

### 6.2 Tests à effectuer

- [ ] Clic Dock avec fenêtre fermée → doit ouvrir la fenêtre
- [ ] Clic Dock avec fenêtre minimisée → doit la restaurer
- [ ] Capture ⌥⇧S avec app en arrière-plan → doit ouvrir + afficher image
- [ ] Capture ⌥⇧X avec fenêtre fermée → doit ouvrir + afficher image
- [ ] Menu bar "Ouvrir Correcteur Pro" → doit fonctionner comme avant

---

## Notes techniques

### Flux actuel (potentiellement cassé)
```
Hotkey → SelectionCapture → openWindowAndSendImage()
                                    ↓
                     NSApp.activate() + post(.openMainWindow)
                                    ↓
                     ❌ Personne n'écoute si fenêtre fermée
                                    ↓
                     sendImageWithRetry() → post(.screenCaptured)
                                    ↓
                     ❌ ContentView n'existe pas → image perdue
```

### Flux souhaité
```
Hotkey → SelectionCapture → openWindowAndSendImage()
                                    ↓
                     Ouvrir/créer fenêtre (méthode fiable)
                                    ↓
                     Attendre que ContentView soit prête
                                    ↓
                     Envoyer l'image
```
