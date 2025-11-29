//
//  Previews.swift
//  Correcteur Pro
//
//  Fichier centralisé pour toutes les previews de l'application
//  Permet de tester rapidement tous les composants
//

import SwiftUI

// MARK: - Preview de l'application complète avec différents scénarios

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Scénario 1 : Application normale avec conversations
            ContentView()
                .frame(width: 600, height: 700)
                .previewDisplayName("📱 Application complète (600x700)")
            
            // Scénario 2 : Mode portrait compact
            ContentView()
                .frame(width: 400, height: 700)
                .previewDisplayName("📱 Mode portrait (400x700)")
            
            // Scénario 3 : Mode large
            ContentView()
                .frame(width: 800, height: 900)
                .previewDisplayName("📱 Mode large (800x900)")
        }
    }
}

// MARK: - Preview des composants individuels

struct ComponentPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            // Sidebar
            SidebarPreviewWrapper()
            .frame(width: 200, height: 700)
            .previewDisplayName("📑 Sidebar")
            
            // Chat avec plusieurs messages
            ChatPreviewWrapper()
            .frame(width: 400, height: 700)
            .previewDisplayName("💬 Chat avec messages")
            
            // Chat vide
            EmptyChatPreviewWrapper()
            .frame(width: 400, height: 700)
            .previewDisplayName("💬 Chat vide")
        }
    }
}

// MARK: - Preview des bulles de messages

struct MessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Message utilisateur
            MessageBubble(
                message: Message(
                    contenu: "Bonjour, peux-tu corriger ce texte avec des fautes d'orthographe ?",
                    isUser: true
                )
            )
            
            // Message assistant
            MessageBubble(
                message: Message(
                    contenu: "Bien sûr ! Envoyez-moi le texte à corriger et je vous aiderai à identifier toutes les erreurs.",
                    isUser: false
                )
            )
            
            // Message utilisateur court
            MessageBubble(
                message: Message(
                    contenu: "OK",
                    isUser: true
                )
            )
            
            // Message assistant long
            MessageBubble(
                message: Message(
                    contenu: "Voici votre texte corrigé : Il y a plusieurs **fautes** dans ce document. J'ai identifié les erreurs et les ai corrigées. Les mots en gras souligné sont les corrections.",
                    isUser: false
                )
            )
        }
        .padding()
        .background(Color.white)
        .previewDisplayName("💬 Bulles de messages")
    }
}

// MARK: - Preview de l'input bar

struct InputBarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Input vide
            InputBarView(
                inputText: .constant(""),
                pendingImages: .constant([]),
                isGenerating: false,
                onSend: {},
                onImageAdded: {},
                onImageError: { _ in },
                onImageCompressed: { _ in }
            )
            .previewDisplayName("⌨️ Input vide")
            
            // Input avec texte court
            InputBarView(
                inputText: .constant("Bonjour"),
                pendingImages: .constant([]),
                isGenerating: false,
                onSend: {},
                onImageAdded: {},
                onImageError: { _ in },
                onImageCompressed: { _ in }
            )
            .previewDisplayName("⌨️ Input avec texte court")
            
            // Input avec texte long (multiligne)
            InputBarView(
                inputText: .constant("Voici un message très long qui va s'étendre sur plusieurs lignes pour tester le comportement du TextEditor multiligne dans l'interface."),
                pendingImages: .constant([]),
                isGenerating: false,
                onSend: {},
                onImageAdded: {},
                onImageError: { _ in },
                onImageCompressed: { _ in }
            )
            .previewDisplayName("⌨️ Input multiligne")
            
            // Input pendant génération
            InputBarView(
                inputText: .constant("Message en cours d'envoi..."),
                pendingImages: .constant([]),
                isGenerating: true,
                onSend: {},
                onImageAdded: {},
                onImageError: { _ in },
                onImageCompressed: { _ in }
            )
            .previewDisplayName("⌨️ Input pendant génération")
        }
        .frame(width: 400)
        .padding()
        .background(Color.white)
    }
}

// MARK: - Preview du header

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            HeaderView(
                title: "Correction de texte",
                isSidebarVisible: .constant(true),
                canRename: true,
                onRename: {},
                viewModel: ChatViewModel.preview,
                isPromptEditorOpen: .constant(false)
            )

            HeaderView(
                title: "Conversation avec un titre très long qui sera tronqué automatiquement",
                isSidebarVisible: .constant(false),
                canRename: false,
                onRename: {},
                viewModel: ChatViewModel.preview,
                isPromptEditorOpen: .constant(true)
            )
        }
        .frame(width: 400)
        .previewDisplayName("📋 Header")
    }
}

// MARK: - Preview de l'état vide

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView()
            .frame(width: 400, height: 500)
            .background(Color.white)
            .previewDisplayName("📭 État vide")
    }
}

// MARK: - Preview Wrappers

private struct SidebarPreviewWrapper: View {
    @StateObject private var viewModel = ChatViewModel.preview
    
    var body: some View {
        SidebarView(viewModel: viewModel)
    }
}

private struct ChatPreviewWrapper: View {
    @StateObject private var viewModel = ChatViewModel(conversations: [
        Conversation(
            titre: "Conversation de test",
            messages: [
                Message(contenu: "Bonjour !", isUser: true),
                Message(contenu: "Bonjour ! Comment puis-je vous aider ?", isUser: false),
                Message(contenu: "Je voudrais corriger ce texte : 'Il y a beaucoup de faute dans ce document.'", isUser: true),
                Message(contenu: "Voici la correction : Il y a beaucoup de **fautes** dans ce document.", isUser: false),
                Message(contenu: "Merci beaucoup !", isUser: true)
            ]
        )
    ])
    @State private var inputText: String = ""
    
    var body: some View {
        ChatView(
            viewModel: viewModel,
            isSidebarVisible: .constant(true),
            inputText: $inputText
        )
    }
}

private struct EmptyChatPreviewWrapper: View {
    @StateObject private var viewModel = ChatViewModel(conversations: [])
    @State private var inputText: String = ""
    
    var body: some View {
        ChatView(
            viewModel: viewModel,
            isSidebarVisible: .constant(true),
            inputText: $inputText
        )
    }
}

