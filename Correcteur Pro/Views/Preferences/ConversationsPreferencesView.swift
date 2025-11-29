//
//  ConversationsPreferencesView.swift
//  Correcteur Pro
//
//  Onglet des préférences de conversations
//

import SwiftUI
import UniformTypeIdentifiers

struct ConversationsPreferencesView: View {

    @ObservedObject var prefsManager = PreferencesManager.shared
    @State private var showingFolderPicker = false
    @State private var editedPrompt: String = ""

    var body: some View {
        Form {
            // SECTION : Prompt Système
            Section("Prompt Système") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instructions envoyées à ChatGPT pour chaque conversation")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $editedPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150, maxHeight: 250)
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: editedPrompt) { _, newValue in
                            prefsManager.preferences.systemPrompt = newValue
                            prefsManager.save()
                        }

                    HStack {
                        Button("Réinitialiser") {
                            resetToDefaultPrompt()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("\(editedPrompt.count) caractères")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // SECTION : Historique
            Section("Historique") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Nombre de messages dans l'historique")
                        Spacer()
                        Text("\(prefsManager.preferences.historyMessageCount)")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: Binding(
                        get: { Double(prefsManager.preferences.historyMessageCount) },
                        set: { prefsManager.preferences.historyMessageCount = Int($0) }
                    ), in: 10...50, step: 5)
                    .onChange(of: prefsManager.preferences.historyMessageCount) { _, _ in
                        prefsManager.save()
                    }

                    // Explication
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Plus de messages = meilleure mémoire mais coût plus élevé")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }

                Text("L'historique permet à ChatGPT de se souvenir du contexte de vos conversations précédentes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // SECTION : Sauvegarde
            Section("Sauvegarde") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dossier d'export des conversations")
                            .font(.body)
                        if let folder = prefsManager.preferences.exportFolder {
                            Text(folder)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Aucun dossier sélectionné")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button("Choisir...") {
                        showingFolderPicker = true
                    }
                }

                Text("Les conversations sont automatiquement sauvegardées dans les préférences de l'application.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // SECTION : Gestion
            Section("Gestion") {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Auto-sauvegarde activée")
                        .font(.body)
                }

                Text("Vos conversations sont sauvegardées automatiquement après chaque message.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
        .onAppear {
            editedPrompt = prefsManager.preferences.systemPrompt
        }
    }

    // MARK: - Helper Methods

    /// Gère la sélection du dossier d'export
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            prefsManager.preferences.exportFolder = url.path
            prefsManager.save()
            print("✅ Dossier d'export sélectionné : \(url.path)")

        case .failure(let error):
            print("❌ Erreur lors de la sélection du dossier : \(error)")
        }
    }

    /// Réinitialise le prompt système à la valeur par défaut
    private func resetToDefaultPrompt() {
        let defaultPrompt = """
Je veux que tu ne regardes que la partie surlignée.
Tu me la re-rediges complètement en respectant les retours à la ligne.

Ensuite pour chaque faute, tu me rayes le mot entier où il y a la faute, ou les mots entiers où il y a les fautes.
Tu rajoutes un espace devant avec et tu mets en gras et soulignés les mots que tu rajoutes pour corriger.

Ensuite, devant chaque paragraphe que tu as modifié, je veux que tu rajoutes une croix rouge (❌).
Et pour les autres paragraphes qui restent, je veux que tu rajoutes une croix verte (✅) devant chaque paragraphe.
"""
        editedPrompt = defaultPrompt
        prefsManager.preferences.systemPrompt = defaultPrompt
        prefsManager.save()
    }
}

#Preview {
    ConversationsPreferencesView()
        .frame(width: 600, height: 400)
}
