//
//  APIPreferencesView.swift
//  Correcteur Pro
//
//  Onglet des préférences API OpenAI
//

import SwiftUI

struct APIPreferencesView: View {

    @ObservedObject var prefsManager = PreferencesManager.shared

    var body: some View {
        Form {
            // SECTION : Modèle
            Section("Modèle") {
                Picker("Modèle OpenAI", selection: $prefsManager.preferences.defaultModel) {
                    ForEach(OpenAIModel.allCases, id: \.self) { model in
                        HStack {
                            Text(model.displayName)
                            Spacer()
                            Text("~\(formatCost(model.costPer1kInputTokens))€ / 1k tokens")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(model)
                    }
                }
                .onChange(of: prefsManager.preferences.defaultModel) { _, _ in
                    prefsManager.save()
                }

                // Informations sur le modèle sélectionné
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prix du modèle \(prefsManager.preferences.defaultModel.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• Input : \(formatCost(prefsManager.preferences.defaultModel.costPer1kInputTokens))€ / 1000 tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• Output : \(formatCost(prefsManager.preferences.defaultModel.costPer1kOutputTokens))€ / 1000 tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }

            // SECTION : Tokens
            Section("Tokens") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Nombre maximum de tokens")
                        Spacer()
                        Text("\(prefsManager.preferences.maxTokens)")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: Binding(
                        get: { Double(prefsManager.preferences.maxTokens) },
                        set: { prefsManager.preferences.maxTokens = Int($0) }
                    ), in: 1000...16000, step: 500)
                    .onChange(of: prefsManager.preferences.maxTokens) { _, _ in
                        prefsManager.save()
                    }

                    // Affichage du coût estimé
                    HStack {
                        Image(systemName: "eurosign.circle")
                            .foregroundColor(.green)
                        Text("Coût estimé par requête : \(estimatedCost)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }

                Toggle("Afficher l'utilisation des tokens après chaque requête", isOn: $prefsManager.preferences.showTokenUsage)
                    .onChange(of: prefsManager.preferences.showTokenUsage) { _, _ in
                        prefsManager.save()
                    }
            }

            // SECTION : Information
            Section("Information") {
                Text("Le nombre de tokens correspond au nombre maximum de mots/caractères générés par l'IA. Plus le nombre est élevé, plus les réponses peuvent être longues, mais plus le coût augmente.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Helper Methods

    /// Formate un coût en euros avec 4 décimales
    private func formatCost(_ cost: Double) -> String {
        return String(format: "%.4f", cost)
    }

    /// Calcule le coût estimé d'une requête en euros
    private var estimatedCost: String {
        let model = prefsManager.preferences.defaultModel
        let tokens = Double(prefsManager.preferences.maxTokens)

        // Estimation : 50% input, 50% output
        let inputTokens = tokens * 0.5
        let outputTokens = tokens * 0.5

        let inputCost = (inputTokens / 1000.0) * model.costPer1kInputTokens
        let outputCost = (outputTokens / 1000.0) * model.costPer1kOutputTokens
        let totalCost = inputCost + outputCost

        return String(format: "%.4f€", totalCost)
    }
}

#Preview {
    APIPreferencesView()
        .frame(width: 600, height: 400)
}
