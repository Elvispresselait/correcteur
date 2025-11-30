//
//  InterfacePreferencesView.swift
//  Correcteur Pro
//
//  Onglet des préférences d'interface
//

import SwiftUI
import ServiceManagement

struct InterfacePreferencesView: View {

    @ObservedObject var prefsManager = PreferencesManager.shared
    @StateObject private var debugLogger = DebugLogger.shared
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            // SECTION : Thème
            Section("Thème") {
                Picker("Apparence", selection: $prefsManager.preferences.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: prefsManager.preferences.theme) { _, newTheme in
                    prefsManager.save()
                    applyTheme(newTheme)
                }

                Text("L'aperçu du thème sera visible au prochain redémarrage de l'application")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // SECTION : Texte
            Section("Texte") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Taille de la police")
                        Spacer()
                        Text("\(Int(prefsManager.preferences.fontSize)) pt")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $prefsManager.preferences.fontSize, in: 12...18, step: 1)
                        .onChange(of: prefsManager.preferences.fontSize) { _, _ in
                            prefsManager.save()
                        }

                    // Aperçu de la taille
                    Text("Exemple de texte avec la taille sélectionnée")
                        .font(.system(size: prefsManager.preferences.fontSize))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            // SECTION : Fenêtre
            Section("Fenêtre") {
                Picker("Position au démarrage", selection: $prefsManager.preferences.windowPosition) {
                    ForEach(WindowPosition.allCases, id: \.self) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .onChange(of: prefsManager.preferences.windowPosition) { _, _ in
                    prefsManager.save()
                }

                Toggle("Lancer au démarrage du Mac", isOn: $prefsManager.preferences.launchAtLogin)
                    .onChange(of: prefsManager.preferences.launchAtLogin) { _, newValue in
                        prefsManager.save()
                        configureLaunchAtLogin(newValue)
                    }

                if let error = launchAtLoginError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle("Afficher dans le Dock", isOn: $prefsManager.preferences.showInDock)
                    .onChange(of: prefsManager.preferences.showInDock) { _, newValue in
                        prefsManager.save()
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }

                Text("L'icône de menu bar reste toujours visible. Désactivez cette option pour masquer l'icône du Dock.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // SECTION : Développeur
            Section("Développeur") {
                Toggle("Afficher la console de debug", isOn: $debugLogger.isEnabled)
                    .onChange(of: debugLogger.isEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "debugConsoleEnabled")
                    }

                if debugLogger.isEnabled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("La console s'affiche en bas de la fenêtre principale")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Effacer les logs") {
                        debugLogger.clear()
                    }
                    .buttonStyle(.bordered)
                }

                Text("La console de debug affiche les logs en temps réel : appels API, réponses ChatGPT, erreurs, etc.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            // Synchroniser l'état avec SMAppService au chargement
            syncLaunchAtLoginState()
        }
    }

    // MARK: - Helper Methods

    /// Applique le thème sélectionné (Clair/Sombre/Auto)
    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto:
            NSApp.appearance = nil // Utiliser le thème système
        }
    }

    /// Configure le lancement au démarrage avec SMAppService (macOS 13+)
    private func configureLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
                DebugLogger.shared.log("✅ Lancement au démarrage activé", category: "System")
            } else {
                try SMAppService.mainApp.unregister()
                DebugLogger.shared.log("❌ Lancement au démarrage désactivé", category: "System")
            }
        } catch {
            DebugLogger.shared.log("⚠️ Erreur launch at login: \(error.localizedDescription)", category: "System")

            // Message d'erreur user-friendly
            if error.localizedDescription.contains("Operation not permitted") ||
               error.localizedDescription.contains("code signing") {
                launchAtLoginError = "Nécessite une signature valide (non disponible en dev)"
            } else {
                launchAtLoginError = error.localizedDescription
            }

            // Remettre l'état précédent en cas d'erreur
            DispatchQueue.main.async {
                prefsManager.preferences.launchAtLogin = !enabled
                prefsManager.save()
            }
        }
    }

    /// Synchronise l'état de la préférence avec SMAppService
    private func syncLaunchAtLoginState() {
        let currentStatus = SMAppService.mainApp.status
        let isEnabled = currentStatus == .enabled

        if prefsManager.preferences.launchAtLogin != isEnabled {
            prefsManager.preferences.launchAtLogin = isEnabled
            prefsManager.save()
            DebugLogger.shared.log("🔄 État launch at login synchronisé: \(isEnabled)", category: "System")
        }
    }
}

#Preview {
    InterfacePreferencesView()
        .frame(width: 600, height: 400)
}
