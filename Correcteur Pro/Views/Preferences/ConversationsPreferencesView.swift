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

            // SECTION : Inactivité
            Section("Nouvelle conversation automatique") {
                Toggle("Activer après inactivité", isOn: $prefsManager.preferences.autoNewConversationOnInactivity)
                    .onChange(of: prefsManager.preferences.autoNewConversationOnInactivity) { _, _ in
                        prefsManager.save()
                    }

                if prefsManager.preferences.autoNewConversationOnInactivity {
                    Picker("Délai d'inactivité", selection: $prefsManager.preferences.inactivityTimeoutMinutes) {
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 heure").tag(60)
                    }
                    .onChange(of: prefsManager.preferences.inactivityTimeoutMinutes) { _, _ in
                        prefsManager.save()
                    }
                }

                Text("Une nouvelle conversation sera créée automatiquement au lancement de l'app si vous n'avez pas envoyé de message depuis ce délai.")
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

            // SECTION : Prompts archivés
            Section("Prompts archivés") {
                if prefsManager.archivedPrompts.isEmpty {
                    HStack {
                        Image(systemName: "archivebox")
                            .foregroundColor(.secondary)
                        Text("Aucun prompt archivé")
                            .foregroundColor(.secondary)
                    }
                    Text("Les prompts archivés apparaîtront ici. Ils seront supprimés définitivement après 90 jours.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(prefsManager.archivedPrompts) { prompt in
                        ArchivedPromptRow(prompt: prompt) {
                            // Restaurer
                            prefsManager.restorePrompt(id: prompt.id)
                        } onDelete: {
                            // Supprimer définitivement
                            prefsManager.deletePromptPermanently(id: prompt.id)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            // Nettoyer les prompts expirés au lancement
            prefsManager.cleanupExpiredPrompts()
        }
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

    /// Réinitialise le prompt système à la valeur par défaut (avec exemples intégrés)
    private func resetToDefaultPrompt() {
        editedPrompt = AppPreferences.defaultPromptCorrecteur
        prefsManager.preferences.systemPrompt = AppPreferences.defaultPromptCorrecteur
        prefsManager.save()
    }
}

// MARK: - Composants

/// Ligne pour un prompt archivé avec actions restaurer/supprimer
struct ArchivedPromptRow: View {
    let prompt: CustomPrompt
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            // Icône et nom
            HStack(spacing: 8) {
                Text(prompt.icon)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.name)
                        .font(.body)

                    if let days = prompt.daysUntilDeletion {
                        Text("Suppression dans \(days) jour\(days > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundColor(days <= 7 ? .red : .secondary)
                    }
                }
            }

            Spacer()

            // Boutons d'action
            HStack(spacing: 8) {
                Button(action: onRestore) {
                    Label("Restaurer", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .alert("Supprimer définitivement ?", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Le prompt \"\(prompt.name)\" sera supprimé définitivement. Cette action est irréversible.")
        }
    }
}

#Preview {
    ConversationsPreferencesView()
        .frame(width: 600, height: 500)
}
