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
    @Binding var isPromptEditorOpen: Bool
    let isColumnMode: Bool

    @State private var isRenamingConversation = false
    @State private var renameDraft = ""
    @State private var pendingImages: [NSImage] = []
    @State private var toast: ToastMessage?
    @State private var previewImage: NSImage? = nil
    
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
        ZStack {
            VStack(spacing: 0) {
                HeaderView(
                    title: viewModel.selectedConversation?.titre ?? "Aucune conversation",
                    isSidebarVisible: $isSidebarVisible,
                    canRename: viewModel.selectedConversation != nil,
                    onRename: presentRenameDialog,
                    viewModel: viewModel,
                    isPromptEditorOpen: $isPromptEditorOpen,
                    isCompactMode: !isColumnMode
                )

                // Éditeur de prompt inline (mode compact uniquement)
                // En mode colonne (large), l'éditeur s'affiche à droite via PromptEditorColumn
                if isPromptEditorOpen && !isColumnMode {
                    PromptEditorView(viewModel: viewModel, isOpen: $isPromptEditorOpen)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let conversation = viewModel.selectedConversation {
                    if conversation.messages.isEmpty {
                        WelcomeView()
                    } else {
                        MessagesScrollView(messages: conversation.messages, onImageTap: { image in
                            previewImage = image
                        })
                    }
                } else {
                    WelcomeView()
                }

                InputBarView(
                    inputText: $inputText,
                    pendingImages: $pendingImages,
                    isGenerating: viewModel.isGenerating,
                    onSend: sendMessage,
                    onImageAdded: { showToast(.success("Image ajoutée")) },
                    onImageError: { error in showToast(.error(error.localizedDescription)) },
                    onImageCompressed: { message in
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

            // Overlay d'aperçu d'image
            if let image = previewImage {
                ImagePreviewOverlay(image: image, onClose: {
                    previewImage = nil
                })
            }
        }
        .toast($toast)
        .onChange(of: toast) { oldValue, newValue in
            if let toast = newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                    self.toast = nil
                }
            }
        }
        // Transfert des images capturées via raccourcis clavier (⌥⇧S, ⌥⇧X)
        .onChange(of: viewModel.capturedImage) { _, newImage in
            guard let image = newImage else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                pendingImages.append(image)
            }
            showToast(.success("📸 Image capturée"))
            viewModel.capturedImage = nil
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
    let isCompactMode: Bool // Mode compact : prompts sur deuxième ligne
    var onTestFrontend: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Ligne 1 : Sidebar + Titre + (Prompts si pas compact)
            if isCompactMode {
                // Mode compact : titre centré
                ZStack {
                    // Bouton sidebar à gauche
                    HStack {
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

                        Spacer()
                    }

                    // Titre centré avec icônes équilibrées
                    HStack(spacing: 8) {
                        // Icône invisible à gauche pour équilibrer le centrage
                        if canRename {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.clear) // Invisible
                        }

                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        // Icône visible à droite
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

                // Ligne 2 : Prompts centrés
                PromptSelectorRow(viewModel: viewModel, isPromptEditorOpen: $isPromptEditorOpen, isCompact: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else {
                // Mode normal : layout horizontal classique
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

                    PromptSelectorRow(viewModel: viewModel, isPromptEditorOpen: $isPromptEditorOpen, isCompact: false)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

/// Ligne de sélection des prompts (responsive)
struct PromptSelectorRow: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPromptEditorOpen: Bool
    let isCompact: Bool // Mode compact : affiche seulement les icônes
    @State private var showNewPromptSheet = false

    /// Prompts personnalisés actifs (non archivés)
    private var customPrompts: [CustomPrompt] {
        PreferencesManager.shared.activePrompts
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
                    isEditorOpen: isPromptEditorOpen && viewModel.selectedCustomPromptID == custom.id,
                    action: {
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
                    },
                    onArchive: {
                        // Archiver le prompt
                        PreferencesManager.shared.archivePrompt(id: custom.id)
                        // Si c'est le prompt sélectionné, désélectionner
                        if viewModel.selectedCustomPromptID == custom.id {
                            viewModel.selectedCustomPromptID = nil
                            viewModel.promptType = .correcteur
                            isPromptEditorOpen = false
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: isCompact ? .center : .trailing)
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
    var onArchive: (() -> Void)? = nil

    @State private var showArchiveConfirmation = false
    @State private var isHovered: Bool = false

    private var backgroundColor: Color {
        if isSelected {
            return Color.purple.opacity(isEditorOpen ? 0.4 : 0.3)
        }
        return (isHovered && isCompact) ? Color.white.opacity(0.12) : Color.white.opacity(0.05)
    }

    private var borderColor: Color {
        isSelected ? Color.purple.opacity(isEditorOpen ? 0.7 : 0.5) : Color.clear
    }

    var body: some View {
        VStack(spacing: 2) {
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
                .background(RoundedRectangle(cornerRadius: 8).fill(backgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .contextMenu {
                Button(role: .destructive) {
                    showArchiveConfirmation = true
                } label: {
                    Label("Archiver", systemImage: "archivebox")
                }
            }

            if isCompact && isHovered {
                Text(prompt.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .alert("Archiver ce prompt ?", isPresented: $showArchiveConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Archiver", role: .destructive) {
                onArchive?()
            }
        } message: {
            Text("Le prompt \"\(prompt.name)\" sera archivé pendant 90 jours. Vous pourrez le restaurer depuis les Préférences.")
        }
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

    @State private var isHovered: Bool = false

    private var backgroundColor: Color {
        if isSelected {
            return isTemporary ? Color.orange.opacity(0.4) : Color.blue.opacity(isEditorOpen ? 0.4 : 0.3)
        }
        return (isHovered && isCompact) ? Color.white.opacity(0.12) : Color.white.opacity(0.05)
    }

    private var borderColor: Color {
        if isSelected {
            return isTemporary ? Color.orange.opacity(0.7) : Color.blue.opacity(isEditorOpen ? 0.7 : 0.5)
        }
        return Color.clear
    }

    var body: some View {
        VStack(spacing: 2) {
            Button(action: action) {
                HStack(spacing: 6) {
                    Text(promptType.icon)
                        .font(.system(size: isCompact ? 16 : 14))

                    if !isCompact {
                        Text(promptType.shortName)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    }

                    if isSelected && isTemporary {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                    }

                    if isSelected {
                        Image(systemName: isEditorOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, isCompact ? 8 : 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(backgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))

            if isCompact && isHovered {
                Text(promptType.shortName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Éditeur de prompt inline (s'affiche sous le header)
struct PromptEditorView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isOpen: Bool
    @State private var editedPrompt: String = ""
    @State private var originalPrompt: String = ""
    @State private var showArchiveAlert: Bool = false
    @FocusState private var isFocused: Bool

    /// Vérifie si c'est un prompt personnalisé (archivable)
    private var isCustomPrompt: Bool {
        viewModel.promptType == .personnalise && viewModel.selectedCustomPromptID != nil
    }

    /// Nom du prompt personnalisé sélectionné
    private var customPromptName: String {
        guard let id = viewModel.selectedCustomPromptID,
              let prompt = PreferencesManager.shared.preferences.customPrompts.first(where: { $0.id == id }) else {
            return "Prompt"
        }
        return prompt.name
    }

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
                    HStack(spacing: 8) {
                        // Bouton Archiver (seulement pour les prompts personnalisés)
                        if isCustomPrompt {
                            Button(action: { showArchiveAlert = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 10))
                                    Text("Archiver")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.orange.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Archiver ce prompt (suppression dans 90 jours)")
                        }

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
        .alert("Archiver ce prompt ?", isPresented: $showArchiveAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Archiver", role: .destructive) {
                archiveCurrentPrompt()
            }
        } message: {
            Text("Le prompt \"\(customPromptName)\" sera archivé pendant 90 jours. Vous pourrez le restaurer depuis les Préférences.")
        }
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

    /// Archive le prompt personnalisé actuel
    private func archiveCurrentPrompt() {
        guard let id = viewModel.selectedCustomPromptID else { return }
        PreferencesManager.shared.archivePrompt(id: id)
        viewModel.selectedCustomPromptID = nil
        viewModel.promptType = .correcteur
        withAnimation(.easeInOut(duration: 0.2)) {
            isOpen = false
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

/// Colonne d'édition de prompt (mode large - s'affiche à droite)
struct PromptEditorColumn: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isOpen: Bool
    @State private var editedPrompt: String = ""
    @State private var originalPrompt: String = ""
    @State private var showArchiveAlert: Bool = false
    @FocusState private var isFocused: Bool

    /// Vérifie si c'est un prompt personnalisé (archivable)
    private var isCustomPrompt: Bool {
        viewModel.promptType == .personnalise && viewModel.selectedCustomPromptID != nil
    }

    /// Nom du prompt personnalisé sélectionné
    private var customPromptName: String {
        guard let id = viewModel.selectedCustomPromptID,
              let prompt = PreferencesManager.shared.preferences.customPrompts.first(where: { $0.id == id }) else {
            return "Prompt"
        }
        return prompt.name
    }

    /// Récupère le prompt sauvegardé selon le type sélectionné
    private var savedPrompt: String {
        ChatViewModel.getSavedPrompt(for: viewModel.promptType)
    }

    /// Vérifie si le prompt a été modifié (mode temporaire)
    private var isModified: Bool {
        editedPrompt != originalPrompt
    }

    private let columnBackground = LinearGradient(
        colors: [
            Color(hex: "0A1628"),
            Color(hex: "0D1D35")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        VStack(spacing: 0) {
            // Header de la colonne
            HStack {
                HStack(spacing: 8) {
                    Text(viewModel.promptType.icon)
                        .font(.system(size: 16))
                    Text(viewModel.promptType.shortName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Indicateur de modification
                if isModified {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }

                // Bouton fermer
                Button(action: { handleClose() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isModified ? Color.red.opacity(0.15) : Color.black.opacity(0.3))

            Divider()
                .background(Color.white.opacity(0.1))

            // Zone d'édition (prend tout l'espace vertical)
            TextEditor(text: $editedPrompt)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(.white)
                .focused($isFocused)
                .padding(12)

            Divider()
                .background(Color.white.opacity(0.1))

            // Footer avec actions
            VStack(spacing: 10) {
                // Compteur de caractères
                HStack {
                    Text("\(editedPrompt.count) caractères")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }

                // Boutons d'action
                if isModified {
                    HStack(spacing: 10) {
                        Button(action: discardChanges) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 10))
                                Text("Annuler")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button(action: saveChanges) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Sauvegarder")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.7))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Boutons Archiver et Dupliquer
                    HStack(spacing: 8) {
                        // Bouton Archiver (seulement pour les prompts personnalisés)
                        if isCustomPrompt {
                            Button(action: { showArchiveAlert = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 10))
                                    Text("Archiver")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.orange.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .help("Archiver ce prompt (suppression dans 90 jours)")
                        }

                        // Bouton pour dupliquer
                        Button(action: createBranch) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 10))
                                Text("Dupliquer")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help("Créer un nouveau prompt basé sur celui-ci")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isModified ? Color.red.opacity(0.1) : Color.clear)
        }
        .padding(.top, 12) // Aligner avec la sidebar et le header
        .frame(maxHeight: .infinity)
        .background(columnBackground)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 1),
            alignment: .leading
        )
        .alert("Archiver ce prompt ?", isPresented: $showArchiveAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Archiver", role: .destructive) {
                archiveCurrentPrompt()
            }
        } message: {
            Text("Le prompt \"\(customPromptName)\" sera archivé pendant 90 jours. Vous pourrez le restaurer depuis les Préférences.")
        }
        .onAppear {
            editedPrompt = savedPrompt
            originalPrompt = savedPrompt
            isFocused = true
        }
        .onChange(of: viewModel.promptType) { _, _ in
            editedPrompt = savedPrompt
            originalPrompt = savedPrompt
        }
    }

    /// Archive le prompt personnalisé actuel
    private func archiveCurrentPrompt() {
        guard let id = viewModel.selectedCustomPromptID else { return }
        PreferencesManager.shared.archivePrompt(id: id)
        viewModel.selectedCustomPromptID = nil
        viewModel.promptType = .correcteur
        withAnimation(.easeInOut(duration: 0.2)) {
            isOpen = false
        }
    }

    private func saveChanges() {
        ChatViewModel.savePrompt(editedPrompt, for: viewModel.promptType)
        originalPrompt = editedPrompt
    }

    private func discardChanges() {
        editedPrompt = originalPrompt
    }

    private func createBranch() {
        let name = "\(viewModel.promptType.shortName) (copie)"
        viewModel.createCustomPrompt(name: name, icon: "📝", content: editedPrompt)
        withAnimation(.easeInOut(duration: 0.2)) {
            isOpen = false
        }
    }

    private func handleClose() {
        if isModified {
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
    let onImageTap: (NSImage) -> Void

    /// ID constant pour l'ancre de scroll en bas
    private let bottomAnchorID = "bottomAnchor"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message, onImageTap: onImageTap)
                            .id(message.id)
                    }

                    // Ancre invisible en bas pour scroll fiable
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            // Trigger 1: Nouveau message ajouté
            .onChange(of: messages.count) { oldCount, newCount in
                if newCount > oldCount {
                    scrollToBottom(proxy: proxy)
                }
            }
            // Trigger 2: Contenu du dernier message change (typing → réponse GPT)
            .onChange(of: messages.last?.contenu) { _, newContent in
                if let content = newContent, !content.starts(with: "⏳") {
                    scrollToBottom(proxy: proxy)
                }
            }
            // Trigger 3: Notification forcée (après capture d'écran)
            .onReceive(NotificationCenter.default.publisher(for: .forceScrollToBottom)) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    /// Scroll vers le bas avec double appel pour contourner les bugs de LazyVStack
    private func scrollToBottom(proxy: ScrollViewProxy) {
        // Premier appel immédiat
        proxy.scrollTo(bottomAnchorID, anchor: .bottom)

        // Deuxième appel avec délai (contourne bug lazy loading)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let onImageTap: (NSImage) -> Void
    private let userBubble = Color(hex: "3E7BFF")
    private let assistantBubble = Color.white.opacity(0.18)

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Images
                if let images = message.images, !images.isEmpty {
                    MessageImagesView(images: images, onImageTap: onImageTap)

                    // Indicateur OCR (si applicable)
                    if message.usedOCR, let confidence = message.ocrConfidence {
                        HStack(spacing: 4) {
                            Image(systemName: "text.viewfinder")
                                .font(.caption2)
                            Text("OCR \(Int(confidence * 100))%")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.15))
                        )
                    } else if message.imageData != nil {
                        // Mode Vision utilisé (fallback ou forcé)
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.caption2)
                            Text("Vision")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                    }
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

/// Overlay plein écran pour afficher une image en grand
struct ImagePreviewOverlay: View {
    let image: NSImage
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Fond semi-transparent
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            // Image centrée
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(40)
                .onTapGesture {
                    // Ne pas fermer quand on clique sur l'image
                }

            // Bouton fermer en haut à droite
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
                Spacer()
            }

            // Instructions en bas
            VStack {
                Spacer()
                Text("Cliquez en dehors de l'image ou sur la croix pour fermer")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: true)
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Bonjour Hadrien 👋")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text("Comment puis-je t'aider aujourd'hui ?")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InputBarView: View {
    @Binding var inputText: String
    @Binding var pendingImages: [NSImage]
    let isGenerating: Bool
    let onSend: () -> Void
    let onImageAdded: () -> Void
    let onImageError: (Error) -> Void
    let onImageCompressed: (String) -> Void
    
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
                    .disabled((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty) || isGenerating)
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
    
    /// Traite le résultat du collage d'image avec gestion d'erreurs et compression automatique
    private func handleImagePasteResult(_ result: ClipboardResult) {
        // Bloquer seulement les erreurs critiques (clipboard vide, format invalide)
        if let error = result.error {
            if case .imageTooLarge = error {
                // Les grandes images sont acceptées et compressées automatiquement
                print("ℹ️ [InputBar] Image grande détectée, compression automatique")
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
        
        // Compression automatique si > 2MB
        let finalImage = compressImageIfNeeded(image, originalSizeMB: originalSizeMB)
        
        // Animation d'ajout avec l'image (compressée ou originale)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pendingImages.append(finalImage)
        }
        
        onImageAdded()
    }
    
    /// Compresse l'image si elle dépasse 2MB
    /// - Parameters:
    ///   - image: Image à compresser
    ///   - originalSizeMB: Taille originale en MB (pour les logs)
    /// - Returns: Image compressée ou originale si déjà sous le seuil
    private func compressImageIfNeeded(_ image: NSImage, originalSizeMB: Double?) -> NSImage {
        // Vérifier la taille actuelle
        let currentSizeMB = image.sizeInMB() ?? originalSizeMB ?? 0.0
        let targetSizeMB: Double = 2.0
        let dimensions = "\(Int(image.size.width))x\(Int(image.size.height))"

        // Log image détectée dans la console de debug
        let detectedMsg = "🖼️ [Compression] Image détectée: \(dimensions), \(String(format: "%.2f", currentSizeMB)) MB"
        print(detectedMsg)
        Task { @MainActor in
            DebugLogger.shared.log(detectedMsg, category: "Compression", level: .info)
        }

        // Si image <= 2MB, pas besoin de compression
        guard currentSizeMB > targetSizeMB else {
            let noCompressMsg = "✅ [Compression] Image acceptée (déjà sous \(targetSizeMB) MB)"
            print(noCompressMsg)
            Task { @MainActor in
                DebugLogger.shared.log(noCompressMsg, category: "Compression", level: .info)
            }
            return image
        }

        let compressStartMsg = "🔧 [Compression] Compression nécessaire: \(String(format: "%.2f", currentSizeMB)) MB -> cible: \(targetSizeMB) MB"
        print(compressStartMsg)
        Task { @MainActor in
            DebugLogger.shared.log(compressStartMsg, category: "Compression", level: .info)
        }

        // Compresser l'image
        if let compressed = image.compressToMaxSize(maxSizeMB: targetSizeMB) {
            let compressedSizeMB = compressed.sizeInMB() ?? 0.0
            let compressionRatio = (compressedSizeMB / currentSizeMB) * 100

            let successMsg = "✅ [Compression] Réussie: \(String(format: "%.2f", currentSizeMB)) MB -> \(String(format: "%.2f", compressedSizeMB)) MB (\(String(format: "%.1f", compressionRatio))%)"
            print(successMsg)
            Task { @MainActor in
                DebugLogger.shared.log(successMsg, category: "Compression", level: .info)
            }

            // Notifier la compression via callback
            let message = String(format: "Image compressée: %.1f MB → %.1f MB", currentSizeMB, compressedSizeMB)
            onImageCompressed(message)

            return compressed
        } else {
            let failMsg = "⚠️ [Compression] Échec de la compression, image originale conservée (\(String(format: "%.2f", currentSizeMB)) MB)"
            print(failMsg)
            Task { @MainActor in
                DebugLogger.shared.log(failMsg, category: "Compression", level: .warning)
            }
            // Notifier l'échec via callback
            let warningMessage = String(format: "Impossible de compresser l'image (%.1f MB). Elle sera envoyée telle quelle.", currentSizeMB)
            onImageCompressed(warningMessage)
            return image
        }
    }
    
    private var sendButtonColor: Color {
        let isEmpty = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty
        if isEmpty || isGenerating {
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
        inputText: .constant(""),
        isPromptEditorOpen: .constant(false),
        isColumnMode: false
    )
    .frame(width: 400, height: 700)
}

#Preview("Chat vide") {
    ChatView(
        viewModel: ChatViewModel(conversations: []),
        isSidebarVisible: .constant(true),
        inputText: .constant(""),
        isPromptEditorOpen: .constant(false),
        isColumnMode: false
    )
    .frame(width: 400, height: 700)
}

















































