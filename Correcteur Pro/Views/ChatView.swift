//
//  ChatView.swift
//  Correcteur Pro
//
//  Zone principale de chat avec messages et input
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isSidebarVisible: Bool
    @Binding var inputText: String

    @State private var isRenamingConversation = false
    @State private var renameDraft = ""
    @State private var pendingImages: [NSImage] = []
    @State private var toast: ToastMessage?
    @State private var isPromptEditorOpen = false
    
    private let chatGradient = LinearGradient(
        colors: [
            Color(hex: "061226"),
            Color(hex: "0C1F3C"),
            Color(hex: "123257")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                title: viewModel.selectedConversation?.titre ?? "Aucune conversation",
                isSidebarVisible: $isSidebarVisible,
                canRename: viewModel.selectedConversation != nil,
                onRename: presentRenameDialog,
                viewModel: viewModel,
                isPromptEditorOpen: $isPromptEditorOpen,
                onTestFrontend: {
                    Task {
                        await FrontendTester.testFrontendFlow()
                    }
                }
            )

            // Éditeur de prompt (s'affiche en dessous du header si ouvert)
            if isPromptEditorOpen {
                PromptEditorView(viewModel: viewModel, isOpen: $isPromptEditorOpen)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let conversation = viewModel.selectedConversation {
                MessagesScrollView(messages: conversation.messages)
            } else {
                EmptyStateView()
            }

            InputBarView(
                inputText: $inputText,
                pendingImages: $pendingImages,
                isGenerating: viewModel.isGenerating, // ÉTAPE 4.2 : Désactiver le bouton pendant la génération
                onSend: sendMessage,
                onImageAdded: { showToast(.success("Image ajoutée")) },
                onImageError: { error in showToast(.error(error.localizedDescription)) },
                onImageCompressed: { message in
                    // TEMPS 2 : Afficher toast de compression
                    if message.contains("compressée") {
                        showToast(.success(message))
                    } else {
                        showToast(.warning(message))
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Rectangle()
                .fill(chatGradient)
        )
        .toast($toast)
        .onChange(of: toast) { oldValue, newValue in
            if let toast = newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                    self.toast = nil
                }
            }
        }
        .alert("Renommer la conversation", isPresented: $isRenamingConversation, actions: {
            TextField("Nouveau titre", text: $renameDraft)
            Button("Annuler", role: .cancel) {
                renameDraft = ""
            }
            Button("Enregistrer") {
                viewModel.renameSelectedConversation(to: renameDraft)
                renameDraft = ""
            }
            .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }, message: {
            Text("Choisissez un titre qui décrit rapidement le contenu.")
        })
    }
    
    private func presentRenameDialog() {
        guard let currentTitle = viewModel.selectedConversation?.titre else { return }
        renameDraft = currentTitle
        isRenamingConversation = true
    }
    
    private func sendMessage() {
        let imagesToSend = pendingImages.isEmpty ? nil : pendingImages
        
        // TEMPS 2 : Les images dans pendingImages sont déjà compressées
        // Plus besoin de vérifier la taille avant envoi
        
        guard viewModel.sendMessage(inputText, images: imagesToSend) else {
            showToast(.error("Impossible d'envoyer le message"))
            return
        }
        
        // Afficher un toast de succès si des images ont été envoyées
        if let images = imagesToSend, !images.isEmpty {
            showToast(.success("\(images.count) image\(images.count > 1 ? "s" : "") envoyée\(images.count > 1 ? "s" : "")"))
        }
        
        inputText = ""
        pendingImages = []
    }
    
    private func showToast(_ message: ToastMessage) {
        toast = message
    }
}

struct HeaderView: View {
    let title: String
    @Binding var isSidebarVisible: Bool
    let canRename: Bool
    let onRename: () -> Void
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPromptEditorOpen: Bool
    var onTestFrontend: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSidebarVisible.toggle()
                }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("Afficher/masquer la barre latérale")

            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Bouton de renommage juste à côté du titre
                if canRename {
                    Button(action: onRename) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Renommer la conversation")
                }
            }

            Spacer()

            // Boutons de sélection de prompt en ligne (sélectionné à droite)
            PromptSelectorRow(viewModel: viewModel, isPromptEditorOpen: $isPromptEditorOpen)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(height: 48)
    }
}

