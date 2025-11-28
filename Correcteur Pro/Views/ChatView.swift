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
                viewModel: viewModel
            )
            
            if let conversation = viewModel.selectedConversation {
                MessagesScrollView(messages: conversation.messages)
            } else {
                EmptyStateView()
            }
            
            InputBarView(
                inputText: $inputText,
                pendingImages: $pendingImages,
                onSend: sendMessage
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(chatGradient)
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
        guard viewModel.sendMessage(inputText, images: imagesToSend) else { return }
        inputText = ""
        pendingImages = []
    }
}

struct HeaderView: View {
    let title: String
    @Binding var isSidebarVisible: Bool
    let canRename: Bool
    let onRename: () -> Void
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var showCustomPromptSheet = false
    
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
            
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Picker pour sélectionner le prompt système
            Menu {
                ForEach(SystemPromptType.allCases) { promptType in
                    Button(action: {
                        viewModel.promptType = promptType
                        if promptType == .personnalise {
                            showCustomPromptSheet = true
                        }
                    }) {
                        HStack {
                            Text(promptType.rawValue)
                            if viewModel.promptType == promptType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                    Text(viewModel.promptType.rawValue)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help("Sélectionner le prompt système")
            
            Button(action: onRename) {
                Label("Renommer", systemImage: "pencil")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .foregroundColor(canRename ? Color.white : Color.white.opacity(0.3))
            .disabled(!canRename)
            .help("Renommer la conversation")
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 14)
        .background(
            UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: 18,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: 18
            ), style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: .init(
                        topLeading: 18,
                        bottomLeading: 0,
                        bottomTrailing: 0,
                        topTrailing: 18
                    ), style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .frame(height: 56)
        .sheet(isPresented: $showCustomPromptSheet) {
            CustomPromptSheet(viewModel: viewModel)
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
    let onSend: () -> Void
    
    private let inputBackground = Color.white.opacity(0.08)
    private let borderColor = Color.white.opacity(0.2)
    
    var body: some View {
        VStack(spacing: 0) {
            // Preview des images
            if !pendingImages.isEmpty {
                ImagePreviewSection(images: $pendingImages)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            
            // Zone de saisie
            HStack(alignment: .bottom, spacing: 12) {
                // Bouton de test pour diagnostiquer le clipboard
                Button(action: {
                    print("\n🔍 [InputBar] Test manuel du clipboard...")
                    ClipboardHelper.diagnostic()
                    if let image = ClipboardHelper.checkClipboardForImage() {
                        print("✅ [InputBar] Image ajoutée depuis le clipboard!")
                        pendingImages.append(image)
                    }
                }) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Tester le clipboard (diagnostic)")
                
                TextEditorWithImagePaste(text: $inputText) { image in
                    print("✅ [InputBar] Image collée via TextEditorWithImagePaste!")
                    pendingImages.append(image)
                }
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
                
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(
                            Circle()
                                .fill(sendButtonColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, pendingImages.isEmpty ? 12 : 0)
            .padding(.bottom, 24)
        }
        .background(
            UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: 22,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: 22
            ), style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: .init(
                        topLeading: 22,
                        bottomLeading: 0,
                        bottomTrailing: 0,
                        topTrailing: 22
                    ), style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // Fonction simplifiée pour gérer les images depuis le clipboard
    // Maintenant gérée directement par TextEditorWithImagePaste
    private func handleImagePasteFromClipboard() {
        if let image = ClipboardHelper.checkClipboardForImage() {
            print("✅ [InputBar] Image ajoutée depuis le clipboard!")
            pendingImages.append(image)
        }
    }
    
    private var sendButtonColor: Color {
        let isEmpty = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty
        if isEmpty {
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


















