//
//  APIPreferencesView.swift
//  Correcteur Pro
//
//  Onglet des préférences API OpenAI
//

import SwiftUI

struct APIPreferencesView: View {

    @ObservedObject var prefsManager = PreferencesManager.shared
    @State private var apiKey: String = ""
    @State private var isApiKeyVisible: Bool = false
    @State private var apiKeyStatus: APIKeyStatus = .checking
    @State private var showSaveConfirmation: Bool = false
    @State private var estimatedRequestsPerDay: Double = 10

    enum APIKeyStatus {
        case checking
        case valid
        case invalid
        case notConfigured
    }

    var body: some View {
        Form {
            // SECTION : Clé API
            Section("Clé API OpenAI") {
                HStack {
                    if isApiKeyVisible {
                        TextField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    Button(action: { isApiKeyVisible.toggle() }) {
                        Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isApiKeyVisible ? "Masquer la clé" : "Afficher la clé")
                }

                HStack {
                    // Indicateur de statut
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Bouton sauvegarder
                    Button("Sauvegarder") {
                        saveApiKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty || !apiKey.hasPrefix("sk-"))
                }

                if showSaveConfirmation {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Clé API sauvegardée avec succès")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .transition(.opacity)
                }

                Text("Votre clé API est stockée de manière sécurisée dans le Trousseau macOS. Obtenez votre clé sur [platform.openai.com](https://platform.openai.com/api-keys)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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

            // SECTION : Estimation du coût total
            Section("Estimation du coût total") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Requêtes estimées par jour")
                        Spacer()
                        Text("\(Int(estimatedRequestsPerDay))")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $estimatedRequestsPerDay, in: 1...100, step: 1)
                }

                // Coûts estimés
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("Coût par jour :")
                        Spacer()
                        Text(dailyCost)
                            .fontWeight(.medium)
                    }
                    .font(.callout)

                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.orange)
                        Text("Coût par mois (30j) :")
                        Spacer()
                        Text(monthlyCost)
                            .fontWeight(.semibold)
                    }
                    .font(.callout)
                }
                .padding(.top, 4)

                Text("Estimation basée sur \(Int(estimatedRequestsPerDay)) requêtes/jour avec \(prefsManager.preferences.maxTokens) tokens max par requête.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .onAppear {
            loadExistingApiKey()
        }
    }

    // MARK: - API Key Methods

    /// Couleur de l'indicateur de statut
    private var statusColor: Color {
        switch apiKeyStatus {
        case .checking: return .orange
        case .valid: return .green
        case .invalid: return .red
        case .notConfigured: return .gray
        }
    }

    /// Texte de l'indicateur de statut
    private var statusText: String {
        switch apiKeyStatus {
        case .checking: return "Vérification..."
        case .valid: return "Clé API configurée"
        case .invalid: return "Clé API invalide"
        case .notConfigured: return "Clé API non configurée"
        }
    }

    /// Charge la clé API existante (masquée)
    private func loadExistingApiKey() {
        if let existingKey = APIKeyManager.loadAPIKey() {
            // Afficher seulement les premiers et derniers caractères
            let prefix = String(existingKey.prefix(7))
            let suffix = String(existingKey.suffix(4))
            apiKey = prefix + "..." + suffix
            apiKeyStatus = .valid
        } else {
            apiKeyStatus = .notConfigured
        }
    }

    /// Sauvegarde la clé API dans le Keychain
    private func saveApiKey() {
        // Ne pas sauvegarder si c'est la version masquée
        if apiKey.contains("...") && apiKey.count < 20 {
            return
        }

        if APIKeyManager.saveAPIKey(apiKey) {
            apiKeyStatus = .valid
            showSaveConfirmation = true
            // Masquer la clé après sauvegarde
            let prefix = String(apiKey.prefix(7))
            let suffix = String(apiKey.suffix(4))
            apiKey = prefix + "..." + suffix

            // Masquer la confirmation après 3 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showSaveConfirmation = false
                }
            }
        } else {
            apiKeyStatus = .invalid
        }
    }

    // MARK: - Helper Methods

    /// Formate un coût en euros avec 4 décimales
    private func formatCost(_ cost: Double) -> String {
        return String(format: "%.4f", cost)
    }

    /// Calcule le coût estimé d'une requête en euros
    private var estimatedCostValue: Double {
        let model = prefsManager.preferences.defaultModel
        let tokens = Double(prefsManager.preferences.maxTokens)

        // Estimation : 50% input, 50% output
        let inputTokens = tokens * 0.5
        let outputTokens = tokens * 0.5

        let inputCost = (inputTokens / 1000.0) * model.costPer1kInputTokens
        let outputCost = (outputTokens / 1000.0) * model.costPer1kOutputTokens
        return inputCost + outputCost
    }

    private var estimatedCost: String {
        return String(format: "%.4f€", estimatedCostValue)
    }

    /// Coût estimé par jour
    private var dailyCost: String {
        let cost = estimatedCostValue * estimatedRequestsPerDay
        return String(format: "%.2f€", cost)
    }

    /// Coût estimé par mois (30 jours)
    private var monthlyCost: String {
        let cost = estimatedCostValue * estimatedRequestsPerDay * 30
        return String(format: "%.2f€", cost)
    }
}

#Preview {
    APIPreferencesView()
        .frame(width: 600, height: 400)
}
