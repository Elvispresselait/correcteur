//
//  ContentView.swift
//  Correcteur Pro
//
//  Vue principale de l'application avec sidebar et zone de chat
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isSidebarVisible: Bool = true
    @State private var inputText: String = ""
    @State private var showSettings = false
    @State private var hasAPIKey = false
    
    private let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: "020815"),
            Color(hex: "07152C"),
            Color(hex: "0F2D4F")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Banner d'avertissement si pas de clé API
                if !hasAPIKey {
                    APIKeyWarningBanner(onOpenSettings: {
                        showSettings = true
                    })
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: hasAPIKey)
                }
                
                HStack(spacing: 0) {
                    if isSidebarVisible {
                        SidebarView(viewModel: viewModel)
                            .frame(width: 230)
                            .transition(.move(edge: .leading))
                    }
                    
                    ChatView(
                        viewModel: viewModel,
                        isSidebarVisible: $isSidebarVisible,
                        inputText: $inputText,
                        onOpenSettings: {
                            showSettings = true
                        }
                    )
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 40, x: 0, y: 20)
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .onDisappear {
                    // Vérifier si une clé a été ajoutée après fermeture des préférences
                    checkAPIKeyStatus()
                }
        }
        .onAppear {
            checkAPIKeyStatus()
            // Observer les notifications pour ouvrir les préférences
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenSettings"),
                object: nil,
                queue: .main
            ) { _ in
                showSettings = true
            }
            
            // Observer les changements de clé API
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("APIKeySaved"),
                object: nil,
                queue: .main
            ) { _ in
                checkAPIKeyStatus()
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("APIKeyDeleted"),
                object: nil,
                queue: .main
            ) { _ in
                checkAPIKeyStatus()
            }
        }
        .onChange(of: showSettings) { oldValue, newValue in
            if !newValue {
                // Vérifier le statut après fermeture
                checkAPIKeyStatus()
            }
        }
    }
    
    private func checkAPIKeyStatus() {
        hasAPIKey = APIKeyManager.hasAPIKey()
    }
}

// MARK: - API Key Warning Banner

struct APIKeyWarningBanner: View {
    let onOpenSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.orange)
            
            Text("Clé API non configurée. Ouvrez les Préférences pour configurer.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Button("Ouvrir les Préférences") {
                onOpenSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "4F8CFF"))
            .cornerRadius(6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color.orange.opacity(0.15)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.orange.opacity(0.3)),
                    alignment: .bottom
                )
        )
    }
}

#Preview("Application complète") {
    ContentView()
        .frame(width: 600, height: 700)
        .previewDisplayName("Correcteur Pro - Vue principale")
}

#Preview("Mode portrait") {
    ContentView()
        .frame(width: 400, height: 700)
        .previewDisplayName("Mode portrait (400x700)")
}

#Preview("Mode large") {
    ContentView()
        .frame(width: 800, height: 900)
        .previewDisplayName("Mode large (800x900)")
}

