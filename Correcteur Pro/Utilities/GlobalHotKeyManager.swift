import Cocoa
import Carbon

/// Gestionnaire de raccourcis clavier globaux pour capturer l'écran
class GlobalHotKeyManager {

    // MARK: - Properties

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    /// Callbacks pour chaque type de capture
    var onMainDisplayCapture: (() -> Void)?
    var onAllDisplaysCapture: (() -> Void)?
    var onSelectionCapture: (() -> Void)?

    // MARK: - Singleton

    static let shared = GlobalHotKeyManager()

    private init() {}

    // MARK: - Registration

    /// Enregistre tous les raccourcis depuis les préférences
    func registerAllHotKeys() {
        // Désenregistrer les anciens raccourcis
        unregisterAllHotKeys()

        // Installer le event handler une seule fois
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

            // Récupérer l'ID du raccourci pressé
            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent,
                            EventParamName(kEventParamDirectObject),
                            EventParamType(typeEventHotKeyID),
                            nil,
                            MemoryLayout<EventHotKeyID>.size,
                            nil,
                            &hotKeyID)

            // Exécuter le callback approprié
            DispatchQueue.main.async {
                switch hotKeyID.id {
                case 1: manager.onMainDisplayCapture?()
                case 2: manager.onAllDisplaysCapture?()
                case 3: manager.onSelectionCapture?()
                default: break
                }
            }

            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        // Récupérer les préférences
        let prefs = PreferencesManager.shared.preferences

        // Enregistrer les 3 raccourcis
        registerHotKey(id: 1, hotKeyString: prefs.hotKeyMainDisplay, name: "Écran principal")
        registerHotKey(id: 2, hotKeyString: prefs.hotKeyAllDisplays, name: "Tous les écrans")
        registerHotKey(id: 3, hotKeyString: prefs.hotKeySelection, name: "Zone sélectionnée")
    }

    /// Enregistre un raccourci individuel
    private func registerHotKey(id: UInt32, hotKeyString: String, name: String) {
        guard let (keyCode, modifiers) = parseHotKey(hotKeyString) else {
            print("⚠️ Impossible de parser le raccourci '\(hotKeyString)' pour \(name)")
            return
        }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("CPRO".fourCharCodeValue)
        hotKeyID.id = id

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode,
                                        modifiers,
                                        hotKeyID,
                                        GetApplicationEventTarget(),
                                        0,
                                        &hotKeyRef)

        if status != noErr {
            print("❌ Échec de l'enregistrement du raccourci \(name) : \(status)")
        } else if let ref = hotKeyRef {
            hotKeyRefs.append(ref)
            print("✅ Raccourci global enregistré : \(hotKeyString) pour \(name)")
        }
    }

    /// Parse une chaîne de raccourci (ex: "⌥⇧S") en keyCode + modifiers
    private func parseHotKey(_ hotKeyString: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        var modifiers: UInt32 = 0
        var keyChar: Character?

        for char in hotKeyString {
            switch char {
            case "⌃": modifiers |= UInt32(controlKey)
            case "⌥": modifiers |= UInt32(optionKey)
            case "⇧": modifiers |= UInt32(shiftKey)
            case "⌘": modifiers |= UInt32(cmdKey)
            default:
                keyChar = char
            }
        }

        guard let key = keyChar else { return nil }

        // Map des touches vers leurs keycodes
        let keyCodeMap: [Character: UInt32] = [
            "S": 1, "s": 1,
            "A": 0, "a": 0,
            "X": 7, "x": 7,
            "C": 8, "c": 8,
            "D": 2, "d": 2,
            "E": 14, "e": 14,
            "F": 3, "f": 3,
            "G": 5, "g": 5,
            "H": 4, "h": 4,
            "I": 34, "i": 34,
            "J": 38, "j": 38,
            "K": 40, "k": 40,
            "L": 37, "l": 37,
            "M": 46, "m": 46,
            "N": 45, "n": 45,
            "O": 31, "o": 31,
            "P": 35, "p": 35,
            "Q": 12, "q": 12,
            "R": 15, "r": 15,
            "T": 17, "t": 17,
            "U": 32, "u": 32,
            "V": 9, "v": 9,
            "W": 13, "w": 13,
            "Y": 16, "y": 16,
            "Z": 6, "z": 6,
        ]

        guard let keyCode = keyCodeMap[key] else {
            print("⚠️ Keycode introuvable pour '\(key)'")
            return nil
        }

        return (keyCode, modifiers)
    }

    /// Désenregistre tous les raccourcis
    func unregisterAllHotKeys() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        print("✅ Tous les raccourcis globaux désenregistrés")
    }

    deinit {
        unregisterAllHotKeys()
    }
}

// MARK: - String Extension

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: .macOSRoman) {
            data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                let pointer = bytes.bindMemory(to: UInt8.self)
                for i in 0..<min(4, pointer.count) {
                    result = result << 8 + FourCharCode(pointer[i])
                }
            }
        }
        return result
    }
}
