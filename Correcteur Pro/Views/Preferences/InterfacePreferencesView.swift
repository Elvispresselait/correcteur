//
//  InterfacePreferencesView.swift
//  Correcteur Pro
//
//  Onglet des préférences d'interface
//

import SwiftUI

struct InterfacePreferencesView: View {

    @ObservedObject var prefsManager = PreferencesManager.shared
    @StateObject private var debugLogger = DebugLogger.shared

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

                Text("Cette option nécessite l'accès aux autorisations système")
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

    /// Configure le lancement au démarrage (helper pour SMLoginItemSetEnabled)
    private func configureLaunchAtLogin(_ enabled: Bool) {
        // TODO: Implémenter avec SMAppService (macOS 13+) ou SMLoginItemSetEnabled
        print(enabled ? "✅ Lancement au démarrage activé" : "❌ Lancement au démarrage désactivé")
    }
}

#Preview {
    InterfacePreferencesView()
        .frame(width: 600, height: 400)
}