/// Ligne de sélection des prompts (responsive)
struct PromptSelectorRow: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPromptEditorOpen: Bool
    @State private var showNewPromptSheet = false

    /// Prompts personnalisés de l'utilisateur
    private var customPrompts: [CustomPrompt] {
        PreferencesManager.shared.preferences.customPrompts
    }

    /// Ordre des prompts de base : non-sélectionnés à gauche, sélectionné à droite
    private var sortedBasePrompts: [SystemPromptType] {
        // Exclure .personnalise car on gère les prompts custom séparément
        SystemPromptType.allCases
            .filter { $0 != .personnalise }
            .sorted { lhs, rhs in
                if lhs == viewModel.promptType { return false }
                if rhs == viewModel.promptType { return true }
                return lhs.rawValue < rhs.rawValue
            }
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 300

            HStack(spacing: 6) {
                // Bouton "+" pour créer un nouveau prompt
                Button(action: { showNewPromptSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .help("Créer un nouveau prompt")

                // Prompts de base (Correcteur, Assistant, Traducteur)
                ForEach(sortedBasePrompts) { promptType in
                    PromptRowButton(
                        promptType: promptType,
                        isSelected: viewModel.promptType == promptType,
                        isCompact: isCompact,
                        isEditorOpen: isPromptEditorOpen && viewModel.promptType == promptType,
                        isTemporary: viewModel.isInTemporaryMode && viewModel.promptType == promptType
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if viewModel.promptType == promptType {
                                // Déjà sélectionné → toggle l'éditeur
                                isPromptEditorOpen.toggle()
                            } else {
                                // Nouveau prompt → sélectionner et ouvrir l'éditeur
                                viewModel.promptType = promptType
                                viewModel.selectedCustomPromptID = nil
                                viewModel.temporaryPrompt = nil
                                isPromptEditorOpen = true
                            }
                        }
                    }
                }

                // Prompts personnalisés créés par l'utilisateur
                ForEach(customPrompts) { custom in
                    CustomPromptRowButton(
                        prompt: custom,
                        isSelected: viewModel.promptType == .personnalise && viewModel.selectedCustomPromptID == custom.id,
                        isCompact: isCompact,
                        isEditorOpen: isPromptEditorOpen && viewModel.selectedCustomPromptID == custom.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if viewModel.promptType == .personnalise && viewModel.selectedCustomPromptID == custom.id {
                                isPromptEditorOpen.toggle()
                            } else {
                                viewModel.promptType = .personnalise
                                viewModel.selectedCustomPromptID = custom.id
                                viewModel.temporaryPrompt = nil
                                isPromptEditorOpen = true
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 32)
        .sheet(isPresented: $showNewPromptSheet) {
            NewPromptSheet(viewModel: viewModel, isOpen: $showNewPromptSheet, onCreated: {
                isPromptEditorOpen = true
            })
        }
    }
}

/// Bouton pour un prompt personnalisé
struct CustomPromptRowButton: View {
    let prompt: CustomPrompt
    let isSelected: Bool
    let isCompact: Bool
    let isEditorOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(prompt.icon)
                    .font(.system(size: isCompact ? 16 : 14))

                if !isCompact {
                    Text(prompt.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                }

                if isSelected {
                    Image(systemName: isEditorOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.purple.opacity(isEditorOpen ? 0.4 : 0.3) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple.opacity(isEditorOpen ? 0.7 : 0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
        .help(prompt.name)
    }
}

/// Sheet pour créer un nouveau prompt
struct NewPromptSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isOpen: Bool
    var onCreated: () -> Void

    @State private var name: String = ""
    @State private var icon: String = "📝"
    @State private var content: String = ""

    private let availableIcons = ["📝", "✨", "🎯", "💡", "🔧", "📊", "🎨", "📚", "🔬", "💬"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Nouveau prompt")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Button("Annuler") {
                    isOpen = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Contenu
            VStack(alignment: .leading, spacing: 16) {
                // Nom et icône
                HStack(spacing: 12) {
                    // Sélecteur d'icône
                    Menu {
                        ForEach(availableIcons, id: \.self) { emoji in
                            Button(emoji) {
                                icon = emoji
                            }
                        }
                    } label: {
                        Text(icon)
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }

                    // Nom
                    TextField("Nom du prompt", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Contenu
                Text("Instructions")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $content)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 150)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                // Bouton créer
                HStack {
                    Spacer()
                    Button("Créer") {
                        viewModel.createCustomPrompt(name: name, icon: icon, content: content)
                        isOpen = false
                        onCreated()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
        }
        .frame(width: 500, height: 400)
    }
}

struct PromptRowButton: View {
    let promptType: SystemPromptType
    let isSelected: Bool
    let isCompact: Bool
    let isEditorOpen: Bool
    var isTemporary: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(promptType.icon)
                    .font(.system(size: isCompact ? 16 : 14))

                if !isCompact {
                    Text(promptType.shortName)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                }

                // Indicateur de mode temporaire (point rouge)
                if isSelected && isTemporary {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                }

                // Chevron pour indiquer l'état de l'éditeur (seulement si sélectionné)
                if isSelected {
                    Image(systemName: isEditorOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? (isTemporary ? Color.orange.opacity(0.4) : Color.blue.opacity(isEditorOpen ? 0.4 : 0.3)) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? (isTemporary ? Color.orange.opacity(0.7) : Color.blue.opacity(isEditorOpen ? 0.7 : 0.5)) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
        .help(isSelected ? (isTemporary ? "Mode temporaire - Cliquer pour modifier" : "Cliquer pour modifier le prompt") : promptType.rawValue)
    }
}

/// Éditeur de prompt inline (s'affiche sous le header)
struct PromptEditorView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isOpen: Bool
    @State private var editedPrompt: String = ""
    @State private var originalPrompt: String = ""
    @FocusState private var isFocused: Bool

    /// Récupère le prompt sauvegardé selon le type sélectionné
    private var savedPrompt: String {
        ChatViewModel.getSavedPrompt(for: viewModel.promptType)
    }

    /// Vérifie si le prompt a été modifié (mode temporaire)
    private var isModified: Bool {
        editedPrompt != originalPrompt
    }

    /// Calcule la hauteur dynamique selon le contenu
    private var dynamicHeight: CGFloat {
        let lineCount = max(3, editedPrompt.components(separatedBy: "\n").count)
        let estimatedHeight = CGFloat(lineCount) * 20 + 40 // 20pt par ligne + padding
        return min(max(80, estimatedHeight), 300) // Min 80, Max 300
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header de l'éditeur
            HStack {
                HStack(spacing: 8) {
                    Text(viewModel.promptType.icon)
                        .font(.system(size: 14))
                    Text("Modifier le prompt : \(viewModel.promptType.shortName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    // Indicateur de modification (point rouge)
                    if isModified {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .help("Modifications non sauvegardées")
                    }
                }

                Spacer()

                // Bouton fermer
                Button(action: {
                    handleClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Fermer l'éditeur")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isModified ? Color.red.opacity(0.15) : Color.black.opacity(0.3))

            // Zone d'édition
            TextEditor(text: $editedPrompt)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.05))
                .foregroundColor(.white)
                .focused($isFocused)
                .frame(minHeight: 60, maxHeight: dynamicHeight)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Footer avec actions
            HStack(spacing: 12) {
                Text("\(editedPrompt.count) caractères")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                if isModified {
                    // Boutons d'action quand modifié
                    Button(action: discardChanges) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 10))
                            Text("Annuler")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Annuler les modifications")

                    Button(action: saveChanges) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Sauvegarder")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.7))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Sauvegarder les modifications")
                } else {
                    // Bouton pour créer une branche (nouveau prompt basé sur celui-ci)
                    Button(action: createBranch) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10))
                            Text("Dupliquer")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Créer un nouveau prompt basé sur celui-ci")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isModified ? Color.red.opacity(0.1) : Color.clear)
        }
        .background(
            Rectangle()
                .fill(Color(hex: "0A1628"))
                .overlay(
                    Rectangle()
                        .stroke(isModified ? Color.red.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            editedPrompt = savedPrompt
            originalPrompt = savedPrompt
            isFocused = true
        }
        .onChange(of: viewModel.promptType) { _, _ in
            // Recharger quand le type change
            editedPrompt = savedPrompt
            originalPrompt = savedPrompt
        }
    }

    /// Sauvegarde les modifications
    private func saveChanges() {
        ChatViewModel.savePrompt(editedPrompt, for: viewModel.promptType)
        originalPrompt = editedPrompt
    }

    /// Annule les modifications
    private func discardChanges() {
        editedPrompt = originalPrompt
    }

    /// Crée une branche (nouveau prompt personnalisé basé sur celui-ci)
    private func createBranch() {
        let name = "\(viewModel.promptType.shortName) (copie)"
        viewModel.createCustomPrompt(name: name, icon: "📝", content: editedPrompt)
        withAnimation(.easeInOut(duration: 0.2)) {
            isOpen = false
        }
    }

    /// Gère la fermeture de l'éditeur
    private func handleClose() {
        if isModified {
            // Si modifié, on garde les changements en mode temporaire
            viewModel.temporaryPrompt = editedPrompt
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isOpen = false
        }
    }
}

struct CustomPromptSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draftPrompt: String

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        _draftPrompt = State(initialValue: viewModel.customPrompt)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Prompt système personnalisé")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Button("Annuler") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Button("Enregistrer") {
                    viewModel.customPrompt = draftPrompt
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // TextEditor
            TextEditor(text: $draftPrompt)
                .font(.system(size: 13, design: .monospaced))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 500)
    }
}

struct MessagesScrollView: View {
    let messages: [Message]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = false) {
        guard let lastID = messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    private let userBubble = Color(hex: "3E7BFF")
    private let assistantBubble = Color.white.opacity(0.18)
    
    @State private var selectedImage: NSImage?
    @State private var showImageModal = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Images
                if let images = message.images, !images.isEmpty {
                    MessageImagesView(images: images, onImageTap: { image in
                        selectedImage = image
                        showImageModal = true
                    })
                }
                
                // Texte
                if !message.contenu.isEmpty {
                    Text(styledText)
                        .font(.system(size: 14))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(bubbleBackground)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(message.isUser ? 0.25 : 0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .frame(maxWidth: 320, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
        .sheet(isPresented: $showImageModal) {
            if let image = selectedImage {
                ImageDetailView(image: image)
            }
        }
    }
    
    private var styledText: AttributedString {
        let converted = convertUnderlineMarkdown(in: message.contenu)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: converted, options: options)) ?? AttributedString(message.contenu)
    }
    
    private func convertUnderlineMarkdown(in text: String) -> String {
        var result = text
        guard let regex = try? NSRegularExpression(pattern: "__([^_]+)__", options: []) else {
            return result
        }
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let innerRange = Range(match.range(at: 1), in: result),
                  let totalRange = Range(match.range, in: result) else {
                continue
            }
            let innerText = result[innerRange]
            result.replaceSubrange(totalRange, with: "<u>\(innerText)</u>")
        }
        return result
    }
    
    private var bubbleBackground: Color {
        message.isUser ? userBubble : assistantBubble
    }
}

struct MessageImagesView: View {
    let images: [NSImage]
    let onImageTap: (NSImage) -> Void
    
    var body: some View {
        if images.count == 1 {
            // Une seule image
            MessageImageThumbnail(image: images[0], onTap: { onImageTap(images[0]) })
        } else {
            // Plusieurs images en grille 2 colonnes
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                    MessageImageThumbnail(image: image, onTap: { onImageTap(image) })
                }
            }
        }
    }
}

struct MessageImageThumbnail: View {
    let image: NSImage
    let onTap: () -> Void
    
    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 300, maxHeight: 200)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            .onTapGesture {
                onTap()
            }
            .help("Cliquer pour voir en taille réelle")
    }
}

