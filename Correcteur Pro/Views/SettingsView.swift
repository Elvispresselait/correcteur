//
//  SettingsView.swift
//  Correcteur Pro
//
//  Vue de préférences pour configurer la clé API OpenAI
//

import SwiftUI
import AppKit

enum ConnectionStatus {
    case notConfigured
    case testing
    case connected
    case error(String)
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKeyInput: String = ""
    @State private var showAPIKey: Bool = false
    @State private var connectionStatus: ConnectionStatus = .notConfigured
    @State private var isTesting: Bool = false
    @State private var toast: ToastMessage?
    
    private let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: "031838"),
            Color(hex: "052448"),
            Color(hex: "07152C")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Préférences")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Section API Configuration
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Configuration API")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Champ de saisie API Key
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Clé API OpenAI")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack(spacing: 8) {
                                if showAPIKey {
                                    TextField("sk-...", text: $apiKeyInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                } else {
                                    SecureField("sk-...", text: $apiKeyInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                Button(action: { showAPIKey.toggle() }) {
                                    Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help(showAPIKey ? "Masquer la clé" : "Afficher la clé")
                            }
                        }
                        
                        // Statut de connexion
                        HStack(spacing: 8) {
                            statusIcon
                            Text(statusText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(statusColor)
                        }
                        .padding(.vertical, 8)
                        
                        // Message d'erreur
                        if case .error(let message) = connectionStatus {
                            Text("Erreur : \(message)")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.vertical, 4)
                        }
                        
                        // Boutons d'action
                        HStack(spacing: 12) {
                            Button(action: testConnection) {
                                HStack(spacing: 6) {
                                    if isTesting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 13))
                                    }
                                    Text("Tester la connexion")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(hex: "4F8CFF"))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(isTesting || apiKeyInput.isEmpty)
                            .opacity((isTesting || apiKeyInput.isEmpty) ? 0.5 : 1.0)
                            
                            Button(action: saveAPIKey) {
                                Text("Enregistrer")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: "4CAF50"))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(apiKeyInput.isEmpty)
                            .opacity(apiKeyInput.isEmpty ? 0.5 : 1.0)
                            
                            if APIKeyManager.hasAPIKey() {
                                Button(action: deleteAPIKey) {
                                    Text("Supprimer")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.red.opacity(0.7))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                
                                // Bouton de tests rapides
                                Button(action: runQuickTests) {
                                    HStack(spacing: 6) {
                                        if isTesting {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .progressViewStyle(.circular)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 13))
                                        }
                                        Text("Tests rapides")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: "FF6B6B"))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(isTesting)
                                .opacity(isTesting ? 0.5 : 1.0)
                            }
                        }
                        
                        // Lien vers OpenAI
                        Button(action: {
                            if let url = URL(string: "https://platform.openai.com/api-keys") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text("Obtenir une clé API")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(Color(hex: "4F8CFF"))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadAPIKey()
        }
        .toast($toast)
        .onChange(of: toast) { oldValue, newValue in
            if let toast = newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                    self.toast = nil
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: some View {
        Group {
            switch connectionStatus {
            case .notConfigured:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.gray)
            case .testing:
                ProgressView()
                    .scaleEffect(0.7)
                    .progressViewStyle(.circular)
                    .tint(.orange)
            case .connected:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var statusText: String {
        switch connectionStatus {
        case .notConfigured:
            return "Non configuré"
        case .testing:
            return "Test en cours..."
        case .connected:
            return "Connecté"
        case .error(let message):
            return "Non connecté : \(message)"
        }
    }
    
    private var statusColor: Color {
        switch connectionStatus {
        case .notConfigured:
            return .gray
        case .testing:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
    
    // MARK: - Actions
    
    private func loadAPIKey() {
        if let key = APIKeyManager.loadAPIKey() {
            apiKeyInput = key
            // Tester automatiquement si une clé existe
            testConnection()
        } else {
            connectionStatus = .notConfigured
        }
    }
    
    private func saveAPIKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            showToast(.error("La clé API ne peut pas être vide"))
            return
        }
        
        guard trimmedKey.hasPrefix("sk-") else {
            showToast(.warning("Format de clé API invalide (doit commencer par 'sk-')"))
            return
        }
        
        if APIKeyManager.saveAPIKey(trimmedKey) {
            showToast(.success("Clé API enregistrée avec succès"))
            apiKeyInput = "" // Vider le champ pour sécurité
            connectionStatus = .notConfigured
            // Notifier que la clé a été sauvegardée (pour mettre à jour le banner)
            NotificationCenter.default.post(name: NSNotification.Name("APIKeySaved"), object: nil)
        } else {
            showToast(.error("Échec de l'enregistrement de la clé API"))
        }
    }
    
    private func deleteAPIKey() {
        if APIKeyManager.deleteAPIKey() {
            showToast(.success("Clé API supprimée"))
            apiKeyInput = ""
            connectionStatus = .notConfigured
            // Notifier que la clé a été supprimée (pour mettre à jour le banner)
            NotificationCenter.default.post(name: NSNotification.Name("APIKeyDeleted"), object: nil)
        } else {
            showToast(.error("Échec de la suppression de la clé API"))
        }
    }
    
    private func testConnection() {
        let keyToTest = apiKeyInput.isEmpty ? APIKeyManager.loadAPIKey() : apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let key = keyToTest, !key.isEmpty else {
            connectionStatus = .error("Aucune clé API à tester")
            return
        }
        
        isTesting = true
        connectionStatus = .testing
        
        // Test réel de connexion avec OpenAIConnectionTester
        Task {
            do {
                let success = try await OpenAIConnectionTester.testConnection(apiKey: key)
                
                await MainActor.run {
                    if success {
                        connectionStatus = .connected
                        showToast(.success("Connexion réussie !"))
                    } else {
                        connectionStatus = .error("Connexion échouée")
                        showToast(.error("Échec de la connexion"))
                    }
                    isTesting = false
                }
            } catch let error as ConnectionTestError {
                await MainActor.run {
                    let errorMessage = error.localizedDescription
                    connectionStatus = .error(errorMessage)
                    isTesting = false
                    
                    // Afficher un toast avec le message d'erreur approprié
                    switch error {
                    case .unauthorized, .invalidAPIKey:
                        showToast(.error("Clé API invalide ou expirée"))
                    case .rateLimitExceeded:
                        showToast(.warning("Limite de requêtes atteinte. Réessayez plus tard."))
                    case .networkError:
                        showToast(.error("Erreur réseau. Vérifiez votre connexion internet."))
                    case .serverError:
                        showToast(.error("Erreur serveur OpenAI. Réessayez plus tard."))
                    default:
                        showToast(.error(errorMessage))
                    }
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .error("Erreur inconnue")
                    isTesting = false
                    showToast(.error("Erreur lors du test de connexion: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func showToast(_ message: ToastMessage) {
        toast = message
    }
    
    // MARK: - Tests rapides
    
    private func runQuickTests() {
        guard let apiKey = APIKeyManager.loadAPIKey() else {
            showToast(.error("Aucune clé API configurée"))
            return
        }
        
        isTesting = true
        showToast(.info("Démarrage des tests..."))
        
        Task {
            // Test 1 : Connexion
            do {
                let isConnected = try await OpenAIConnectionTester.testConnection(apiKey: apiKey)
                await MainActor.run {
                    if isConnected {
                        showToast(.success("✅ Test 1/3 : Connexion réussie"))
                    }
                }
            } catch {
                await MainActor.run {
                    showToast(.error("❌ Test 1/3 échoué: \(error.localizedDescription)"))
                    isTesting = false
                    return
                }
            }
            
            // Attendre un peu
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Test 2 : Message simple
            do {
                let response = try await OpenAIService.sendMessage(
                    message: "Dis bonjour en français",
                    systemPrompt: "Tu es un assistant utile."
                )
                await MainActor.run {
                    showToast(.success("✅ Test 2/3 : Message simple réussi"))
                    print("📝 Réponse test 2: \(response)")
                }
            } catch {
                await MainActor.run {
                    showToast(.error("❌ Test 2/3 échoué: \(error.localizedDescription)"))
                    isTesting = false
                    return
                }
            }
            
            // Attendre un peu
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Test 3 : Question
            do {
                let response = try await OpenAIService.sendMessage(
                    message: "Quelle est la capitale de la France ?",
                    systemPrompt: "Tu es un assistant géographique."
                )
                await MainActor.run {
                    showToast(.success("✅ Test 3/3 : Question réussie"))
                    print("📝 Réponse test 3: \(response)")
                    showToast(.success("🎉 Tous les tests sont réussis !"))
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    showToast(.error("❌ Test 3/3 échoué: \(error.localizedDescription)"))
                    isTesting = false
                }
            }
        }
    }
}

#Preview("Settings View") {
    SettingsView()
}

