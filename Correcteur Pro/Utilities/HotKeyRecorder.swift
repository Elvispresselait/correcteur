//
//  HotKeyRecorder.swift
//  Correcteur Pro
//
//  Composant SwiftUI pour enregistrer des raccourcis clavier
//

import SwiftUI
import Carbon

struct HotKeyRecorder: View {
    let label: String
    @Binding var hotKey: String
    let onHotKeyChanged: (() -> Void)?

    @State private var isRecording = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(label)

            Spacer()

            Button(action: {
                isRecording = true
                isFocused = true
            }) {
                HStack(spacing: 4) {
                    if isRecording {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                        Text("Appuyez sur des touches...")
                    } else {
                        Text(hotKey)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isRecording ? Color.red.opacity(0.1) : Color.gray.opacity(0.2))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.red : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .onKeyPress { press in
                if isRecording {
                    handleKeyPress(press)
                    return .handled
                }
                return .ignored
            }

            if !isRecording && hotKey != "⌥⇧S" && hotKey != "⌥⇧A" && hotKey != "⌥⇧X" {
                Button(action: resetToDefault) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Réinitialiser")
            }
        }
    }

    // MARK: - Key Press Handling

    private func handleKeyPress(_ press: KeyPress) {
        // Extraire les modificateurs
        var modifiers: [String] = []

        if press.modifiers.contains(.control) {
            modifiers.append("⌃")
        }
        if press.modifiers.contains(.option) {
            modifiers.append("⌥")
        }
        if press.modifiers.contains(.shift) {
            modifiers.append("⇧")
        }
        if press.modifiers.contains(.command) {
            modifiers.append("⌘")
        }

        // Obtenir la touche principale
        let key = press.key
        let keyString = convertKeyToSymbol(key)

        // Construire le raccourci
        let newHotKey = modifiers.joined() + keyString

        // Valider le raccourci
        if isValidHotKey(newHotKey) {
            hotKey = newHotKey
            isRecording = false
            isFocused = false
            onHotKeyChanged?()
        } else {
            // Raccourci invalide, réinitialiser
            isRecording = false
            isFocused = false
        }
    }

    // MARK: - Key Conversion

    private func convertKeyToSymbol(_ key: KeyEquivalent) -> String {
        switch key {
        case "a": return "A"
        case "b": return "B"
        case "c": return "C"
        case "d": return "D"
        case "e": return "E"
        case "f": return "F"
        case "g": return "G"
        case "h": return "H"
        case "i": return "I"
        case "j": return "J"
        case "k": return "K"
        case "l": return "L"
        case "m": return "M"
        case "n": return "N"
        case "o": return "O"
        case "p": return "P"
        case "q": return "Q"
        case "r": return "R"
        case "s": return "S"
        case "t": return "T"
        case "u": return "U"
        case "v": return "V"
        case "w": return "W"
        case "x": return "X"
        case "y": return "Y"
        case "z": return "Z"
        case "0": return "0"
        case "1": return "1"
        case "2": return "2"
        case "3": return "3"
        case "4": return "4"
        case "5": return "5"
        case "6": return "6"
        case "7": return "7"
        case "8": return "8"
        case "9": return "9"
        case " ": return "Space"
        case "\t": return "Tab"
        case "\r": return "↩"
        case "\u{1B}": return "Esc"
        default: return key.character.uppercased()
        }
    }

    // MARK: - Validation

    private func isValidHotKey(_ hotKey: String) -> Bool {
        // Doit contenir au moins un modificateur
        let hasModifier = hotKey.contains("⌃") || hotKey.contains("⌥") ||
                         hotKey.contains("⇧") || hotKey.contains("⌘")

        // Ne doit pas être vide
        let isNotEmpty = !hotKey.isEmpty

        // Ne doit pas être un raccourci système critique
        let systemShortcuts = [
            "⌘Q",  // Quitter
            "⌘W",  // Fermer fenêtre
            "⌘N",  // Nouvelle fenêtre
            "⌘T",  // Nouvel onglet
            "⌘,",  // Préférences
            "⌘H",  // Cacher
            "⌘M",  // Minimiser
            "⌘P",  // Imprimer
            "⌘S",  // Sauvegarder
            "⌘O",  // Ouvrir
            "⌘A",  // Tout sélectionner
            "⌘C",  // Copier
            "⌘V",  // Coller
            "⌘X",  // Couper
            "⌘Z",  // Annuler
            "⌘⇧Z", // Rétablir
            "⌘Space", // Spotlight
        ]

        let isNotSystemShortcut = !systemShortcuts.contains(hotKey)

        return hasModifier && isNotEmpty && isNotSystemShortcut
    }

    // MARK: - Reset

    private func resetToDefault() {
        // Déterminer le raccourci par défaut selon le label
        if label.contains("principal") {
            hotKey = "⌥⇧S"
        } else if label.contains("tous") {
            hotKey = "⌥⇧A"
        } else if label.contains("zone") {
            hotKey = "⌥⇧X"
        }
        onHotKeyChanged?()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HotKeyRecorder(
            label: "Capture écran principal",
            hotKey: .constant("⌥⇧S"),
            onHotKeyChanged: nil
        )

        HotKeyRecorder(
            label: "Capture tous les écrans",
            hotKey: .constant("⌥⇧A"),
            onHotKeyChanged: nil
        )

        HotKeyRecorder(
            label: "Capture zone sélectionnée",
            hotKey: .constant("⌥⇧X"),
            onHotKeyChanged: nil
        )
    }
    .padding()
    .frame(width: 500)
}
