//
//  CapturePreferencesView.swift
//  Correcteur Pro
//
//  Onglet des préférences de capture d'écran
//

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
            // SECTION : Sélection de l'écran
            Section("Écran à capturer") {
                Picker("Mode de capture", selection: $prefsManager.preferences.captureMode) {
                    ForEach(CaptureMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .onChange(of: prefsManager.preferences.captureMode) { _, _ in
                    prefsManager.save()
                }

                // Si mode "Écran sélectionné", afficher la liste des écrans
                if prefsManager.preferences.captureMode == .specificDisplay {
                    if availableDisplays.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Détection des écrans...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Picker("Écran", selection: $prefsManager.preferences.selectedDisplayID) {
                            ForEach(availableDisplays) { display in
                                Text("\(display.name) (\(display.resolution))")
                                    .tag(display.id as CGDirectDisplayID?)
                            }
                        }
                        .onChange(of: prefsManager.preferences.selectedDisplayID) { _, _ in
                            prefsManager.save()
                        }
                    }
                }

                Text("Choisissez quel écran capturer lorsque vous utilisez le raccourci clavier.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // SECTION : Qualité
            Section("Qualité") {
                Picker("Compression", selection: $prefsManager.preferences.compressionQuality) {
                    ForEach(CompressionQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .onChange(of: prefsManager.preferences.compressionQuality) { _, _ in
                    prefsManager.save()
                }

                // Informations sur la compression
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Ratio de compression : \(Int(prefsManager.preferences.compressionQuality.compressionRatio * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Picker("Format", selection: $prefsManager.preferences.outputFormat) {
                    ForEach(CaptureImageFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .onChange(of: prefsManager.preferences.outputFormat) { _, _ in
                    prefsManager.save()
                }

                Text("Une compression élevée réduit la taille du fichier tout en conservant une bonne qualité pour GPT-4o Vision.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // SECTION : Options
            Section("Options") {
                Toggle("Envoi automatique après capture", isOn: $prefsManager.preferences.autoSendOnCapture)
                    .onChange(of: prefsManager.preferences.autoSendOnCapture) { _, _ in
                        prefsManager.save()
                    }

                Text("Envoie automatiquement l'image pour correction dès la capture terminée.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Son de notification après capture", isOn: $prefsManager.preferences.playsSoundAfterCapture)
                    .onChange(of: prefsManager.preferences.playsSoundAfterCapture) { _, _ in
                        prefsManager.save()
                    }

                Toggle("Curseur visible dans la capture", isOn: $prefsManager.preferences.showsCursorInCapture)
                    .onChange(of: prefsManager.preferences.showsCursorInCapture) { _, _ in
                        prefsManager.save()
                    }
            }

            // SECTION : Raccourcis clavier
            Section("Raccourcis clavier") {
                VStack(alignment: .leading, spacing: 12) {
                    HotKeyRecorder(
                        label: "Capture écran principal/sélectionné",
                        hotKey: $prefsManager.preferences.hotKeyMainDisplay,
                        onHotKeyChanged: {
                            prefsManager.save()
                            reregisterHotKeys()
                        }
                    )

                    HotKeyRecorder(
                        label: "Capture tous les écrans",
                        hotKey: $prefsManager.preferences.hotKeyAllDisplays,
                        onHotKeyChanged: {
                            prefsManager.save()
                            reregisterHotKeys()
                        }
                    )

                    HotKeyRecorder(
                        label: "Capture zone sélectionnée",
                        hotKey: $prefsManager.preferences.hotKeySelection,
                        onHotKeyChanged: {
                            prefsManager.save()
                            reregisterHotKeys()
                        }
                    )
                }

                Text("Cliquez sur un raccourci pour l'enregistrer. Appuyez sur Échap pour annuler.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadAvailableDisplays()
        }
    }

    // MARK: - Helper Methods

    /// Détecte et charge la liste des écrans disponibles
    private func loadAvailableDisplays() {
        Task {
            if #available(macOS 12.3, *) {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                    await MainActor.run {
                        availableDisplays = content.displays.enumerated().map { index, display in
                            DisplayInfo(
                                id: display.displayID,
                                name: "Écran \(index + 1)",
                                resolution: "\(Int(display.width))x\(Int(display.height))"
                            )
                        }

                        // Sélectionner le premier écran par défaut si aucun n'est sélectionné
                        if prefsManager.preferences.selectedDisplayID == nil,
                           let firstDisplay = availableDisplays.first {
                            prefsManager.preferences.selectedDisplayID = firstDisplay.id
                            prefsManager.save()
                        }
                    }

                    print("✅ \(availableDisplays.count) écran(s) détecté(s)")
                } catch {
                    print("❌ Erreur lors de la détection des écrans : \(error)")
                }
            }
        }
    }

    /// Réenregistre les raccourcis clavier globaux
    private func reregisterHotKeys() {
        // Réenregistrer tous les raccourcis avec les nouvelles valeurs
        GlobalHotKeyManager.shared.registerAllHotKeys()
        print("✅ Raccourcis mis à jour en direct :")
        print("  - Écran principal : \(prefsManager.preferences.hotKeyMainDisplay)")
        print("  - Tous les écrans : \(prefsManager.preferences.hotKeyAllDisplays)")
        print("  - Zone sélectionnée : \(prefsManager.preferences.hotKeySelection)")
    }
}

#Preview {
    CapturePreferencesView()
        .frame(width: 600, height: 400)
}