struct ImageDetailView: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(16)
            }
            .background(Color.black.opacity(0.8))
            
            // Image en taille réelle
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.badge")
                .font(.system(size: 48))
                .foregroundColor(Color.white.opacity(0.3))
            
            Text("Aucune conversation sélectionnée")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
            
            Text("Créez un nouveau chat pour commencer")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InputBarView: View {
    @Binding var inputText: String
    @Binding var pendingImages: [NSImage]
    let isGenerating: Bool // ÉTAPE 4.2 : État de génération pour désactiver le bouton
    let onSend: () -> Void
    let onImageAdded: () -> Void
    let onImageError: (Error) -> Void
    let onImageCompressed: (String) -> Void // TEMPS 2 : Callback pour notifier la compression
    
    private let inputBackground = Color.white.opacity(0.08)
    private let borderColor = Color.white.opacity(0.2)
    
    var body: some View {
        VStack(spacing: 0) {
            // Preview des images
            if !pendingImages.isEmpty {
                ImagePreviewSection(images: $pendingImages)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            
            // Zone de saisie
            HStack(alignment: .bottom, spacing: 12) {
                TextEditorWithImagePaste(text: $inputText, onImagePasted: { result in
                    handleImagePasteResult(result)
                }, onSend: onSend)
                .frame(minHeight: 36, maxHeight: 80)
                .padding(8)
                .background(inputBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .foregroundColor(.white)
                .accentColor(Color(hex: "5C9DFF"))

                // Boutons empilés verticalement
                VStack(spacing: 8) {
                    // Bouton pour coller une image (même taille et couleur que le bouton d'envoi)
                    Button(action: {
                        handleImagePasteFromClipboard()
                    }) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(
                                Circle()
                                    .fill(Color(hex: "4F8CFF"))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Coller une image depuis le presse-papiers")

                    // Bouton d'envoi
                    Button(action: onSend) {
                        Image(systemName: isGenerating ? "stop.circle.fill" : "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(
                                Circle()
                                    .fill(sendButtonColor)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty) || isGenerating) // ÉTAPE 4.2 : Désactiver pendant la génération
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, pendingImages.isEmpty ? 8 : 0)
            .padding(.bottom, 12)
        }
    }
    
    // Gestion du collage d'image depuis le clipboard
    private func handleImagePasteFromClipboard() {
        let result = ClipboardHelper.checkClipboardForImage()
        handleImagePasteResult(result)
    }
    
    // Traite le résultat du collage d'image avec gestion d'erreurs
    // TEMPS 1 : Accepter toutes les images sans vérification de taille
    // TEMPS 2 : Compression automatique après upload
    private func handleImagePasteResult(_ result: ClipboardResult) {
        // Ne bloquer que les erreurs critiques (clipboard vide, format invalide)
        // Plus de vérification de taille - toutes les images sont acceptées
        if let error = result.error {
            // Ne bloquer que les erreurs non liées à la taille
            if case .imageTooLarge = error {
                // TEMPS 1 : Plus de rejet pour taille, on accepte quand même
                print("ℹ️ [InputBar] Image grande détectée, sera compressée après upload")
            } else {
                // Autres erreurs (vide, format invalide) : bloquer
                print("❌ [InputBar] Erreur: \(error.localizedDescription)")
                onImageError(error)
                return
            }
        }
        
        guard let image = result.image else {
            print("⚠️ [InputBar] Aucune image dans le résultat")
            onImageError(ClipboardError.empty)
            return
        }
        
        let originalSizeMB = result.sizeMB
        print("✅ [InputBar] Image ajoutée: \(image.size.width)x\(image.size.height)")
        if let mimeType = result.mimeType {
            print("📄 [InputBar] Type MIME: \(mimeType)")
        }
        if let sizeMB = originalSizeMB {
            print("📊 [InputBar] Taille originale: \(String(format: "%.2f", sizeMB)) MB")
        }
        
        // TEMPS 2 : Compression automatique après upload
        let finalImage = compressImageIfNeeded(image, originalSizeMB: originalSizeMB)
        
        // Animation d'ajout avec l'image (compressée ou originale)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pendingImages.append(finalImage)
        }
        
        onImageAdded()
    }
    
    /// TEMPS 2 : Compresse l'image si elle est > 2MB
    /// - Parameters:
    ///   - image: Image à compresser
    ///   - originalSizeMB: Taille originale en MB (optionnel, pour les logs)
    /// - Returns: Image compressée si > 2MB, sinon image originale
    private func compressImageIfNeeded(_ image: NSImage, originalSizeMB: Double?) -> NSImage {
        // Vérifier la taille actuelle
        let currentSizeMB = image.sizeInMB() ?? originalSizeMB ?? 0.0
        let targetSizeMB: Double = 2.0
        
        // Si image <= 2MB, pas besoin de compression
        guard currentSizeMB > targetSizeMB else {
            print("✅ [InputBar] Image déjà sous \(targetSizeMB) MB, pas de compression nécessaire")
            return image
        }
        
        print("🔧 [InputBar] TEMPS 2: Compression automatique activée (image > \(targetSizeMB) MB)...")
        print("📊 [InputBar] Compression: \(String(format: "%.2f", currentSizeMB)) MB -> cible: \(targetSizeMB) MB")
        
        // Compresser l'image
        if let compressed = image.compressToMaxSize(maxSizeMB: targetSizeMB) {
            let compressedSizeMB = compressed.sizeInMB() ?? 0.0
            let compressionRatio = (compressedSizeMB / currentSizeMB) * 100
            
            print("✅ [InputBar] Compression réussie: \(String(format: "%.2f", currentSizeMB)) MB -> \(String(format: "%.2f", compressedSizeMB)) MB (\(String(format: "%.1f", compressionRatio))%)")
            
            // Notifier la compression via callback
            let message = String(format: "Image compressée: %.1f MB → %.1f MB", currentSizeMB, compressedSizeMB)
            onImageCompressed(message)
            
            return compressed
        } else {
            print("⚠️ [InputBar] Échec de la compression, image originale conservée")
            // Notifier l'échec via callback
            let warningMessage = String(format: "Impossible de compresser l'image (%.1f MB). Elle sera envoyée telle quelle.", currentSizeMB)
            onImageCompressed(warningMessage)
            return image
        }
    }
    
    private var sendButtonColor: Color {
        let isEmpty = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty
        if isEmpty || isGenerating { // ÉTAPE 4.2 : Griser pendant la génération
            return Color.white.opacity(0.18)
        }
        return Color(hex: "4F8CFF")
    }
}

struct ImagePreviewSection: View {
    @Binding var images: [NSImage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(images.count) image\(images.count > 1 ? "s" : "") attachée\(images.count > 1 ? "s" : "")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ImagePreviewThumbnail(image: image) {
                        images.remove(at: index)
                    }
                }
            }
        }
    }
}

struct ImagePreviewThumbnail: View {
    let image: NSImage
    let onRemove: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 150)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .scaleEffect(isAnimating ? 1.0 : 0.95)
                .opacity(isAnimating ? 1.0 : 0.8)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }
}

#Preview("Chat complet") {
    ContentView()
        .frame(width: 600, height: 700)
}

#Preview("ChatView - Avec messages") {
    ChatView(
        viewModel: .preview,
        isSidebarVisible: .constant(true),
        inputText: .constant("")
    )
    .frame(width: 400, height: 700)
}

#Preview("Chat vide") {
    ChatView(
        viewModel: ChatViewModel(conversations: []),
        isSidebarVisible: .constant(true),
        inputText: .constant("")
    )
    .frame(width: 400, height: 700)
}

















































